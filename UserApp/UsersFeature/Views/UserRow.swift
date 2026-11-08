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
                .accessibilityLabel("Email: \(user.email)")
            Text(user.companyName)
                .font(AppTypography.rowMetadata)
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityLabel("Company: \(user.companyName)")
        }
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
private struct UserRowPreview: View {
    var body: some View {
        List {
            UserRow(user: .example)
            UserRow(user: previewUser(
                id: 2,
                name: "Alexandra Catherine Montgomery-Wellington",
                email: "alexandra.montgomery-wellington@international.example.com",
                companyName: "International Research and Development Company"
            ))
            UserRow(user: previewUser(
                id: 3,
                name: "Jordan Reed",
                email: "jordan.reed@example.com",
                companyName: "Regional Public Transport and Digital Services Company"
            ))
            UserRow(user: previewUser(
                id: 4,
                name: "Taylor Morgan",
                email: "taylor.morgan@research.example.com",
                companyName: "Galaxy Technologies"
            ))
        }
    }

    private func previewUser(id: Int, name: String, email: String, companyName: String) -> User {
        User(
            id: id,
            name: name,
            email: email,
            companyName: companyName
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
