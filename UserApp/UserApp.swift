//
//  UserApp.swift
//  UserApp
//

import SwiftUI

@main
struct UserApp: App {
    var body: some Scene {
        WindowGroup {
            UsersListView(viewModel: UsersViewModel(apiClient: UsersAPIClient()))
        }
    }
}
