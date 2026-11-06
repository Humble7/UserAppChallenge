// UsersListView.swift

import SwiftUI

struct UsersListView: View {
    @ObservedObject private var viewModel = UsersViewModel(apiClient: UsersAPIClient())

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Users")
                .toolbar {
                    Button("Refresh") {
                        Task {
                            await viewModel.load()
                        }
                    }
                }
                .task {
                    await viewModel.load()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Loading…")

        case .failed:
            VStack(spacing: 8) {
                Text("Something went wrong")
                Button("Try Again") {
                    Task {
                        await viewModel.load()
                    }
                }
            }

        case .loaded(let users):
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
        }
    }
}
