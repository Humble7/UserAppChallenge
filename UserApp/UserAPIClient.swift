// UsersAPIClient.swift

import Foundation

struct UsersAPIClient {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func fetchUsers() async throws -> [User] {
        let url = URL(string: "https://jsonplaceholder.typicode.com/users")!
        let (data, _) = try await session.data(from: url)

        struct Response: Decodable {
            let users: [User]
        }

        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.users
    }
}
