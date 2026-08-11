import SwiftUI
import AuthenticationServices

/// زر فيسبوك — يفتح OAuth عبر المتصفح عند توفر معرّف التطبيق في Info.plist.
public struct FacebookLoginButton: View {
    public let onToken: (String) -> Void
    public let onConfigMissing: () -> Void
    public let onError: () -> Void

    public init(onToken: @escaping (String) -> Void, onConfigMissing: @escaping () -> Void, onError: @escaping () -> Void) {
        self.onToken = onToken
        self.onConfigMissing = onConfigMissing
        self.onError = onError
    }

    public var body: some View {
        Button {
            startLogin()
        } label: {
            Text("login_facebook")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(SanadTheme.fieldStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func startLogin() {
        guard let appId = Bundle.main.object(forInfoDictionaryKey: "FacebookAppID") as? String,
              !appId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              appId != "0" else {
            onConfigMissing()
            return
        }
        let redirect = "fb\(appId)://authorize"
        let scope = "public_profile,email"
        guard let url = URL(string: "https://www.facebook.com/v19.0/dialog/oauth?client_id=\(appId)&redirect_uri=\(redirect)&response_type=token&scope=\(scope)") else {
            onError()
            return
        }
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "fb\(appId)") { callbackURL, error in
            if error != nil {
                onError()
                return
            }
            guard let fragment = callbackURL?.fragment else {
                onError()
                return
            }
            let token = fragment.split(separator: "&")
                .compactMap { part -> String? in
                    let pieces = part.split(separator: "=", maxSplits: 1).map(String.init)
                    guard pieces.count == 2, pieces[0] == "access_token" else { return nil }
                    return pieces[1]
                }
                .first
            if let token, !token.isEmpty {
                onToken(token)
            } else {
                onError()
            }
        }
        session.presentationContextProvider = WebAuthContext.shared
        session.prefersEphemeralWebBrowserSession = true
        if !session.start() {
            onError()
        }
    }
}

private final class WebAuthContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthContext()
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
