// Only decode fields consumed by the app; unrelated API fields do not affect loading.
nonisolated struct UserDTO: Decodable {
    let id: Int
    let name: String
    let email: String
    let company: CompanyDTO

    struct CompanyDTO: Decodable {
        let name: String
    }

    func toDomain() -> User {
        User(id: id, name: name, email: email, companyName: company.name)
    }
}
