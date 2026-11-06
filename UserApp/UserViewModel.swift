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

    private let apiClient: any UsersService

    init(apiClient: any UsersService) {
        self.apiClient = apiClient
    }
    
    var isLoading: Bool {
        if case .loading = state {
            return true
        }
        return false
    }

    func load() async {
        guard !isLoading else { return }
        
        state = .loading

        do {
            let users = try await apiClient.fetchUsers()
            state = .loaded(users)
        } catch {
            state = .failed(error)
        }
    }
}
