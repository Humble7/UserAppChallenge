//
//  Untitled.swift
//  QantasCodeChallenge
//
//  Created by Micah Napier on 12/12/2025.
//

import XCTest
@testable import UserApp

final class UsersViewModelTests: XCTestCase {
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
