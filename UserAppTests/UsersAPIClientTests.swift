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
}

private final class HTTP200UsersURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let data = Data(#"""
        [
            {
                "id": 42,
                "name": "Test User",
                "username": "tester",
                "email": "test@example.com",
                "phone": "123",
                "website": "example.com",
                "address": {
                    "street": "Main Street",
                    "suite": "1",
                    "city": "Sydney",
                    "zipcode": "2000",
                    "geo": { "lat": "-33", "lng": "151" }
                },
                "company": { "name": "Example", "catchPhrase": "", "bs": "" }
            }
        ]
        """#.utf8)

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

}

private final class HTTP500URLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: 500,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let data = Data(#"{"message": "Internal Server Error"}"#.utf8)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
