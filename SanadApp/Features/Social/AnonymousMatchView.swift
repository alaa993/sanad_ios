import SwiftUI

struct AnonymousMatchView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var gender = "male"
    @State private var matchGender = "any"
    @State private var mode = "chat"
    @State private var statusText = NSLocalizedString("anonymous_match_idle", comment: "")
    @State private var current: AnonymousMatchData?
    @State private var loading = false
    @State private var error: String?

    private let service = AnonymousMatchService()
    private let genders = ["male", "female", "other"]
    private let preferences = ["any", "same", "male", "female"]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "anonymous_match_title", subtitle: "anonymous_match_subtitle")

                VStack(alignment: .leading, spacing: 16) {
                    SanadListCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Picker("anonymous_match_gender", selection: $gender) {
                                ForEach(genders, id: \.self) { g in
                                    Text(localizedGender(g)).tag(g)
                                }
                            }
                            .pickerStyle(.segmented)

                            Picker("anonymous_match_preference", selection: $matchGender) {
                                ForEach(preferences, id: \.self) { p in
                                    Text(localizedPreference(p)).tag(p)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("anonymous_match_mode", selection: $mode) {
                                Text("anonymous_match_mode_chat").tag("chat")
                                Text("anonymous_match_mode_voice").tag("voice")
                            }
                            .pickerStyle(.segmented)

                            Text(statusText)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(SanadTheme.onBg)

                            if let err = error {
                                Text(err).font(.system(size: 13)).foregroundColor(SanadTheme.error)
                            }
                        }
                    }

                    Button("anonymous_match_find") { Task { await join() } }
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(SanadTheme.primary))
                        .foregroundColor(SanadTheme.onPrimary)
                        .disabled(loading)

                    if isMatched {
                        NavigationLink(destination: ChatRoomView(chatId: current?.chat_id ?? 0, chatTitle: NSLocalizedString("anonymous_match_title", comment: "")).environmentObject(authVM)) {
                            Text("anonymous_match_open_chat")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Capsule().stroke(SanadTheme.primary, lineWidth: 1))
                                .foregroundColor(SanadTheme.primary)
                        }

                        Button("community_vent_report") { Task { await report() } }
                            .font(.system(size: 14))
                            .foregroundColor(SanadTheme.error)
                    }

                    Button("common_cancel") { Task { await leave() } }
                        .font(.system(size: 14))
                        .foregroundColor(SanadTheme.placeholder)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    private var isMatched: Bool {
        current?.status == "matched" && (current?.chat_id ?? 0) > 0
    }

    private func refresh() async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            let data = try await service.status(token: token)
            await MainActor.run { bind(data) }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("anonymous_match_error", comment: "") }
        }
    }

    private func join() async {
        guard let token = KeychainHelper.getToken() else { return }
        loading = true
        defer { loading = false }
        do {
            let data = try await service.join(gender: gender, matchGender: matchGender, mode: mode, token: token)
            await MainActor.run {
                bind(data)
                error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("anonymous_match_error", comment: "") }
        }
    }

    private func leave() async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            if let id = current?.id, isMatched {
                try await service.end(id: id, token: token)
            }
            try await service.leave(token: token)
            await MainActor.run {
                current = nil
                bind(nil)
            }
        } catch { }
    }

    private func report() async {
        guard let token = KeychainHelper.getToken(), let id = current?.id else { return }
        do {
            try await service.report(id: id, token: token)
            await MainActor.run {
                current = nil
                bind(nil)
            }
        } catch { }
    }

    private func bind(_ data: AnonymousMatchData?) {
        current = data
        if let data {
            let partner = data.alias_partner ?? "—"
            statusText = String(format: NSLocalizedString("anonymous_match_status_fmt", comment: ""), data.status ?? "—", partner)
        } else {
            statusText = NSLocalizedString("anonymous_match_idle", comment: "")
        }
    }

    private func localizedGender(_ g: String) -> String {
        switch g {
        case "female": return NSLocalizedString("anonymous_gender_female", comment: "")
        case "other": return NSLocalizedString("anonymous_gender_other", comment: "")
        default: return NSLocalizedString("anonymous_gender_male", comment: "")
        }
    }

    private func localizedPreference(_ p: String) -> String {
        switch p {
        case "same": return NSLocalizedString("anonymous_pref_same", comment: "")
        case "male": return NSLocalizedString("anonymous_gender_male", comment: "")
        case "female": return NSLocalizedString("anonymous_gender_female", comment: "")
        default: return NSLocalizedString("anonymous_pref_any", comment: "")
        }
    }
}
