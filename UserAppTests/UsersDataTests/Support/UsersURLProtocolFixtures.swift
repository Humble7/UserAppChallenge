import Foundation

// Each fixture subclass provides immutable responses, so parallel tests do not share a handler.
class StubbedUsersURLProtocol: URLProtocol {
    class var statusCode: Int { 200 }
    class var responseData: Data { Data("[]".utf8) }
    class var transportError: URLError? { nil }
    class var returnsHTTPResponse: Bool { true }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let error = Self.transportError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let response: URLResponse
        if Self.returnsHTTPResponse {
            guard let httpResponse = HTTPURLResponse(
                url: url,
                statusCode: Self.statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            response = httpResponse
        } else {
            response = URLResponse(
                url: url,
                mimeType: "application/json",
                expectedContentLength: Self.responseData.count,
                textEncodingName: "utf-8"
            )
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class HTTP200UsersURLProtocol: StubbedUsersURLProtocol {
    override class var responseData: Data {
        Data(#"""
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
    }
}

final class MinimalUsersURLProtocol: StubbedUsersURLProtocol {
    override class var responseData: Data {
        Data(#"[{"id":42,"name":"Test User","email":"test@example.com","company":{"name":"Example"}}]"#.utf8)
    }
}

final class UnusedFieldsUsersURLProtocol: StubbedUsersURLProtocol {
    override class var responseData: Data {
        // Unconsumed fields may be null or change shape without breaking the user list.
        Data(#"""
        [{
            "id": 42,
            "name": "Test User",
            "email": "test@example.com",
            "username": null,
            "phone": 123,
            "website": null,
            "address": "unavailable",
            "company": {"name": "Example", "catchPhrase": null, "bs": 123}
        }]
        """#.utf8)
    }
}

final class MissingCompanyNameURLProtocol: StubbedUsersURLProtocol {
    override class var responseData: Data {
        Data(#"[{"id":42,"name":"Test User","email":"test@example.com","company":{}}]"#.utf8)
    }
}

final class HTTP500URLProtocol: StubbedUsersURLProtocol {
    override class var statusCode: Int { 500 }

    override class var responseData: Data {
        Data(#"{"message": "Internal Server Error"}"#.utf8)
    }
}

final class HTTP299URLProtocol: StubbedUsersURLProtocol {
    override class var statusCode: Int { 299 }
}

final class HTTP300URLProtocol: StubbedUsersURLProtocol {
    override class var statusCode: Int { 300 }
}

final class HTTP404URLProtocol: StubbedUsersURLProtocol {
    override class var statusCode: Int { 404 }
}

final class MalformedJSONURLProtocol: StubbedUsersURLProtocol {
    override class var responseData: Data { Data("{invalid JSON".utf8) }
}

final class MissingFieldURLProtocol: StubbedUsersURLProtocol {
    override class var responseData: Data { Data(#"[{"id":42}]"#.utf8) }
}

final class NonHTTPURLProtocol: StubbedUsersURLProtocol {
    override class var returnsHTTPResponse: Bool { false }
}

final class OfflineURLProtocol: StubbedUsersURLProtocol {
    override class var transportError: URLError? { URLError(.notConnectedToInternet) }
}

final class TimeoutURLProtocol: StubbedUsersURLProtocol {
    override class var transportError: URLError? { URLError(.timedOut) }
}

final class CancelledURLProtocol: StubbedUsersURLProtocol {
    override class var transportError: URLError? { URLError(.cancelled) }
}
