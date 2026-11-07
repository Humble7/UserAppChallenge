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
        .overlay(alignment: .bottom) {
            refreshErrorOverlay
        }
        .onReceive(viewModel.$state) { state in
            if case .loaded(_, .failed) = state {
                refreshErrorToastID = UUID()
            } else {
                refreshErrorToastID = nil
            }
        }
        .task(id: refreshErrorToastID) {
            guard let toastID = refreshErrorToastID else { return }

            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }

            guard refreshErrorToastID == toastID else { return }
            refreshErrorToastID = nil
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
        VStack(spacing: 8) {
            Text("Something went wrong")
            Button("Try Again") {
                loadRequestID = UUID()
            }
            .disabled(viewModel.isLoading)
        }
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

    private var refreshErrorOverlay: some View {
        ZStack {
            if refreshErrorToastID != nil {
                Text("Couldn't refresh. Try again.")
                    .font(.subheadline)
                    .padding()
                    .background(.ultraThickMaterial, in: .rect(cornerRadius: 12))
                    .padding(.horizontal)
                    .padding(.bottom)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: refreshErrorToastID)
        .allowsHitTesting(false)
    }
    
    private var emptyView: some View {
        ContentUnavailableView(
            "No Users",
            systemImage: "person.2",
            description: Text(
                "There are no users to display. Try refreshing to check again."
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
