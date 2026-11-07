import Foundation

#if DEBUG
extension User {
    nonisolated static let example = User(
        id: 1,
        name: "Alex Chen",
        username: "alex",
        email: "alex@example.com",
        phone: "0400 000 000",
        website: "example.com",
        address: Address(
            street: "George Street",
            suite: "1",
            city: "Sydney",
            zipcode: "2000",
            geo: Geo(lat: "-33.8688", lng: "151.2093")
        ),
        company: Company(name: "Example Company", catchPhrase: "", bs: "")
    )
}
#endif
