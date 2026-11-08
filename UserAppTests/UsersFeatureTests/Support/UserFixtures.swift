@testable import UserApp

func makeUser(id: Int, name: String, email: String) -> User {
    User(id: id, name: name, email: email, companyName: "Example")
}
