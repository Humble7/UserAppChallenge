// UsersAPIClient.swift

import Foundation

nonisolated enum UsersAPIError: Error, Equatable {
    case invalidResponse
    case httpStatus(Int)
}

nonisolated struct UsersAPIClient: UsersService {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    @concurrent
    func fetchUsers() async throws -> [User] {
        let url = URL(string: "https://jsonplaceholder.typicode.com/users")!
        let (data, response) = try await session.data(from: url)
        
        guard let response = response as? HTTPURLResponse else {
            throw UsersAPIError.invalidResponse
        }
        
        guard (200..<300).contains(response.statusCode) else {
            throw UsersAPIError.httpStatus(response.statusCode)
        }

        return try JSONDecoder().decode([User].self, from: data)
    }
}
