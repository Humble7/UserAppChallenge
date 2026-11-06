// UsersViewModel.swift

import Foundation
import Combine

enum UsersState {
    case idle
    case loading
    case loaded([User])
    case failed(Error)
}

final class UsersViewModel: ObservableObject {
    @Published private(set) var state: UsersState = .idle

    private let apiClient: UsersAPIClient

    init(apiClient: UsersAPIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading

        do {
            let users = try await apiClient.fetchUsers()
            state = .loaded(users)
        } catch {
            state = .failed(error)
        }
    }
}
