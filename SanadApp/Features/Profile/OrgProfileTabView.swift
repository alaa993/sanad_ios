import SwiftUI

/// تبويب ملف المنظمة — يعرض حالة المراجعة وإعادة الإرسال.
struct OrgProfileTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.defaultLanguage.rawValue
    @AppStorage(AppTheme.storageKey) private var appTheme = AppTheme.defaultTheme.rawValue

    @State private var showChangePassword = false
    @State private var showLogoutConfirm = false
    @State private var profileToast: String?

    private var org: User.OrgProfile? { authVM.currentUser?.org_profile }
    private var status: String? {
        authVM.currentUser?.organization_status ?? org?.status
    }

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack { contentBody }
            } else {
                NavigationView { contentBody }
            }
        }
    }

    private var contentBody: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 16) {
                heroHeader
                orgInfoCard
                NavigationLink(destination: WalletView()) {
                    HStack {
                        Text("nav_wallet").font(.system(size: 15, weight: .semibold)).foregroundColor(SanadTheme.onBg)
                        Spacer()
                        SanadIcon.chevronLeft.image.foregroundColor(SanadTheme.placeholder)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(SanadTheme.card))
                }
                .buttonStyle(.plain)
                NavigationLink(destination: OrgBillingView()) {
                    HStack {
                        Text("org_billing_title").font(.system(size: 15, weight: .semibold)).foregroundColor(SanadTheme.onBg)
                        Spacer()
                        SanadIcon.chevronLeft.image.foregroundColor(SanadTheme.placeholder)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(SanadTheme.card))
                }
                .buttonStyle(.plain)
                if status?.lowercased() == "rejected" {
                    Button("profile_resubmit") {
                        Task { await authVM.resubmit() }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(SanadTheme.primary))
                    .foregroundColor(SanadTheme.onPrimary)
                }
                PushPreferencesSection()
                changePasswordRow
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
            .padding(20)
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationTitle("profile_title")
        .navigationBarHidden(true)
        .task {
            // Soft refresh only when org status payload is missing from bootstrap.
            if authVM.currentUser?.org_profile == nil {
                await authVM.refreshUser()
            }
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

    private var heroHeader: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [SanadTheme.primary, SanadTheme.primaryDark], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 150)
            VStack(alignment: .trailing, spacing: 8) {
                Text(org?.name ?? authVM.currentUser?.name ?? "—")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                Text(statusLabel(status))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(20)
        }
    }

    private var orgInfoCard: some View {
        VStack(alignment: .trailing, spacing: 8) {
            row("profile_email", value: authVM.currentUser?.email ?? NSLocalizedString("profile_not_available", comment: ""))
            row("profile_phone", value: authVM.currentUser?.phone ?? NSLocalizedString("profile_not_available", comment: ""))
            row("profile_account_status", value: statusLabel(status))
            if let org {
                Text(String(format: NSLocalizedString("profile_org_stats_fmt", comment: ""), org.members ?? 0, org.specialists ?? 0, org.beneficiaries ?? 0))
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.placeholder)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if let notes = authVM.currentUser?.org_rejection_reason ?? org?.review_notes, !notes.isEmpty {
                Text("profile_rejected_hint")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.trailing)
                Text(notes)
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.onBg)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(SanadTheme.card))
    }

    private func row(_ key: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(value).font(.system(size: 14)).foregroundColor(SanadTheme.onBg)
            Spacer()
            Text(key).font(.system(size: 12)).foregroundColor(SanadTheme.placeholder)
        }
    }

    private var changePasswordRow: some View {
        Button { showChangePassword = true } label: {
            HStack {
                Text("admin_profile_change_password")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                Spacer()
                SanadIcon.chevronLeft.image.foregroundColor(SanadTheme.placeholder)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(SanadTheme.card))
        }
        .buttonStyle(.plain)
    }

    private var contentLinks: some View {
        VStack(spacing: 10) {
            pageLink(.contact)
            pageLink(.about)
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
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(SanadTheme.card))
    }

    private var logoutButton: some View {
        Button("profile_logout") { showLogoutConfirm = true }
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(SanadTheme.primary)
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
    }

    private func statusLabel(_ status: String?) -> String {
        switch status?.lowercased() {
        case "approved": return NSLocalizedString("specialist_verification_approved", comment: "")
        case "rejected": return NSLocalizedString("specialist_verification_rejected", comment: "")
        case "under_review": return NSLocalizedString("specialist_verification_under_review", comment: "")
        default: return NSLocalizedString("specialist_verification_pending", comment: "")
        }
    }
}
