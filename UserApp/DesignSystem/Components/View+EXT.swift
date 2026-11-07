//
//  View+EXT.swift
//  UserApp
//
//  Created by ChenZhen on 7/11/26.
//

import SwiftUI

extension View {
    /// Presents a toast that dismisses after the duration, restarting the countdown when its presentation ID changes.
    func toast<ID: Equatable>(
        message: LocalizedStringKey,
        presentationID: Binding<ID?>,
        duration: Duration = .seconds(5)
    ) -> some View {
        self.overlay(alignment: .bottom) {
            ZStack {
                if presentationID.wrappedValue != nil {
                    AppToastView(message: message)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: presentationID.wrappedValue)
            .allowsHitTesting(false)
        }
        .task(id: presentationID.wrappedValue) {
            guard let toastID = presentationID.wrappedValue else { return }

            do {
                try await Task.sleep(for: duration)
            } catch {
                return
            }

            guard presentationID.wrappedValue == toastID else { return }
            presentationID.wrappedValue = nil
        }
    }
}

#if DEBUG
#Preview("Toast presentation and timer reset") {
    @Previewable @State var presentationID: UUID? = nil

    NavigationStack {
        Button("Show toast") {
            presentationID = UUID()
        }
        .navigationTitle("Toast preview")
    }
    .toast(
        message: "Couldn't refresh users. Tap Refresh to try again.",
        presentationID: $presentationID
    )
}
#endif
