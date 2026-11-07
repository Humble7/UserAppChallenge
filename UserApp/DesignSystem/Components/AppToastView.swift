import SwiftUI

struct AppToastView: View {
    let message: LocalizedStringKey

    private enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 12
        static let cornerRadius: CGFloat = 12
        static let maximumWidth: CGFloat = 480
    }

    var body: some View {
        Text(message)
            .font(AppTypography.toastMessage)
            .foregroundStyle(AppColors.textPrimary)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
            .frame(maxWidth: Layout.maximumWidth, alignment: .leading)
            .background(
                .ultraThickMaterial,
                in: .rect(cornerRadius: Layout.cornerRadius)
            )
    }
}

#if DEBUG
#Preview("Short message") {
    AppToastView(message: "Users refreshed.")
        .padding()
}

#Preview("Refresh failure") {
    AppToastView(message: "Couldn't refresh users. Tap Refresh to try again.")
        .padding()
}

#Preview("Multiline message") {
    AppToastView(
        message: "Couldn't refresh users. The list hasn't been updated. Tap Refresh to try again."
    )
    .padding()
}

#Preview("Chinese message") {
    AppToastView(message: "无法刷新用户列表。请点击刷新按钮重试。")
        .padding()
}

#Preview("Dark appearance") {
    AppToastView(message: "Couldn't refresh users. Tap Refresh to try again.")
        .padding()
        .preferredColorScheme(.dark)
}
#endif
