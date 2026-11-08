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

    nonisolated static let examples: [User] = [
        example,
        User(
            id: 2,
            name: "Olivia Wilson",
            username: "olivia",
            email: "olivia.wilson@example.com",
            phone: "0400 000 001",
            website: "example.com",
            address: Address(
                street: "Collins Street",
                suite: "12",
                city: "Melbourne",
                zipcode: "3000",
                geo: Geo(lat: "-37.8136", lng: "144.9631")
            ),
            company: Company(name: "Example Studio", catchPhrase: "", bs: "")
        ),
        User(
            id: 3,
            name: "Noah Williams",
            username: "noah",
            email: "noah.williams@example.com",
            phone: "0400 000 002",
            website: "example.com",
            address: Address(
                street: "Queen Street",
                suite: "3",
                city: "Brisbane",
                zipcode: "4000",
                geo: Geo(lat: "-27.4698", lng: "153.0251")
            ),
            company: Company(name: "Example Labs", catchPhrase: "", bs: "")
        ),
        User(
            id: 4,
            name: "Amelia Patel",
            username: "amelia",
            email: "amelia.patel@example.com",
            phone: "0400 000 003",
            website: "example.com",
            address: Address(
                street: "St Georges Terrace",
                suite: "24",
                city: "Perth",
                zipcode: "6000",
                geo: Geo(lat: "-31.9505", lng: "115.8605")
            ),
            company: Company(name: "Example Design", catchPhrase: "", bs: "")
        ),
        User(
            id: 5,
            name: "Ethan Nguyen",
            username: "ethan",
            email: "ethan.nguyen@example.com",
            phone: "0400 000 004",
            website: "example.com",
            address: Address(
                street: "King William Street",
                suite: "5",
                city: "Adelaide",
                zipcode: "5000",
                geo: Geo(lat: "-34.9285", lng: "138.6007")
            ),
            company: Company(name: "Example Digital", catchPhrase: "", bs: "")
        ),
        User(
            id: 6,
            name: "Isabella Thompson",
            username: "isabella",
            email: "isabella.thompson@example.com",
            phone: "0400 000 005",
            website: "example.com",
            address: Address(
                street: "Macquarie Street",
                suite: "6",
                city: "Hobart",
                zipcode: "7000",
                geo: Geo(lat: "-42.8821", lng: "147.3272")
            ),
            company: Company(name: "Example Systems", catchPhrase: "", bs: "")
        )
    ]
}
#endif
