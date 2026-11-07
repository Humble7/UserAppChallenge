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
    func testInitialLoadSucceeds() async throws {
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
        XCTAssertEqual(users.map { $0.company.name }, [user.company.name])
    }

    // Covers initial load failure: preserve the service error and leave the loading state.
    @MainActor
    func testInitialLoadFails() async throws {
        // Arrange
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)

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

    // Covers retry recovery: a failed initial request must allow a new load and clear the error on success.
    @MainActor
    func testRetryAfterInitialFailureSucceeds() async throws {
        // Arrange
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)
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
        let viewModel = UsersViewModel(apiClient: service)
        
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
    
    // Bug fix
    // Covers cancellation treated as failure: cancelling an initial load must restore idle instead of showing an error.
    @MainActor
    func testCancelledLoadReturnsToIdle() async throws {
        // Arrange
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)

        // Act
        let load = Task {
            await viewModel.load()
        }

        try await service.waitUntilRequestStarted()
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

    // A cancelled refresh must retain the existing users and allow a later refresh.
    @MainActor
    func testCancelledRefreshKeepsUsersAndAllowsRetry() async throws {
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)
        let existing = makeUser(id: 1, name: "Existing User", email: "existing@example.com")
        let updated = makeUser(id: 1, name: "Updated User", email: "updated@example.com")
        try await load([existing], into: viewModel, using: service)

        let refresh = Task { await viewModel.load() }
        try await service.waitUntilRequestStarted()
        refresh.cancel()
        service.fail(with: URLError(.cancelled))
        await refresh.value

        guard case .loaded(let users, .idle) = viewModel.state else {
            return XCTFail("Expected existing users and idle refresh after cancellation")
        }
        XCTAssertEqual(users.map(\.name), [existing.name])
        XCTAssertFalse(viewModel.isLoading)

        try await load([updated], into: viewModel, using: service)

        guard case .loaded(let refreshedUsers, .idle) = viewModel.state else {
            return XCTFail("Expected a subsequent refresh to succeed")
        }
        XCTAssertEqual(refreshedUsers.map(\.name), [updated.name])
        XCTAssertEqual(service.requestCount, 3)
        XCTAssertFalse(viewModel.isLoading)
    }

    // The service deliberately ignores cancellation and returns a successful response.
    @MainActor
    func testCancelledInitialLoadIgnoresLateSuccess() async throws {
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)
        let lateUser = makeUser(id: 42, name: "Late User", email: "late@example.com")

        let initialLoad = Task { await viewModel.load() }
        try await service.waitUntilRequestStarted()
        initialLoad.cancel()
        service.complete(with: [lateUser])
        await initialLoad.value

        guard case .idle = viewModel.state else {
            return XCTFail("A successful response after cancellation must not be published")
        }
        XCTAssertEqual(service.requestCount, 1)
        XCTAssertFalse(viewModel.isLoading)
    }

    @MainActor
    func testCancelledRefreshIgnoresLateSuccess() async throws {
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)
        let existing = makeUser(id: 1, name: "Existing User", email: "existing@example.com")
        let lateUser = makeUser(id: 1, name: "Late Update", email: "late@example.com")
        try await load([existing], into: viewModel, using: service)

        let refresh = Task { await viewModel.load() }
        try await service.waitUntilRequestStarted()
        refresh.cancel()
        service.complete(with: [lateUser])
        await refresh.value

        guard case .loaded(let users, .idle) = viewModel.state else {
            return XCTFail("Expected existing users after a cancelled refresh returns success")
        }
        XCTAssertEqual(users.map(\.id), [existing.id])
        XCTAssertEqual(users.map(\.name), [existing.name])
        XCTAssertEqual(users.map(\.email), [existing.email])
        XCTAssertEqual(service.requestCount, 2)
        XCTAssertFalse(viewModel.isLoading)
    }

    @MainActor
    func testRefreshAfterFailureSucceeds() async throws {
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)
        let existing = makeUser(id: 1, name: "Existing User", email: "existing@example.com")
        let updated = makeUser(id: 1, name: "Recovered User", email: "recovered@example.com")
        try await load([existing], into: viewModel, using: service)

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
        try await load([user], into: viewModel, using: service)

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
    func testInitialLoadAcceptsEmptyResult() async throws {
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)

        try await load([], into: viewModel, using: service)

        guard case .loaded(let users, .idle) = viewModel.state else {
            return XCTFail("An empty response must be treated as a successful load")
        }
        XCTAssertTrue(users.isEmpty)
        XCTAssertEqual(service.requestCount, 1)
        XCTAssertFalse(viewModel.isLoading)
    }

    @MainActor
    func testRefreshAcceptsEmptyResult() async throws {
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)
        let user = makeUser(id: 1, name: "Existing User", email: "existing@example.com")
        try await load([user], into: viewModel, using: service)

        try await load([], into: viewModel, using: service)

        guard case .loaded(let users, .idle) = viewModel.state else {
            return XCTFail("An empty refresh response must replace the previous users")
        }
        XCTAssertTrue(users.isEmpty)
        XCTAssertEqual(service.requestCount, 2)
        XCTAssertFalse(viewModel.isLoading)
    }

    // The child task inherits MainActor, so it cannot start until this test yields.
    @MainActor
    func testAlreadyCancelledLoadDoesNotStartRequest() async {
        let service = ImmediateUsersService(result: [])
        let viewModel = UsersViewModel(apiClient: service)

        let initialLoad = Task { await viewModel.load() }
        initialLoad.cancel()
        await initialLoad.value

        guard case .idle = viewModel.state else {
            return XCTFail("An already-cancelled task must leave the ViewModel idle")
        }
        XCTAssertEqual(service.requestCount, 0)
        XCTAssertFalse(viewModel.isLoading)
    }

    @MainActor
    func testAlreadyCancelledRefreshDoesNotStartRequest() async {
        let user = makeUser(id: 1, name: "Existing User", email: "existing@example.com")
        let service = ImmediateUsersService(result: [user])
        let viewModel = UsersViewModel(apiClient: service)
        await viewModel.load()

        let refresh = Task { await viewModel.load() }
        refresh.cancel()
        await refresh.value

        guard case .loaded(let users, .idle) = viewModel.state else {
            return XCTFail("An already-cancelled refresh must leave existing users unchanged")
        }
        XCTAssertEqual(users.map(\.id), [user.id])
        XCTAssertEqual(service.requestCount, 1)
        XCTAssertFalse(viewModel.isLoading)
    }

    @MainActor
    func testServiceCancellationDoesNotBecomeFailure() async throws {
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)

        let initialLoad = Task { await viewModel.load() }
        try await service.waitUntilRequestStarted()
        // The task itself is not cancelled: this exercises the URLError cancellation branch.
        service.fail(with: URLError(.cancelled))
        await initialLoad.value

        guard case .idle = viewModel.state else {
            return XCTFail("A service cancellation must restore idle without a failure")
        }
        XCTAssertFalse(initialLoad.isCancelled)
        XCTAssertFalse(viewModel.isLoading)
    }

    @MainActor
    func testCancellationErrorDoesNotBecomeFailure() async throws {
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)

        let initialLoad = Task { await viewModel.load() }
        try await service.waitUntilRequestStarted()
        service.fail(with: CancellationError())
        await initialLoad.value

        guard case .idle = viewModel.state else {
            return XCTFail("CancellationError must restore idle without a failure")
        }
        XCTAssertFalse(initialLoad.isCancelled)
        XCTAssertFalse(viewModel.isLoading)
    }

    @MainActor
    func testInitialLoadPreservesMultipleUsersAndOrder() async throws {
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)
        let users = [
            makeUser(id: 42, name: "First User", email: "first@example.com"),
            makeUser(id: 7, name: "Second User", email: "second@example.com")
        ]

        try await load(users, into: viewModel, using: service)

        guard case .loaded(let loadedUsers, .idle) = viewModel.state else {
            return XCTFail("Expected all returned users to be loaded")
        }
        XCTAssertEqual(loadedUsers.map(\.id), [42, 7])
        XCTAssertEqual(loadedUsers.map(\.name), users.map(\.name))
        XCTAssertEqual(loadedUsers.map(\.email), users.map(\.email))
        XCTAssertFalse(viewModel.isLoading)
    }

    @MainActor
    private func load(
        _ users: [User],
        into viewModel: UsersViewModel,
        using service: ControlledUsersService
    ) async throws {
        let task = Task { await viewModel.load() }
        try await service.waitUntilRequestStarted()
        service.complete(with: users)
        await task.value
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

// Immediate responses keep pre-cancellation tests bounded even if the entry guard regresses.
@MainActor
private final class ImmediateUsersService: UsersService {
    private(set) var requestCount = 0
    private let result: [User]

    init(result: [User]) {
        self.result = result
    }

    @MainActor
    func fetchUsers() async throws -> [User] {
        requestCount += 1
        return result
    }
}

@MainActor
private final class ControlledUsersService: UsersService {
    private(set) var requestCount = 0
    private var pendingResponse: CheckedContinuation<[User], Error>?
    private var requestStarted: XCTestExpectation?
    
    @MainActor
    func fetchUsers() async throws -> [User] {
        requestCount += 1
        
        // Unexpected overlapping requests finish immediately so a regression fails instead of hanging.
        if pendingResponse != nil {
            return []
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            pendingResponse = continuation
            requestStarted?.fulfill()
            requestStarted = nil
        }
    }
    
    func waitUntilRequestStarted(timeout: TimeInterval = 5) async throws {
        if pendingResponse != nil { return }
        let expectation = XCTestExpectation(description: "UsersService request started")
        requestStarted = expectation
        defer { requestStarted = nil }

        let result = await XCTWaiter.fulfillment(of: [expectation], timeout: timeout)
        guard result == .completed else {
            throw RequestStartError.timedOut
        }
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

    private enum RequestStartError: Error {
        case timedOut
    }
}
