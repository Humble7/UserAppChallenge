import SwiftUI

struct AppPrimaryButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
    }
}

#if DEBUG
#Preview("Primary actions") {
    VStack(spacing: 16) {
        AppPrimaryButton(title: "Refresh", action: {})
        AppPrimaryButton(title: "Try again", action: {})
    }
    .padding()
}

#Preview("Long title with accessibility text size") {
    AppPrimaryButton(title: "Refresh the user directory", action: {})
        .frame(maxWidth: 280)
        .padding()
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Disabled primary action") {
    AppPrimaryButton(title: "Refresh", action: {})
        .disabled(true)
        .padding()
}
#endif
