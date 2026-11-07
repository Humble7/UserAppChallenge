import SwiftUI

struct AppUnavailableView: View {
    struct Action {
        let title: LocalizedStringKey
        let isEnabled: Bool
        let perform: () -> Void
    }

    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String
    let action: Action?

    init(
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        systemImage: String,
        action: Action? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
                    .font(AppTypography.stateTitle)
                    .foregroundStyle(AppColors.textPrimary)
            } icon: {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
            .accessibilityAddTraits(.isHeader)
        } description: {
            Text(message)
                .font(AppTypography.stateMessage)
                .foregroundStyle(AppColors.textSecondary)
        } actions: {
            if let action {
                AppPrimaryButton(title: action.title, action: action.perform)
                    .disabled(!action.isEnabled)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview("Empty state") {
    AppUnavailableView(
        title: "No users",
        message: "Refresh to check for users.",
        systemImage: "person.2",
        action: .init(title: "Refresh", isEnabled: true, perform: {})
    )
}

#Preview("Failure state") {
    AppUnavailableView(
        title: "Couldn't load users",
        message: "Try again in a moment.",
        systemImage: "exclamationmark.triangle",
        action: .init(title: "Try again", isEnabled: true, perform: {})
    )
}

#Preview("Disabled action") {
    AppUnavailableView(
        title: "No users",
        message: "Refresh to check for users.",
        systemImage: "person.2",
        action: .init(title: "Refresh", isEnabled: false, perform: {})
    )
}

#Preview("Long message without an action") {
    AppUnavailableView(
        title: "No matching users in this directory",
        message: "There are no users matching the current search and filters. Change your search or remove some filters to see more results.",
        systemImage: "person.2"
    )
}

#Preview("Accessibility text size") {
    AppUnavailableView(
        title: "Couldn't load users",
        message: "Try again in a moment.",
        systemImage: "exclamationmark.triangle",
        action: .init(title: "Try again", isEnabled: true, perform: {})
    )
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Dark appearance") {
    AppUnavailableView(
        title: "No users",
        message: "Refresh to check for users.",
        systemImage: "person.2",
        action: .init(title: "Refresh", isEnabled: true, perform: {})
    )
    .preferredColorScheme(.dark)
}
#endif
