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
        // Bug fix: Reject cancelled tasks and overlapping loads so requests cannot race to update state.
        // Trade-off: Ignoring overlapping loads avoids request races with minimal coordination,
        // but drops new requests; search or filtering may need a latest-request policy instead.
        guard !Task.isCancelled, !isLoading else { return }

        let previousState = state
        // Trade-off: Keeping users visible during refresh and after refresh failure preserves
        // access to the list, but the displayed data may be stale until a refresh succeeds.
        if case .loaded(let users, _) = previousState {
            state = .loaded(users: users, refresh: .loading)
        } else {
            state = .loading
        }

        do {
            let users = try await apiClient.fetchUsers()
            // Bug fix: A service may return after cancellation; do not publish its result.
            try Task.checkCancellation()
            state = .loaded(users: users, refresh: .idle)
        } catch {
            // Bug fix: Cancellation should exit loading without displaying a new failure.
            // Keep loaded users and reset refresh, or restore the state before the initial load.
            let wasCancelled = Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled
            if case .loaded(let users, _) = previousState {
                state = .loaded(users: users, refresh: wasCancelled ? .idle : .failed(error))
            } else {
                state = wasCancelled ? previousState : .failed(error)
            }
        }
    }
}
