// UsersListView.swift

import SwiftUI

struct UsersListView: View {
    @StateObject private var viewModel: UsersViewModel

    init(viewModel: @autoclosure @escaping () -> UsersViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Users")
                .toolbar {
                    if case .loaded(_, let refresh) = viewModel.state {
                        if case .loading = refresh {
                            ProgressView()
                        } else {
                            Button("Refresh") {
                                Task {
                                    await viewModel.load()
                                }
                            }
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

        case .loaded(let users, let refresh):
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
            .safeAreaInset(edge: .top) {
                if case .failed = refresh {
                    Text("Couldn't refresh. Showing the last loaded data.")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.regularMaterial)
                }
            }
        }
    }
}
