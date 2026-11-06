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

        return try JSONDecoder().decode([User].self, from: data)
    }
}
