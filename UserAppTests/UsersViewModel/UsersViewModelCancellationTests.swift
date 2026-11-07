import Foundation
import XCTest
@testable import UserApp

final class UsersViewModelCancellationTests: XCTestCase {

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

    // A cancelled refresh must retain the existing users and allow a later refresh.
    @MainActor
    func testCancelledRefreshKeepsUsersAndAllowsRetry() async throws {
        let service = ControlledUsersService()
        let viewModel = UsersViewModel(apiClient: service)
        let existing = makeUser(id: 1, name: "Existing User", email: "existing@example.com")
        let updated = makeUser(id: 1, name: "Updated User", email: "updated@example.com")
        try await loadUsers([existing], into: viewModel, using: service)

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

        try await loadUsers([updated], into: viewModel, using: service)

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
        try await loadUsers([existing], into: viewModel, using: service)

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
}
