import Foundation

#if DEBUG
extension User {
    nonisolated static let example = User(
        id: 1,
        name: "Alex Chen",
        email: "alex@example.com",
        companyName: "Example Company"
    )

    nonisolated static let examples: [User] = [
        example,
        User(
            id: 2,
            name: "Olivia Wilson",
            email: "olivia.wilson@example.com",
            companyName: "Example Studio"
        ),
        User(
            id: 3,
            name: "Noah Williams",
            email: "noah.williams@example.com",
            companyName: "Example Labs"
        ),
        User(
            id: 4,
            name: "Amelia Patel",
            email: "amelia.patel@example.com",
            companyName: "Example Design"
        ),
        User(
            id: 5,
            name: "Ethan Nguyen",
            email: "ethan.nguyen@example.com",
            companyName: "Example Digital"
        ),
        User(
            id: 6,
            name: "Isabella Thompson",
            email: "isabella.thompson@example.com",
            companyName: "Example Systems"
        )
    ]
}
#endif
