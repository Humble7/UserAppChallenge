import Foundation
import XCTest
@testable import UserApp

@MainActor
func loadUsers(
    _ users: [User],
    into viewModel: UsersViewModel,
    using service: ControlledUsersService
) async throws {
    let task = Task { await viewModel.load() }
    try await service.waitUntilRequestStarted()
    service.complete(with: users)
    await task.value
}

// Immediate responses keep pre-cancellation tests bounded even if the entry guard regresses.
@MainActor
final class ImmediateUsersService: UsersService {
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
final class ControlledUsersService: UsersService {
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
