import SwiftUI

struct PushPreferencesSection: View {
    @State private var pushEnabled = true

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack {
                Toggle("", isOn: $pushEnabled)
                    .labelsHidden()
                    .onChange(of: pushEnabled) { enabled in
                        Task {
                            let saved = await PushNotificationManager.shared.updatePreferences(enabled)
                            await MainActor.run { pushEnabled = saved }
                        }
                    }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("push_notifications_title")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(SanadTheme.onBg)
                    Text("push_notifications_subtitle")
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(SanadTheme.card))
        .shadow(color: SanadTheme.subtleShadow, radius: 6, y: 4)
        .task {
            let enabled = await PushNotificationManager.shared.loadPreferences()
            await MainActor.run { pushEnabled = enabled }
        }
    }
}
