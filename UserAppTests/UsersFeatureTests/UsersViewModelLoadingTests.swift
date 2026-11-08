import Foundation
import XCTest
@testable import UserApp

final class UsersViewModelLoadingTests: XCTestCase {
    // Covers initial loading: enter loading, then expose the fetched users with an idle refresh state.
    @MainActor
    func testInitialLoadSucceeds() async throws {
        // Arrange
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(service: service)
        let user = makeUser(id: 42, name: "Loaded User", email: "loaded@example.com")

        if case .idle = viewModel.state {
            // Expected
        } else {
            XCTFail("Expected idle before the first load")
        }
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(service.requestCount, 0)

        // Act / Assert: inspect loading before allowing the request to finish.
        let load = Task { await viewModel.load() }
        try await service.waitUntilRequestStarted()

        if case .loading = viewModel.state {
            // Expected
        } else {
            XCTFail("Expected loading while the initial request is pending")
        }
        XCTAssertTrue(viewModel.isLoading)
        XCTAssertEqual(service.requestCount, 1)

        service.complete(with: [user])
        await load.value

        // Assert
        XCTAssertFalse(viewModel.isLoading)
        guard case .loaded(let users, .idle) = viewModel.state else {
            XCTFail("Expected loaded users with an idle refresh state")
            return
        }
        XCTAssertEqual(users.map(\.id), [user.id])
        XCTAssertEqual(users.map(\.name), [user.name])
        XCTAssertEqual(users.map(\.email), [user.email])
        XCTAssertEqual(users.map { $0.companyName }, [user.companyName])
    }

    // Covers initial load failure: preserve the service error and leave the loading state.
    @MainActor
    func testInitialLoadFails() async throws {
        // Arrange
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(service: service)

        // Act
        let load = Task { await viewModel.load() }
        try await service.waitUntilRequestStarted()

        if case .loading = viewModel.state {
            // Expected
        } else {
            XCTFail("Expected loading before the initial request fails")
        }
        XCTAssertTrue(viewModel.isLoading)

        service.fail(with: URLError(.notConnectedToInternet))
        await load.value

        // Assert
        XCTAssertEqual(service.requestCount, 1)
        XCTAssertFalse(viewModel.isLoading)
        guard case .failed(let error) = viewModel.state else {
            XCTFail("Expected a page-level failure after the initial request fails")
            return
        }
        XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
    }

    // Covers retry recovery: a failed initial request must allow a new load and clear the error on success.
    @MainActor
    func testRetryAfterInitialFailureSucceeds() async throws {
        // Arrange
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(service: service)
        let user = makeUser(id: 42, name: "Recovered User", email: "recovered@example.com")
        let initialLoad = Task { await viewModel.load() }
        try await service.waitUntilRequestStarted()
        service.fail(with: URLError(.notConnectedToInternet))
        await initialLoad.value

        guard case .failed(let error) = viewModel.state else {
            XCTFail("Expected an initial failure before retrying")
            return
        }
        XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(service.requestCount, 1)

        // Act / Assert: retry must start a new request and replace the error with loading.
        let retry = Task { await viewModel.load() }
        try await service.waitUntilRequestStarted()

        if case .loading = viewModel.state {
            // Expected
        } else {
            XCTFail("Expected loading while retrying the initial request")
        }
        XCTAssertTrue(viewModel.isLoading)
        XCTAssertEqual(service.requestCount, 2)

        service.complete(with: [user])
        await retry.value

        // Assert
        XCTAssertFalse(viewModel.isLoading)
        guard case .loaded(let users, .idle) = viewModel.state else {
            XCTFail("Expected retry success to replace the failure with loaded users")
            return
        }
        XCTAssertEqual(users.map(\.id), [user.id])
        XCTAssertEqual(users.map(\.name), [user.name])
        XCTAssertEqual(users.map(\.email), [user.email])
    }

    // Bug fix
    // Covers overlapping requests: a second load must not start another request or end the active loading state.
    @MainActor
    func testIgnoresDuplicateLoad() async throws {
        // Arrange
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(service: service)

        // Act
        let firstLoad = Task {
            await viewModel.load()
        }

        try await service.waitUntilRequestStarted()

        await viewModel.load()

        // Assert
        XCTAssertEqual(service.requestCount, 1)

        if case .loading = viewModel.state {
            // Expected
        } else {
            XCTFail("Expected loading state")
        }

        // Cleanup
        service.complete(with: [])
        await firstLoad.value
    }

    @MainActor
    func testInitialLoadAcceptsEmptyResult() async throws {
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(service: service)

        try await loadUsers([], into: viewModel, using: service)

        guard case .loaded(let users, .idle) = viewModel.state else {
            return XCTFail("An empty response must be treated as a successful load")
        }
        XCTAssertTrue(users.isEmpty)
        XCTAssertEqual(service.requestCount, 1)
        XCTAssertFalse(viewModel.isLoading)
    }

    @MainActor
    func testInitialLoadPreservesMultipleUsersAndOrder() async throws {
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(service: service)
        let users = [
            makeUser(id: 42, name: "First User", email: "first@example.com"),
            makeUser(id: 7, name: "Second User", email: "second@example.com")
        ]

        try await loadUsers(users, into: viewModel, using: service)

        guard case .loaded(let loadedUsers, .idle) = viewModel.state else {
            return XCTFail("Expected all returned users to be loaded")
        }
        XCTAssertEqual(loadedUsers.map(\.id), [42, 7])
        XCTAssertEqual(loadedUsers.map(\.name), users.map(\.name))
        XCTAssertEqual(loadedUsers.map(\.email), users.map(\.email))
        XCTAssertFalse(viewModel.isLoading)
    }
}
