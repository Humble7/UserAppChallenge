import SwiftUI

struct UserRow: View {
    let user: User

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(user.name)
                .font(AppTypography.rowTitle)
                .foregroundStyle(AppColors.textPrimary)
            Text(user.email)
                .font(AppTypography.rowSubtitle)
                .foregroundStyle(AppColors.textPrimary)
            Text(user.company.name)
                .font(AppTypography.rowMetadata)
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}

#if DEBUG
private struct UserRowPreview: View {
    var body: some View {
        List {
            UserRow(user: .example)
            UserRow(user: previewUser(
                name: "Alexandra Catherine Montgomery-Wellington",
                email: "alexandra.montgomery-wellington@international.example.com",
                companyName: "International Research and Development Company"
            ))
            UserRow(user: previewUser(
                name: "Jordan Reed",
                email: "jordan.reed@example.com",
                companyName: "Regional Public Transport and Digital Services Company"
            ))
            UserRow(user: previewUser(
                name: "Taylor Morgan",
                email: "taylor.morgan@research.example.com",
                companyName: "Galaxy Technologies"
            ))
        }
    }

    private func previewUser(name: String, email: String, companyName: String) -> User {
        let example = User.example
        return User(
            id: example.id,
            name: name,
            username: example.username,
            email: email,
            phone: example.phone,
            website: example.website,
            address: example.address,
            company: Company(name: companyName, catchPhrase: "", bs: "")
        )
    }
}

#Preview("User rows") {
    UserRowPreview()
}

#Preview("User rows with accessibility text size") {
    UserRowPreview()
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("User rows in dark appearance") {
    UserRowPreview()
        .preferredColorScheme(.dark)
}
#endif
