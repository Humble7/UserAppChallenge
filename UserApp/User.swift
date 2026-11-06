// User.swift

import Foundation

nonisolated struct Geo: Decodable {
    let lat: String
    let lng: String
}

nonisolated struct Address: Decodable {
    let street: String
    let suite: String
    let city: String
    let zipcode: String
    let geo: Geo
}

nonisolated struct Company: Decodable {
    let name: String
    let catchPhrase: String
    let bs: String
}

nonisolated struct User: Decodable, Identifiable {
    let id: Int
    let name: String
    let username: String
    let email: String
    let phone: String
    let website: String
    let address: Address
    let company: Company
}
