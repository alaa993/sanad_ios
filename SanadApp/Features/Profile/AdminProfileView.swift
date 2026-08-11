import SwiftUI
import PhotosUI

struct AdminProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var profile: AdminProfileData?
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var name = ""
    @State private var locale = ""
    @State private var phone = ""
    @State private var privacy = ""
    @State private var contact = ""
    @State private var platformFee = ""
    @State private var loading = true
    @State private var toast: String?
    @State private var showPasswordSheet = false
    @State private var showLogoutConfirm = false

    private let service = AdminProfileService()

    var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 16) {
                Text("admin_profile_title")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(SanadTheme.onBg)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                adminAvatarView

                PhotosPicker(selection: $avatarItem, matching: .images) {
                    Text("admin_profile_pick_avatar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SanadTheme.primary)
                }
                .onChange(of: avatarItem) {
                    Task { await pickAvatar() }
                }

                if loading {
                    ProgressView().frame(maxWidth: .infinity)
                }

                if let stats = profile?.stats {
                    adminStatsGrid(stats)
                }

                adminQuickLinks()

                Text("admin_profile_account_section")
                field("admin_profile_name", text: $name)
                field("admin_profile_locale", text: $locale)
                field("admin_profile_phone", text: $phone)

                if let email = profile?.email {
                    HStack {
                        Text(email)
                            .font(.system(size: 14))
                            .foregroundColor(SanadTheme.onBg)
                        Spacer()
                        Text("profile_email")
                            .font(.system(size: 12))
                            .foregroundColor(SanadTheme.placeholder)
                    }
                }

                field("privacy_policy", text: $privacy, axis: .vertical)
                field("contact_us", text: $contact, axis: .vertical)
                field("admin_profile_platform_fee", text: $platformFee)

                Button("admin_profile_save_profile") {
                    Task { await saveProfile() }
                }
                .buttonStyle(SanadPrimaryButtonStyle())

                Button("admin_profile_save_settings") {
                    Task { await saveSettings() }
                }
                .buttonStyle(SanadSecondaryButtonStyle())

                Button("admin_profile_change_password") {
                    showPasswordSheet = true
                }
                .buttonStyle(SanadSecondaryButtonStyle())

                PushPreferencesSection()

                NavigationLink(destination: AdminWalletView()) {
                    Text("nav_wallet")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().stroke(SanadTheme.primary, lineWidth: 1))
                        .foregroundColor(SanadTheme.primary)
                }

                Button("profile_logout") {
                    showLogoutConfirm = true
                }
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(SanadTheme.primary.opacity(0.1)))
                .foregroundColor(SanadTheme.primary)

                if let toast {
                    Text(toast)
                        .font(.system(size: 13))
                        .foregroundColor(SanadTheme.placeholder)
                }
            }
            .padding(20)
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .task { await load() }
        .sheet(isPresented: $showPasswordSheet) {
            ChangePasswordSheet(scope: .admin) {
                toast = NSLocalizedString("profile_password_updated", comment: "")
            }
        }
        .confirmationDialog("profile_logout", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("profile_logout", role: .destructive) { authVM.logout() }
            Button("common_cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func adminStatsGrid(_ stats: AdminProfileData.Stats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            statChip("admin_dashboard_specialists_pending", value: stats.pending_specialists ?? 0)
            statChip("admin_dashboard_orgs_pending", value: stats.pending_organizations ?? 0)
            statChip("admin_dashboard_users", value: stats.total_users ?? 0)
            statChip("admin_dashboard_sessions_week", value: stats.total_sessions ?? 0)
        }
    }

    private func statChip(_ titleKey: LocalizedStringKey, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titleKey)
                .font(.system(size: 11))
                .foregroundColor(SanadTheme.placeholder)
            Text("\(value)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(SanadTheme.onBg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(SanadTheme.card))
    }

    @ViewBuilder
    private func adminQuickLinks() -> some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text("admin_profile_quick_manage")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)
                .frame(maxWidth: .infinity, alignment: .trailing)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                NavigationLink(destination: AdminSpecialistsView()) {
                    quickLinkLabel("admin_specialists_title")
                }
                NavigationLink(destination: AdminOrganizationsView()) {
                    quickLinkLabel("admin_orgs_title")
                }
                NavigationLink(destination: AdminSessionsView()) {
                    quickLinkLabel("admin_sessions_view")
                }
                NavigationLink(destination: AdminUsersView()) {
                    quickLinkLabel("admin_users_title")
                }
                NavigationLink(destination: CommunityListView().environmentObject(authVM)) {
                    quickLinkLabel("shortcut_community")
                }
            }
        }
    }

    private func quickLinkLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(SanadTheme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).stroke(SanadTheme.primary.opacity(0.35), lineWidth: 1))
    }

    @ViewBuilder
    private var adminAvatarView: some View {
        if let data = avatarData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 88)
                .clipShape(Circle())
        } else if let urlString = profile?.avatar, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Circle().fill(SanadTheme.primary.opacity(0.15))
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(Circle())
        }
    }

    private func field(_ label: LocalizedStringKey, text: Binding<String>, axis: Axis = .horizontal) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(SanadTheme.placeholder)
            TextField("", text: text, axis: axis)
                .multilineTextAlignment(.trailing)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(SanadTheme.card))
        }
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else { return }
        loading = true
        defer { loading = false }
        do {
            let p = try await service.loadProfile(token: token)
            await MainActor.run {
                profile = p
                name = p.name ?? ""
                locale = p.locale ?? ""
                phone = p.phone ?? ""
                privacy = p.privacy_policy ?? ""
                contact = p.contact_info ?? ""
                if let fee = p.platform_fee_percent {
                    platformFee = "\(fee)"
                }
            }
        } catch {
            await MainActor.run { toast = NSLocalizedString("static_page_load_failed", comment: "") }
        }
    }

    private func saveProfile() async {
        guard let token = KeychainHelper.getToken() else { return }
        var body: [String: Any] = [:]
        if !name.isEmpty { body["name"] = name }
        if !locale.isEmpty { body["locale"] = locale }
        if !phone.isEmpty { body["phone"] = phone }
        do {
            try await service.updateProfile(token: token, body: body)
            await MainActor.run { toast = NSLocalizedString("admin_profile_saved", comment: "") }
            await authVM.refreshUser()
        } catch {
            await MainActor.run { toast = NSLocalizedString("static_page_load_failed", comment: "") }
        }
    }

    private func pickAvatar() async {
        guard let item = avatarItem,
              let data = try? await item.loadTransferable(type: Data.self),
              let token = KeychainHelper.getToken() else { return }
        do {
            _ = try await service.uploadAvatar(token: token, data: data)
            await MainActor.run { toast = NSLocalizedString("admin_avatar_uploaded", comment: "") }
            await load()
        } catch {
            await MainActor.run { toast = NSLocalizedString("admin_avatar_upload_failed", comment: "") }
        }
    }

    private func saveSettings() async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await service.saveSettings(token: token, privacy: privacy, contact: contact, platformFee: platformFee)
            await MainActor.run { toast = NSLocalizedString("admin_profile_saved", comment: "") }
        } catch {
            await MainActor.run { toast = NSLocalizedString("static_page_load_failed", comment: "") }
        }
    }
}
