import SwiftUI

struct NotificationsView: View {
    @State private var notifications: [AppNotification] = []
    @State private var loading = false
    @State private var error: String?

    private let service = NotificationService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "notifications_title", subtitle: "notifications_subtitle")

                VStack(alignment: .leading, spacing: 14) {
                    if loading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else if let err = error {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.error)
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(SanadTheme.surface)
                            )
                    } else if notifications.isEmpty {
                        SanadEmptyState(message: "notifications_empty")
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(notifications) { item in
                                notificationRow(item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await load() }
        .refreshable { await load() }
    }

    private func notificationRow(_ item: AppNotification) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title ?? "")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                    .opacity(item.read == true ? 0.65 : 1)
                Text(item.body ?? "")
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.placeholder)
                    .opacity(item.read == true ? 0.65 : 1)
                if let created = item.created_at, !created.isEmpty {
                    Text(created)
                        .font(.system(size: 11))
                        .foregroundColor(SanadTheme.placeholder)
                }
            }
        }
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        defer { loading = false }
        do {
            let list = try await service.list(token: token)
            await MainActor.run {
                notifications = list
                error = nil
            }
        } catch _ {
            await MainActor.run {
                notifications = []
                error = NSLocalizedString("notifications_load_failed", comment: "")
            }
        }
    }
}

#Preview {
    NotificationsView()
}
