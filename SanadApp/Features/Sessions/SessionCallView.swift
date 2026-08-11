import SwiftUI
import WebKit

struct SessionCallView: View {
    let sessionId: Int
    let joinUrl: String?
    let callMode: String

    @State private var liveKit: LiveKitTokenResponse?
    @State private var error: String?
    @State private var loading = false
    @State private var preferExternalLink = false

    private let liveKitService = LiveKitService()

    var body: some View {
        VStack(spacing: 12) {
            if preferExternalLink, let joinUrl = joinUrl, !joinUrl.isEmpty, let url = URL(string: joinUrl) {
                WebView(url: url)
                    .ignoresSafeArea()
            } else if loading {
                ProgressView()
            } else if let err = error {
                VStack(spacing: 12) {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    if let joinUrl = joinUrl, !joinUrl.isEmpty {
                        Button("session_call_open_link") {
                            preferExternalLink = true
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(SanadTheme.primary)
                    }
                    Button("cta_retry") {
                        Task { await loadLiveKit() }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SanadTheme.primary)
                }
            } else if let liveKit = liveKit {
                LiveKitCallView(sessionId: sessionId, callMode: callMode, liveKit: liveKit)
            } else {
                Text("session_call_connecting")
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
            }
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationTitle("session_call_title")
        .task { await loadLiveKit() }
    }

    private func loadLiveKit() async {
        preferExternalLink = false
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        do {
            let res = try await liveKitService.token(sessionId: sessionId, token: token)
            await MainActor.run {
                self.liveKit = res
                self.error = nil
            }
        } catch {
            await MainActor.run {
                // Fall back to external join link only when LiveKit token fails.
                if let joinUrl, !joinUrl.isEmpty {
                    self.preferExternalLink = true
                    self.error = nil
                } else {
                    self.error = NSLocalizedString("session_call_start_failed", comment: "")
                }
            }
        }
        loading = false
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.load(URLRequest(url: url))
        return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

#Preview { SessionCallView(sessionId: 1, joinUrl: "https://example.com", callMode: "video") }
