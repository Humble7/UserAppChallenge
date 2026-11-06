// UsersViewModel.swift

import Foundation
import Combine

enum UsersState {
    case idle
    case loading
    case loaded(users: [User], refresh: RefreshState)
    case failed(Error)
}

enum RefreshState {
    case idle
    case loading
    case failed(Error)
}

final class UsersViewModel: ObservableObject {
    @Published private(set) var state: UsersState = .idle

    private let apiClient: any UsersService

    init(apiClient: any UsersService) {
        self.apiClient = apiClient
    }
    
    var isLoading: Bool {
        switch state {
        case .loading, .loaded(_, .loading):
            return true
        default:
            return false
        }
    }

    func load() async {
        guard !Task.isCancelled, !isLoading else { return }

        let previousState = state
        if case .loaded(let users, _) = previousState {
            state = .loaded(users: users, refresh: .loading)
        } else {
            state = .loading
        }

        do {
            let users = try await apiClient.fetchUsers()
            try Task.checkCancellation()
            state = .loaded(users: users, refresh: .idle)
        } catch {
            let wasCancelled = Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled
            if case .loaded(let users, _) = previousState {
                state = .loaded(users: users, refresh: wasCancelled ? .idle : .failed(error))
            } else {
                state = wasCancelled ? previousState : .failed(error)
            }
        }
    }
}
