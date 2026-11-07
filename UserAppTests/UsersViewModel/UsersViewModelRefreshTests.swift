import Foundation
import XCTest
@testable import UserApp

final class UsersViewModelRefreshTests: XCTestCase {
    // Covers refresh success: keep existing users while loading, then replace their content with the new response.
    @MainActor
    func testRefreshSucceeds() async throws {
        // Arrange: use the same ID so the test detects stale content, not just changes in identity.
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)
        let existingUser = makeUser(id: 1, name: "Existing User", email: "existing@example.com")
        let updatedUser = makeUser(id: 1, name: "Updated User", email: "updated@example.com")
        let initialLoad = Task { await viewModel.load() }
        try await service.waitUntilRequestStarted()
        service.complete(with: [existingUser])
        await initialLoad.value

        // Act / Assert: retain the last loaded content throughout the refresh.
        let refresh = Task { await viewModel.load() }
        try await service.waitUntilRequestStarted()

        if case .loaded(let users, .loading) = viewModel.state {
            XCTAssertEqual(users.map(\.id), [existingUser.id])
            XCTAssertEqual(users.map(\.name), [existingUser.name])
            XCTAssertEqual(users.map(\.email), [existingUser.email])
        } else {
            XCTFail("Expected existing users while refreshing")
        }
        XCTAssertTrue(viewModel.isLoading)
        XCTAssertEqual(service.requestCount, 2)

        service.complete(with: [updatedUser])
        await refresh.value

        // Assert
        XCTAssertFalse(viewModel.isLoading)
        guard case .loaded(let users, .idle) = viewModel.state else {
            XCTFail("Expected updated users with an idle refresh state")
            return
        }
        XCTAssertEqual(users.map(\.id), [updatedUser.id])
        XCTAssertEqual(users.map(\.name), [updatedUser.name])
        XCTAssertEqual(users.map(\.email), [updatedUser.email])
    }


    // Bug fix
    // Covers refresh data preservation: keep loaded users during refresh and after failure, exposing the error in RefreshState.
    @MainActor
    func testRefreshFailureKeepsLoadedUsers() async throws {
        // Arrange
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)
        let user = User(
            id: 1,
            name: "Existing User",
            username: "user",
            email: "user@example.com",
            phone: "123",
            website: "example.com",
            address: Address(
                street: "Main Street",
                suite: "1",
                city: "Sydney",
                zipcode: "2000",
                geo: Geo(lat: "-33", lng: "151")
            ),
            company: Company(name: "Example", catchPhrase: "", bs: "")
        )
        let initialLoad = Task { await viewModel.load() }
        try await service.waitUntilRequestStarted()
        service.complete(with: [user])
        await initialLoad.value

        // Act
        let refresh = Task { await viewModel.load() }
        try await service.waitUntilRequestStarted()

        // Assert: keep existing users while refreshing.
        if case .loaded(let users, .loading) = viewModel.state {
            XCTAssertEqual(users.map(\.id), [user.id])
        } else {
            XCTFail("Expected existing users while refreshing")
        }

        service.fail(with: URLError(.notConnectedToInternet))
        await refresh.value

        // Assert: keep existing users and expose the refresh error.
        if case .loaded(let users, .failed(let error)) = viewModel.state {
            XCTAssertEqual(users.map(\.id), [user.id])
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        } else {
            XCTFail("Expected existing users after refresh failure")
        }
    }

    @MainActor
    func testRefreshAfterFailureSucceeds() async throws {
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)
        let existing = makeUser(id: 1, name: "Existing User", email: "existing@example.com")
        let updated = makeUser(id: 1, name: "Recovered User", email: "recovered@example.com")
        try await loadUsers([existing], into: viewModel, using: service)

        let failedRefresh = Task { await viewModel.load() }
        try await service.waitUntilRequestStarted()
        service.fail(with: URLError(.notConnectedToInternet))
        await failedRefresh.value

        guard case .loaded(_, .failed) = viewModel.state else {
            return XCTFail("Expected a refresh failure before retrying")
        }

        let retry = Task { await viewModel.load() }
        try await service.waitUntilRequestStarted()
        if case .loaded(let users, .loading) = viewModel.state {
            XCTAssertEqual(users.map(\.name), [existing.name])
        } else {
            XCTFail("Expected existing users and loading refresh while retrying")
        }
        XCTAssertTrue(viewModel.isLoading)

        service.complete(with: [updated])
        await retry.value

        guard case .loaded(let users, .idle) = viewModel.state else {
            return XCTFail("Expected the previous refresh error to clear on success")
        }
        XCTAssertEqual(users.map(\.name), [updated.name])
        XCTAssertEqual(users.map(\.email), [updated.email])
        XCTAssertEqual(service.requestCount, 3)
        XCTAssertFalse(viewModel.isLoading)
    }

    @MainActor
    func testIgnoresDuplicateRefresh() async throws {
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)
        let user = makeUser(id: 1, name: "Existing User", email: "existing@example.com")
        try await loadUsers([user], into: viewModel, using: service)

        let refresh = Task { await viewModel.load() }
        try await service.waitUntilRequestStarted()
        await viewModel.load()
        await viewModel.load()

        XCTAssertEqual(service.requestCount, 2)
        XCTAssertTrue(viewModel.isLoading)
        if case .loaded(let users, .loading) = viewModel.state {
            XCTAssertEqual(users.map(\.id), [user.id])
        } else {
            XCTFail("Duplicate refreshes must not end the active refresh or remove users")
        }

        service.complete(with: [user])
        await refresh.value

        guard case .loaded(_, .idle) = viewModel.state else {
            return XCTFail("Expected the original refresh to complete normally")
        }
        XCTAssertFalse(viewModel.isLoading)
    }

    @MainActor
    func testRefreshAcceptsEmptyResult() async throws {
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)
        let user = makeUser(id: 1, name: "Existing User", email: "existing@example.com")
        try await loadUsers([user], into: viewModel, using: service)

        try await loadUsers([], into: viewModel, using: service)

        guard case .loaded(let users, .idle) = viewModel.state else {
            return XCTFail("An empty refresh response must replace the previous users")
        }
        XCTAssertTrue(users.isEmpty)
        XCTAssertEqual(service.requestCount, 2)
        XCTAssertFalse(viewModel.isLoading)
    }
}
