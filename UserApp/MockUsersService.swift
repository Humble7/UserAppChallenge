import Foundation

#if DEBUG
actor MockUsersService: UsersService {
    nonisolated enum Scenario {
        case success
        case initialFailure
        case refreshFailure
        case initialLoading
        case refreshLoading
    }

    private let scenario: Scenario
    private let result: [User]
    private let error: UsersAPIError
    private let delay: Duration
    private var hasResponded = false

    init(
        scenario: Scenario = .success,
        result: [User] = [User.example],
        error: UsersAPIError = .httpStatus(500),
        delay: Duration = .zero
    ) {
        self.scenario = scenario
        self.result = result
        self.error = error
        self.delay = delay
    }

    func fetchUsers() async throws -> [User] {
        if delay > .zero {
            try await Task.sleep(for: delay)
        }

        try Task.checkCancellation()

        switch (scenario, hasResponded) {
        case (.initialFailure, false):
            hasResponded = true
            throw error

        case (.refreshFailure, true):
            throw error

        case (.initialLoading, _), (.refreshLoading, true):
            // Keep the request pending until the preview cancels it.
            while true {
                try await Task.sleep(for: .seconds(3_600))
            }

        default:
            hasResponded = true
            return result
        }
    }
}

extension User {
    nonisolated static let example = User(
        id: 1,
        name: "Alex Chen",
        username: "alex",
        email: "alex@example.com",
        phone: "0400 000 000",
        website: "example.com",
        address: Address(
            street: "George Street",
            suite: "1",
            city: "Sydney",
            zipcode: "2000",
            geo: Geo(lat: "-33.8688", lng: "151.2093")
        ),
        company: Company(name: "Example Company", catchPhrase: "", bs: "")
    )
}
#endif
