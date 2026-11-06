//
//  UsersService.swift
//  UserApp
//
//  Created by ChenZhen on 6/11/26.
//

import Foundation

nonisolated protocol UsersService {
    func fetchUsers() async throws -> [User]
}
