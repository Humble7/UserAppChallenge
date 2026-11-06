//
//  UsersService.swift
//  UserApp
//
//  Created by ChenZhen on 6/11/26.
//

import Foundation

@MainActor
protocol UsersService {
    func fetchUsers() async throws -> [User]
}
