//
//  UsersAPIClientTests.swift
//  UserAppTests
//
//  Created by ChenZhen on 6/11/26.
//

import Foundation
import Testing
@testable import UserApp

struct UsersAPIClientTests {

    // Bug fix
    // Covers the incorrect response decoding bug: a valid top-level user array must decode successfully.
    @Test
    @MainActor
    func `Fetch users decodes a top-level array`() async throws {
        // Arrange
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HTTP200UsersURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = UsersAPIClient(session: session)

        // Act
        let users = try await client.fetchUsers()

        // Assert
        #expect(users.map(\.id) == [42])
        #expect(users.map(\.name) == ["Test User"])
        #expect(users.map(\.email) == ["test@example.com"])
        #expect(users.map { $0.company.name } == ["Example"])
    }

    // Bug fix
    // Reject unsuccessful HTTP statuses before decoding, including the HTTP 500 error body.
    @Test(arguments: [HTTPResponse.redirect, .notFound, .serverError])
    @MainActor
    func `Fetch users rejects unsuccessful HTTP statuses`(_ response: HTTPResponse) async {
        let (client, session) = makeClient(protocolClass: response.protocolClass)
        defer { session.invalidateAndCancel() }

        await #expect(throws: UsersAPIError.httpStatus(response.rawValue)) {
            _ = try await client.fetchUsers()
        }
    }

    // Empty arrays are valid at both boundaries of the successful HTTP status range.
    @Test(arguments: [HTTPResponse.ok, .upperSuccessBoundary])
    @MainActor
    func `Fetch users returns an empty array for successful HTTP statuses`(_ response: HTTPResponse) async throws {
        let (client, session) = makeClient(protocolClass: response.protocolClass)
        defer { session.invalidateAndCancel() }

        let users = try await client.fetchUsers()

        #expect(users.isEmpty)
    }

    @Test
    @MainActor
    func `Fetch users rejects malformed JSON`() async {
        let (client, session) = makeClient(protocolClass: MalformedJSONURLProtocol.self)
        defer { session.invalidateAndCancel() }

        do {
            _ = try await client.fetchUsers()
            Issue.record("Expected invalid JSON to fail decoding")
        } catch DecodingError.dataCorrupted(_) {
            // Expected: the HTTP response is valid, but its body is not valid JSON.
        } catch {
            Issue.record("Expected DecodingError.dataCorrupted, received \(error)")
        }
    }

    @Test
    @MainActor
    func `Fetch users rejects missing required fields`() async {
        let (client, session) = makeClient(protocolClass: MissingFieldURLProtocol.self)
        defer { session.invalidateAndCancel() }

        do {
            _ = try await client.fetchUsers()
            Issue.record("Expected a user missing required fields to fail decoding")
        } catch DecodingError.keyNotFound(_, _) {
            // Expected: a syntactically valid user object is missing required fields.
        } catch {
            Issue.record("Expected DecodingError.keyNotFound, received \(error)")
        }
    }

    @Test
    @MainActor
    func `Fetch users rejects non-HTTP responses`() async {
        let (client, session) = makeClient(protocolClass: NonHTTPURLProtocol.self)
        defer { session.invalidateAndCancel() }

        await #expect(throws: UsersAPIError.invalidResponse) {
            _ = try await client.fetchUsers()
        }
    }

    // Verify propagation of URLSession errors, including a simulated cancellation error.
    @Test(arguments: TransportFailure.allCases)
    @MainActor
    func `Fetch users propagates transport errors`(_ failure: TransportFailure) async {
        let (client, session) = makeClient(protocolClass: failure.protocolClass)
        defer { session.invalidateAndCancel() }

        do {
            _ = try await client.fetchUsers()
            Issue.record("Expected URLError with code \(failure.code)")
        } catch let error as URLError {
            #expect(error.code == failure.code)
        } catch {
            Issue.record("Expected URLError with code \(failure.code), received \(error)")
        }
    }

    private func makeClient(protocolClass: URLProtocol.Type) -> (UsersAPIClient, URLSession) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [protocolClass]
        let session = URLSession(configuration: configuration)
        return (UsersAPIClient(session: session), session)
    }

    enum HTTPResponse: Int {
        case ok = 200
        case upperSuccessBoundary = 299
        case redirect = 300
        case notFound = 404
        case serverError = 500

        var protocolClass: URLProtocol.Type {
            switch self {
            case .ok: StubbedUsersURLProtocol.self
            case .upperSuccessBoundary: HTTP299URLProtocol.self
            case .redirect: HTTP300URLProtocol.self
            case .notFound: HTTP404URLProtocol.self
            case .serverError: HTTP500URLProtocol.self
            }
        }
    }

    enum TransportFailure: String, CaseIterable {
        case offline
        case timeout
        case cancelled

        var code: URLError.Code {
            switch self {
            case .offline: .notConnectedToInternet
            case .timeout: .timedOut
            case .cancelled: .cancelled
            }
        }

        var protocolClass: URLProtocol.Type {
            switch self {
            case .offline: OfflineURLProtocol.self
            case .timeout: TimeoutURLProtocol.self
            case .cancelled: CancelledURLProtocol.self
            }
        }
    }
}
