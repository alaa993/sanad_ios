import AuthenticationServices
import SwiftUI

struct AppleSignInButton: View {
    let onToken: (String, String?) -> Void
    let onError: () -> Void

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case .success(let auth):
                guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                      let tokenData = credential.identityToken,
                      let token = String(data: tokenData, encoding: .utf8) else {
                    onError()
                    return
                }
                var name: String?
                if let full = credential.fullName {
                    let parts = [full.givenName, full.familyName].compactMap { $0 }
                    if !parts.isEmpty { name = parts.joined(separator: " ") }
                }
                onToken(token, name)
            case .failure:
                onError()
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 44)
        .clipShape(Capsule())
    }
}
