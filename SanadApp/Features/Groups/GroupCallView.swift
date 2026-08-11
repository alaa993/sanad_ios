import SwiftUI

struct GroupCallView: View {
    let groupId: Int
    let callMode: String
    let joinUrl: String?

    @State private var liveKit: LiveKitTokenResponse?
    @State private var error: String?
    @State private var loading = false

    private let service = GroupSessionsService()

    var body: some View {
        VStack(spacing: 12) {
            if let joinUrl = joinUrl, !joinUrl.isEmpty, let url = URL(string: joinUrl) {
                WebView(url: url)
                    .ignoresSafeArea()
            } else {
                if loading {
                    ProgressView()
                } else if let err = error {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                } else if let liveKit = liveKit {
                    LiveKitCallView(sessionId: groupId, callMode: callMode, liveKit: liveKit)
                } else {
                    Text("session_call_connecting")
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
            }
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationTitle("session_call_title")
        .task { await loadLiveKit() }
    }

    private func loadLiveKit() async {
        guard joinUrl == nil || joinUrl?.isEmpty == true else { return }
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        do {
            let res = try await service.liveKitToken(id: groupId, token: token)
            await MainActor.run {
                self.liveKit = res
                self.error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("session_call_start_failed", comment: "") }
        }
        loading = false
    }
}

#Preview { GroupCallView(groupId: 1, callMode: "video", joinUrl: nil) }
