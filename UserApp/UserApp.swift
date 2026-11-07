//
//  UserApp.swift
//  UserApp
//

import SwiftUI

@main
struct UserApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                UsersListView(viewModel: UsersViewModel(apiClient: UsersAPIClient()))
            }
        }
    }
}
