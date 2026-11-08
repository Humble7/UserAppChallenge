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
        
        // Bug fix: URLSession does not throw for HTTP error statuses. Validate before decoding.
        guard let response = response as? HTTPURLResponse else {
            throw UsersAPIError.invalidResponse
        }
        
        guard (200..<300).contains(response.statusCode) else {
            throw UsersAPIError.httpStatus(response.statusCode)
        }

        // Bug fix: The endpoint returns a top-level array, not an object containing a users array.
        let users = try JSONDecoder().decode([UserDTO].self, from: data)
        return users.map { $0.toDomain() }
    }
}
