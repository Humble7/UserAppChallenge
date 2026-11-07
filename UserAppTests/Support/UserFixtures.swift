@testable import UserApp

func makeUser(id: Int, name: String, email: String) -> User {
    User(
        id: id,
        name: name,
        username: "user",
        email: email,
        phone: "123",
        website: "example.com",
        address: Address(
            street: "Main Street",
            suite: "1",
            city: "Sydney",
            zipcode: "2000",
            geo: Geo(lat: "-33", lng: "151")
        ),
        company: Company(name: "Example", catchPhrase: "", bs: "")
    )
}
