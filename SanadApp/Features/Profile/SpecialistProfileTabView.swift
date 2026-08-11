import SwiftUI

/// تبويب ملف الأخصائي — مطابق لـ `SpecialistProfileFragment`.
struct SpecialistProfileTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.defaultLanguage.rawValue
    @AppStorage(AppTheme.storageKey) private var appTheme = AppTheme.defaultTheme.rawValue

    @State private var profile: SpecialistProfileData?
    @State private var loading = false
    @State private var showEdit = false
    @State private var showChangePassword = false
    @State private var showLogoutConfirm = false
    @State private var profileToast: String?

    private let service = SpecialistProfileService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(
                    title: LocalizedStringKey(profile?.user?.name ?? authVM.currentUser?.name ?? "—"),
                    subtitle: "specialist_profile"
                )

                VStack(alignment: .trailing, spacing: 16) {
                    profileAvatarRow

                    Text(statusLabel(profile?.status))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(SanadTheme.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    if loading { ProgressView() }
                    if let p = profile { specialistFields(p) }
                    actionRows
                    PushPreferencesSection()
                    languageSection
                    themeSection
                    contentLinks
                    logoutButton
                    if let profileToast {
                        Text(profileToast)
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.placeholder)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await loadProfile() }
        .sheet(isPresented: $showEdit) {
            SpecialistEditView(profile: profile) { Task { await loadProfile() } }
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordSheet {
                profileToast = NSLocalizedString("profile_password_updated", comment: "")
            }
        }
        .confirmationDialog("profile_logout", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("profile_logout", role: .destructive) { authVM.logout() }
            Button("common_cancel", role: .cancel) {}
        }
    }

    private var profileAvatarRow: some View {
        HStack {
            Spacer(minLength: 0)
            profileAvatar
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var profileAvatar: some View {
        let name = profile?.user?.name ?? authVM.currentUser?.name ?? "—"
        let initial = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
        ZStack {
            Circle()
                .fill(SanadTheme.primary.opacity(0.12))
            Text(initial.isEmpty ? "—" : initial)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(SanadTheme.primary)
            if let urlString = profile?.avatar, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Color.clear
                    }
                }
                .clipShape(Circle())
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(Circle())
        .overlay(Circle().stroke(SanadTheme.card, lineWidth: 3))
        .offset(y: -28)
        .padding(.bottom, -20)
    }

    private func specialistFields(_ p: SpecialistProfileData) -> some View {
        SanadListCard {
            VStack(alignment: .trailing, spacing: 8) {
                row("profile_email", value: p.user?.email ?? NSLocalizedString("profile_not_available", comment: ""))
                row("specialist_profile_specialty", value: p.specialty ?? NSLocalizedString("specialist_profile_specialty_unset", comment: ""))
                row("specialist_edit_years", value: "\(p.years_exp ?? 0)")
                if let rate = p.rate_cents, rate > 0, let cur = p.currency {
                    row("specialist_profile_price", value: String(format: NSLocalizedString("specialist_rate_format", comment: ""), cur.uppercased(), Float(rate) / 100))
                } else {
                    row("specialist_profile_price", value: NSLocalizedString("specialist_profile_specialty_unset", comment: ""))
                }
                let accepting = SpecialistAccepting.isAccepting(p.accepting_new)
                    ? NSLocalizedString("specialist_accepting_yes", comment: "")
                    : NSLocalizedString("specialist_accepting_no", comment: "")
                row("specialist_edit_accepting", value: accepting)
                row("specialist_profile_languages", value: p.languages?.joined(separator: " · ") ?? NSLocalizedString("specialist_profile_specialty_unset", comment: ""))
                if let notes = p.verification_notes, !notes.isEmpty {
                    row("specialist_profile_verification_notes", value: notes)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func row(_ key: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(value).font(.system(size: 14)).foregroundColor(SanadTheme.onBg)
            Spacer()
            Text(key).font(.system(size: 12)).foregroundColor(SanadTheme.placeholder)
        }
    }

    private var actionRows: some View {
        VStack(spacing: 10) {
            navRow("specialist_edit") { showEdit = true }
            if let p = profile {
                NavigationLink(destination: SpecialistInfoView(profile: p)) {
                    actionRowLabel("specialist_info")
                }
                .buttonStyle(.plain)
            } else {
                navRow("specialist_info") { }
                    .disabled(true)
            }
            navRow("admin_profile_change_password") { showChangePassword = true }
            NavigationLink(destination: WalletView()) {
                actionRowLabel("nav_wallet")
            }
            .buttonStyle(.plain)
            NavigationLink(destination: SpecialistDocumentsView()) {
                actionRowLabel("specialist_documents")
            }
            .buttonStyle(.plain)
        }
    }

    private var contentLinks: some View {
        VStack(spacing: 10) {
            pageLink(.contact)
            pageLink(.privacy)
        }
    }

    private var languageSection: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("language_settings").font(.system(size: 15, weight: .medium))
            Picker("", selection: $appLanguage) {
                ForEach(AppLanguage.allCases) { Text($0.titleKey).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
        }
        .coachMarkTarget("profile_language")
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(SanadTheme.card))
    }

    private var themeSection: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("theme_settings").font(.system(size: 15, weight: .medium))
            Picker("", selection: $appTheme) {
                ForEach(AppTheme.allCases) { Text($0.titleKey).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
        }
        .coachMarkTarget("profile_theme")
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(SanadTheme.card))
    }

    private var logoutButton: some View {
        Button("profile_logout") { showLogoutConfirm = true }
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(SanadTheme.primary)
            .coachMarkTarget("profile_logout")
    }

    private func navRow(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            actionRowLabel(title)
        }
        .buttonStyle(.plain)
    }

    private func actionRowLabel(_ title: LocalizedStringKey) -> some View {
        HStack {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(SanadTheme.onBg)
            Spacer()
            SanadIcon.chevronLeft.image.foregroundColor(SanadTheme.placeholder)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(SanadTheme.card))
    }

    private func pageLink(_ type: StaticPageView.PageType) -> some View {
        NavigationLink(destination: StaticPageView(type: type)) {
            HStack {
                Text(type.titleKey).font(.system(size: 15, weight: .semibold)).foregroundColor(SanadTheme.onBg)
                Spacer()
                SanadIcon.chevronLeft.image.foregroundColor(SanadTheme.placeholder)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(SanadTheme.card))
        }
        .coachMarkTarget(type == .contact ? "profile_contact" : "profile_privacy")
    }

    private func statusLabel(_ status: String?) -> String {
        switch status?.lowercased() {
        case "approved": return NSLocalizedString("specialist_verification_approved", comment: "")
        case "rejected": return NSLocalizedString("specialist_verification_rejected", comment: "")
        case "under_review": return NSLocalizedString("specialist_verification_under_review", comment: "")
        default: return NSLocalizedString("specialist_verification_pending", comment: "")
        }
    }

    private func loadProfile() async {
        guard let token = KeychainHelper.getToken() else { return }
        loading = true
        defer { loading = false }
        profile = try? await service.fetchProfile(token: token)
    }
}
