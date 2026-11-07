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
    func fetchUsersDecodesTopLevelArray() async throws {
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
    // Covers missing HTTP validation: an HTTP 500 must produce a status error, not a decoding error.
    @Test
    @MainActor
    func fetchUsersRejectsHTTP500() async {
        // Arrange
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HTTP500URLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = UsersAPIClient(session: session)

        // Act / Assert
        await #expect(throws: UsersAPIError.httpStatus(500)) {
            _ = try await client.fetchUsers()
        }
    }

    // HTTP 299 is the upper successful boundary; an empty array is still valid data.
    @Test
    @MainActor
    func fetchUsersAcceptsHTTP299() async throws {
        let (client, session) = makeClient(protocolClass: HTTP299URLProtocol.self)
        defer { session.invalidateAndCancel() }

        let users = try await client.fetchUsers()

        #expect(users.isEmpty)
    }

    @Test
    @MainActor
    func fetchUsersRejectsHTTP300() async {
        let (client, session) = makeClient(protocolClass: HTTP300URLProtocol.self)
        defer { session.invalidateAndCancel() }

        await #expect(throws: UsersAPIError.httpStatus(300)) {
            _ = try await client.fetchUsers()
        }
    }

    @Test
    @MainActor
    func fetchUsersRejectsHTTP404() async {
        let (client, session) = makeClient(protocolClass: HTTP404URLProtocol.self)
        defer { session.invalidateAndCancel() }

        await #expect(throws: UsersAPIError.httpStatus(404)) {
            _ = try await client.fetchUsers()
        }
    }

    @Test
    @MainActor
    func fetchUsersReturnsEmptyArray() async throws {
        let (client, session) = makeClient(protocolClass: StubbedUsersURLProtocol.self)
        defer { session.invalidateAndCancel() }

        let users = try await client.fetchUsers()

        #expect(users.isEmpty)
    }

    @Test
    @MainActor
    func fetchUsersRejectsMalformedJSON() async {
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
    func fetchUsersRejectsMissingRequiredField() async {
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
    func fetchUsersRejectsNonHTTPResponse() async {
        let (client, session) = makeClient(protocolClass: NonHTTPURLProtocol.self)
        defer { session.invalidateAndCancel() }

        await #expect(throws: UsersAPIError.invalidResponse) {
            _ = try await client.fetchUsers()
        }
    }

    @Test
    @MainActor
    func fetchUsersPropagatesOfflineError() async {
        await expectTransportError(.notConnectedToInternet, protocolClass: OfflineURLProtocol.self)
    }

    @Test
    @MainActor
    func fetchUsersPropagatesTimeout() async {
        await expectTransportError(.timedOut, protocolClass: TimeoutURLProtocol.self)
    }

    @Test
    @MainActor
    func fetchUsersPropagatesCancellation() async {
        await expectTransportError(.cancelled, protocolClass: CancelledURLProtocol.self)
    }

    private func makeClient(protocolClass: URLProtocol.Type) -> (UsersAPIClient, URLSession) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [protocolClass]
        let session = URLSession(configuration: configuration)
        return (UsersAPIClient(session: session), session)
    }

    private func expectTransportError(_ code: URLError.Code, protocolClass: URLProtocol.Type) async {
        let (client, session) = makeClient(protocolClass: protocolClass)
        defer { session.invalidateAndCancel() }

        do {
            _ = try await client.fetchUsers()
            Issue.record("Expected URLError with code \(code)")
        } catch let error as URLError {
            #expect(error.code == code)
        } catch {
            Issue.record("Expected URLError with code \(code), received \(error)")
        }
    }
}
