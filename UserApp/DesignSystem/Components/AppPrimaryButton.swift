import SwiftUI

struct AppPrimaryButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
    }
}
