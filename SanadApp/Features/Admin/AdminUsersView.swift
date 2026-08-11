import SwiftUI

struct AdminUsersView: View {
    @State private var users: [AdminUser] = []
    @State private var loading = false
    @State private var error: String?

    private let service = AdminService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "admin_users_title")

                VStack(alignment: .leading, spacing: 14) {
                    if loading && users.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                    } else if let err = error {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.error)
                    } else if users.isEmpty {
                        SanadEmptyState(message: "common_no_items")
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(users) { user in
                                userCard(user)
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

    private func userCard(_ user: AdminUser) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(user.name ?? NSLocalizedString("common_user", comment: ""))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                Text(user.email ?? NSLocalizedString("admin_user_no_email", comment: ""))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
                if let role = user.role {
                    Text(String(format: NSLocalizedString("admin_user_role", comment: ""), role))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
                if let status = user.status {
                    Text(String(format: NSLocalizedString("admin_user_status", comment: ""), status))
                        .font(.system(size: 12))
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
        do {
            let res = try await service.users(token: token)
            await MainActor.run {
                self.users = res
                self.error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("admin_users_load_failed", comment: "") }
        }
        loading = false
    }
}

#Preview { NavigationView { AdminUsersView() } }
