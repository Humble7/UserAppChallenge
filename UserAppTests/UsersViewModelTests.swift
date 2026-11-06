//
//  Untitled.swift
//  QantasCodeChallenge
//
//  Created by Micah Napier on 12/12/2025.
//

import XCTest
@testable import UserApp

final class UsersViewModelTests: XCTestCase {
    // Covers initial loading: enter loading, then expose the fetched users with an idle refresh state.
    @MainActor
    func testInitialLoadSucceeds() async {
        // Arrange
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)
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
        await service.waitUntilRequestStarted()

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
        XCTAssertEqual(users.map { $0.company.name }, [user.company.name])
    }

    // Covers initial load failure: preserve the service error and leave the loading state.
    @MainActor
    func testInitialLoadFails() async {
        // Arrange
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)

        // Act
        let load = Task { await viewModel.load() }
        await service.waitUntilRequestStarted()

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

    // Covers refresh success: keep existing users while loading, then replace their content with the new response.
    @MainActor
    func testRefreshSucceeds() async {
        // Arrange: use the same ID so the test detects stale content, not just changes in identity.
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)
        let existingUser = makeUser(id: 1, name: "Existing User", email: "existing@example.com")
        let updatedUser = makeUser(id: 1, name: "Updated User", email: "updated@example.com")
        let initialLoad = Task { await viewModel.load() }
        await service.waitUntilRequestStarted()
        service.complete(with: [existingUser])
        await initialLoad.value

        // Act / Assert: retain the last loaded content throughout the refresh.
        let refresh = Task { await viewModel.load() }
        await service.waitUntilRequestStarted()

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

    // Covers retry recovery: a failed initial request must allow a new load and clear the error on success.
    @MainActor
    func testRetryAfterInitialFailureSucceeds() async {
        // Arrange
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)
        let user = makeUser(id: 42, name: "Recovered User", email: "recovered@example.com")
        let initialLoad = Task { await viewModel.load() }
        await service.waitUntilRequestStarted()
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
        await service.waitUntilRequestStarted()

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
    func testIgnoresDuplicateLoad() async {
        // Arrange
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)
        
        // Act
        let firstLoad = Task {
            await viewModel.load()
        }
        
        await service.waitUntilRequestStarted()
        
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
    
    // Bug fix
    // Covers cancellation treated as failure: cancelling an initial load must restore idle instead of showing an error.
    @MainActor
    func testCancelledLoadReturnsToIdle() async {
        // Arrange
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)

        // Act
        let load = Task {
            await viewModel.load()
        }

        await service.waitUntilRequestStarted()
        load.cancel()
        service.fail(with: URLError(.cancelled))
        await load.value

        // Assert
        if case .idle = viewModel.state {
            // Expected
        } else {
            XCTFail("Expected idle after cancellation")
        }
    }
    
    // Bug fix
    // Covers refresh data preservation: keep loaded users during refresh and after failure, exposing the error in RefreshState.
    @MainActor
    func testRefreshFailureKeepsLoadedUsers() async {
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
        await service.waitUntilRequestStarted()
        service.complete(with: [user])
        await initialLoad.value

        // Act
        let refresh = Task { await viewModel.load() }
        await service.waitUntilRequestStarted()

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

    private func makeUser(id: Int, name: String, email: String) -> User {
        User(
            id: id,
            name: name,
            username: "user",
            email: email,
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
    }
}

@MainActor
private final class ControlledUsersService: UsersService {
    private(set) var requestCount = 0
    private var pendingResponse: CheckedContinuation<[User], Error>?
    private var requestStarted: CheckedContinuation<Void, Never>?
    
    @MainActor
    func fetchUsers() async throws -> [User] {
        requestCount += 1
        
        // Unexpected overlapping requests finish immediately so a regression fails instead of hanging.
        if pendingResponse != nil {
            return []
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            pendingResponse = continuation
            requestStarted?.resume()
            requestStarted = nil
        }
    }
    
    func waitUntilRequestStarted() async {
        if pendingResponse != nil { return }
        await withCheckedContinuation { requestStarted = $0 }
    }
    
    func complete(with users: [User]) {
        guard let continuation = pendingResponse else {
            preconditionFailure("No request is pending")
        }
        pendingResponse = nil
        continuation.resume(returning: users)
    }
    
    func fail(with error: Error) {
        guard let continuation = pendingResponse else {
            preconditionFailure("No request is pending")
        }
        pendingResponse = nil
        continuation.resume(throwing: error)
    }
}
