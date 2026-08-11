import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.defaultLanguage.rawValue
    @AppStorage(AppTheme.storageKey) private var appTheme = AppTheme.defaultTheme.rawValue

    @State private var showChangePassword = false
    @State private var showEditName = false
    @State private var showLogoutConfirm = false
    @State private var editName = ""
    @State private var profileToast: String?
    @State private var deleteAccountURL: URL = AppConfig.deleteAccountURL

    private var role: String { (authVM.userRole ?? "patient").lowercased() }
    private var isPatient: Bool { role.contains("patient") || role.isEmpty }
    private var isOrganization: Bool { role.contains("organization") }

    private var statusText: String {
        NSLocalizedString("profile_status_active", comment: "")
    }

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack { contentBody }
            } else {
                NavigationView { contentBody }
            }
        }
        .onChange(of: appLanguage) { newValue in
            Task { await syncLocale(newValue) }
        }
        .alert("profile_full_name", isPresented: $showEditName) {
            TextField("profile_full_name", text: $editName)
            Button("save") { Task { await saveName() } }
            Button("common_cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordSheet {
                profileToast = NSLocalizedString("profile_password_updated", comment: "")
                authVM.requestTab(.dashboard)
            }
        }
        .confirmationDialog("profile_logout", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("profile_logout", role: .destructive) { authVM.logout() }
            Button("common_cancel", role: .cancel) {}
        }
    }

    private func saveName() async {
        let trimmed = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, let token = KeychainHelper.getToken() else { return }
        do {
            try await ProfileService().updateProfile(token: token, body: ["name": trimmed])
            await authVM.refreshUser()
            await MainActor.run { profileToast = NSLocalizedString("admin_profile_saved", comment: "") }
        } catch {
            await MainActor.run { profileToast = NSLocalizedString("static_page_load_failed", comment: "") }
        }
    }

    private func syncLocale(_ code: String) async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await ProfileService().updateProfile(token: token, body: ["locale": code])
        } catch {}
    }

    private var contentBody: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(
                    title: LocalizedStringKey(authVM.currentUser?.name ?? "—"),
                    subtitle: "profile_title"
                )

                VStack(alignment: .trailing, spacing: 20) {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(SanadTheme.primary.opacity(0.15))
                            .frame(width: 68, height: 68)
                            .overlay(
                                Text(initials)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(SanadTheme.primary)
                            )
                    }
                    infoSection
                statusCard
                PushPreferencesSection()
                changePasswordRow
                if isPatient {
                    walletRow
                }
                languageSection
                themeSection
                contentLinks
                deleteAccountRow
                if let passwordToast = profileToast {
                    Text(passwordToast)
                        .font(.system(size: 13))
                        .foregroundColor(SanadTheme.placeholder)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                logoutButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 24)
            }
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationBarHidden(true)
        .coachMarks(key: "tour_profile", steps: [
            CoachMarkStep(id: "lang", title: "tour_profile_language_title", desc: "tour_profile_language_desc", targetId: "profile_language"),
            CoachMarkStep(id: "theme", title: "tour_profile_theme_title", desc: "tour_profile_theme_desc", targetId: "profile_theme"),
            CoachMarkStep(id: "contact", title: "tour_profile_contact_title", desc: "tour_profile_contact_desc", targetId: "profile_contact"),
            CoachMarkStep(id: "privacy", title: "tour_profile_privacy_title", desc: "tour_profile_privacy_desc", targetId: "profile_privacy")
        ])
    }

    private var infoSection: some View {
        SanadListCard {
            VStack(alignment: .trailing, spacing: 12) {
                HStack {
                    Spacer()
                    Text("profile_account_info")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(SanadTheme.placeholder)
                }
                VStack(spacing: 12) {
                    ForEach(infoRows) { row in
                        infoRowView(row)
                    }
                    if isPatient {
                        Text("register_patient_privacy_note")
                            .font(.system(size: 12))
                            .foregroundColor(SanadTheme.placeholder)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var changePasswordRow: some View {
        Button {
            showChangePassword = true
        } label: {
            HStack {
                Text("admin_profile_change_password")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                Spacer()
                SanadIcon.chevronLeft.image
                    .foregroundColor(SanadTheme.placeholder)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(SanadTheme.card))
            .shadow(color: SanadTheme.subtleShadow, radius: 4, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var deleteAccountRow: some View {
        Link(destination: deleteAccountURL) {
            HStack {
                Text("menu_delete_account")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.red)
                Spacer()
                SanadIcon.chevronLeft.image
                    .foregroundColor(SanadTheme.placeholder)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(SanadTheme.card))
            .shadow(color: SanadTheme.subtleShadow, radius: 4, y: 3)
        }
    }

    private var logoutButton: some View {
        Button("profile_logout") {
            showLogoutConfirm = true
        }
        .font(.system(size: 16, weight: .semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Capsule().fill(SanadTheme.primary.opacity(0.1)))
        .foregroundColor(SanadTheme.primary)
        .coachMarkTarget("profile_logout")
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(SanadTheme.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(SanadTheme.surface.opacity(0.3)))
    }

    private var infoRows: [ProfileInfoRow] {
        let user = authVM.currentUser
        var rows: [ProfileInfoRow] = [
            ProfileInfoRow(icon: "person.fill", label: "profile_full_name", value: user?.name ?? "—")
        ]
        if !isPatient {
            rows.append(ProfileInfoRow(
                icon: "envelope.fill",
                label: "profile_email",
                value: user?.email ?? NSLocalizedString("profile_not_available", comment: "")
            ))
            rows.append(ProfileInfoRow(
                icon: "phone.fill",
                label: "profile_phone",
                value: user?.phone ?? NSLocalizedString("profile_not_available", comment: "")
            ))
        }
        return rows
    }

    private var initials: String {
        guard let raw = authVM.currentUser?.name.trimmingCharacters(in: .whitespacesAndNewlines),
              let first = raw.first else {
            return NSLocalizedString("profile_initial_placeholder", comment: "")
        }
        return String(first)
    }

    private func infoRowView(_ row: ProfileInfoRow) -> some View {
        Button {
            if row.icon == "person.fill" {
                editName = authVM.currentUser?.name ?? ""
                showEditName = true
            }
        } label: {
            HStack {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(row.label)
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                    Text(row.value)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SanadTheme.onBg)
                }
                Spacer()
                SanadIcon.forShortcut(id: row.icon).image
                    .foregroundColor(SanadTheme.primary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(SanadTheme.primary.opacity(0.12)))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("profile_account_status")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)
            Text(statusText)
                .font(.system(size: 14))
                .foregroundColor(SanadTheme.primary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(SanadTheme.card))
        .shadow(color: SanadTheme.subtleShadow, radius: 6, y: 4)
    }

    private var walletRow: some View {
        NavigationLink(destination: WalletView()) {
            HStack {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("nav_wallet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(SanadTheme.onBg)
                    Text("wallet_redeem_desc")
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
                Spacer()
                SanadIcon.wallet.image
                    .foregroundColor(SanadTheme.primary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(SanadTheme.primary.opacity(0.12)))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(SanadTheme.card))
            .shadow(color: SanadTheme.subtleShadow, radius: 4, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var contentLinks: some View {
        VStack(spacing: 10) {
            pageLink(type: .contact, subtitle: "body_contact_hint")
            pageLink(type: .about, subtitle: "body_about_hint")
            pageLink(type: .privacy, subtitle: "body_privacy_hint")
        }
    }

    private var languageSection: some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack {
                Spacer()
                Text("language_settings")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SanadTheme.placeholder)
            }
            Picker("language_settings", selection: $appLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.titleKey).tag(language.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .coachMarkTarget("profile_language")
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(SanadTheme.card))
        .shadow(color: SanadTheme.subtleShadow, radius: 6, y: 4)
    }

    private var themeSection: some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack {
                Spacer()
                Text("theme_settings")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SanadTheme.placeholder)
            }
            Picker("theme_settings", selection: $appTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.titleKey).tag(theme.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .coachMarkTarget("profile_theme")
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(SanadTheme.card))
        .shadow(color: SanadTheme.subtleShadow, radius: 6, y: 4)
    }

    @ViewBuilder
    private func pageLink(type: StaticPageView.PageType, subtitle: LocalizedStringKey) -> some View {
        NavigationLink(destination: StaticPageView(type: type)) {
            HStack {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(type.titleKey)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(SanadTheme.onBg)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
                Spacer()
                SanadIcon.chevronLeft.image
                    .foregroundColor(SanadTheme.placeholder)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(SanadTheme.card))
            .shadow(color: SanadTheme.subtleShadow, radius: 4, y: 3)
        }
        .coachMarkTarget(coachTargetId(for: type))
    }

    private func coachTargetId(for type: StaticPageView.PageType) -> String {
        switch type {
        case .contact: return "profile_contact"
        case .privacy: return "profile_privacy"
        case .about: return "profile_about"
        }
    }

    private struct ProfileInfoRow: Identifiable {
        let id = UUID()
        let icon: String
        let label: LocalizedStringKey
        let value: String
    }
}

#Preview {
    ProfileView().environmentObject(AuthViewModel())
}
