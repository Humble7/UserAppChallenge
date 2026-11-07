// UsersListView.swift

import SwiftUI

struct UsersListView: View {
    // Bug fix: Retain the ViewModel across view reconstruction instead of recreating it with @ObservedObject.
    @StateObject private var viewModel: UsersViewModel
    
    // Trade-off: Keep this task trigger in the view to encapsulate lifecycle coordination, while the ViewModel owns loading logic and state.
    @State private var loadRequestID = UUID()
    @State private var refreshErrorToastID: UUID?

    init(viewModel: @autoclosure @escaping () -> UsersViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Users")
                .toolbar {
                    refreshToolbar
                }
        }
        .task(id: loadRequestID) {
            await viewModel.load()
        }
        .toast(
            message: "Couldn't refresh users. Tap Refresh to try again.",
            presentationID: $refreshErrorToastID
        )
        .onReceive(viewModel.$state) { state in
            if case .loaded(_, .failed) = state {
                refreshErrorToastID = UUID()
            } else {
                refreshErrorToastID = nil
            }
        }
    }

    // MARK: - View Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Loading…")

        case .failed:
            failureView

        case .loaded(let users, _):
            usersList(users)
        }
    }

    private var failureView: some View {
        AppUnavailableView(
            title: "Couldn't load users",
            message: "Try again in a moment.",
            systemImage: "exclamationmark.triangle",
            action: .init(
                title: "Try again",
                isEnabled: !viewModel.isLoading,
                perform: { loadRequestID = UUID() }
            )
        )
    }

    private func usersList(_ users: [User]) -> some View {
        List(users) { user in
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)
                Text(user.email)
                    .font(.subheadline)
                Text(user.company.name)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .overlay {
            if users.isEmpty {
                emptyView
            }
        }
    }
    
    @ViewBuilder
    private var refreshToolbar: some View {
        if case .loaded(_, let refresh) = viewModel.state {
            if case .loading = refresh {
                ProgressView()
            } else {
                Button("Refresh") {
                    loadRequestID = UUID()
                }
                .disabled(viewModel.isLoading)
            }
        }
    }

    private var emptyView: some View {
        AppUnavailableView(
            title: "No users",
            message: "Refresh to check for users.",
            systemImage: "person.2",
            action: .init(
                title: "Refresh",
                isEnabled: !viewModel.isLoading,
                perform: { loadRequestID = UUID() }
            )
        )
    }
}

#if DEBUG
#Preview("Users loaded") {
    UsersListView(viewModel: UsersViewModel(apiClient: MockUsersService(scenario: .success)))
}

#Preview("Empty users") {
    UsersListView(viewModel: UsersViewModel(apiClient: MockUsersService(result: [])))
}

#Preview("Slow loading (3s)") {
    UsersListView(
        viewModel: UsersViewModel(apiClient: MockUsersService(scenario: .success, delay: .seconds(3)))
    )
}

#Preview("Initial load failure") {
    UsersListView(
        viewModel: UsersViewModel(apiClient: MockUsersService(scenario: .initialFailure))
    )
}

#Preview("Initial loading") {
    UsersListView(viewModel: UsersViewModel(apiClient: MockUsersService(scenario: .initialLoading)))
}

#Preview("Refresh failure") {
    UsersListView(
        viewModel: UsersViewModel(apiClient: MockUsersService(scenario: .refreshFailure))
    )
}

#Preview("Refresh loading") {
    UsersListView(
        viewModel: UsersViewModel(apiClient: MockUsersService(scenario: .refreshLoading))
    )
}

#endif
