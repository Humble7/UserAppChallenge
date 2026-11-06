//
//  Untitled.swift
//  QantasCodeChallenge
//
//  Created by Micah Napier on 12/12/2025.
//

import XCTest
@testable import UserApp

final class UsersViewModelTests: XCTestCase {
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
}

@MainActor
private final class ControlledUsersService: UsersService {
    private(set) var requestCount = 0
    private var pendingResponse: CheckedContinuation<[User], Never>?
    private var requestStarted: CheckedContinuation<Void, Never>?
    
    func fetchUsers() async -> [User] {
        requestCount += 1
        
        // Unexpected overlapping requests finish immediately so a regression fails instead of hanging.
        if pendingResponse != nil {
            return []
        }
        
        return await withCheckedContinuation { continuation in
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
}
