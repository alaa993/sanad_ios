import SwiftUI

struct StaticPageView: View {
    enum PageType {
        case contact
        case privacy
        case about

        var titleKey: LocalizedStringKey {
            switch self {
            case .contact: return "contact_us"
            case .privacy: return "privacy_policy"
            case .about: return "about_us"
            }
        }

        var fallbackKey: LocalizedStringKey {
            switch self {
            case .contact: return "contact_us_body"
            case .privacy: return "privacy_policy_body"
            case .about: return "about_us_body"
            }
        }
    }

    let type: PageType
    @State private var content: String?
    @State private var error: String?
    @State private var loading = false
    @State private var webURL: URL?

    private let service = SettingsService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(type.titleKey)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                if let err = error {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                Group {
                    if type == .about {
                        Text(type.fallbackKey)
                    } else if let content = content {
                        Text(content)
                    } else {
                        Text(type.fallbackKey)
                    }
                }
                .font(.system(size: 15))
                .foregroundColor(SanadTheme.onBg)
                .multilineTextAlignment(.leading)

                if type == .privacy, let url = webURL {
                    Link(destination: url) {
                        Text("open_privacy_on_web")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(SanadTheme.primary))
                            .foregroundColor(SanadTheme.onPrimary)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(20)
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .task { await loadContent() }
    }

    private func loadContent() async {
        guard !loading else { return }
        if type == .about {
            content = nil
            webURL = nil
            return
        }
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            if type == .privacy { webURL = AppConfig.privacyPolicyURL }
            return
        }
        loading = true
        do {
            let settings = try await service.fetch(token: token)
            await MainActor.run {
                self.content = self.value(for: settings)
                self.error = nil
                if type == .privacy {
                    self.webURL = settings.resolvedPrivacyURL()
                }
            }
        } catch {
            await MainActor.run {
                self.error = NSLocalizedString("static_page_load_failed", comment: "")
                if type == .privacy {
                    self.webURL = AppConfig.privacyPolicyURL
                }
            }
        }
        loading = false
    }

    private func value(for settings: SettingsResponse) -> String? {
        switch type {
        case .contact: return settings.contact_info
        case .privacy: return settings.privacy_policy
        case .about: return nil
        }
    }
}

#Preview {
    Group {
        if #available(iOS 16.0, *) {
            NavigationStack { StaticPageView(type: .contact) }
        } else {
            NavigationView { StaticPageView(type: .contact) }
        }
    }
}
