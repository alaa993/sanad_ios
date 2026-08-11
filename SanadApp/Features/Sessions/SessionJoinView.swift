import SwiftUI
import UIKit
import Combine

struct SessionJoinView: View {
    let sessionId: Int
    let isSpecialist: Bool

    @EnvironmentObject private var authVM: AuthViewModel

    @State private var session: SessionItem?
    @State private var error: String?
    @State private var enableJoin = false
    @State private var joinStatus = ""
    @State private var scheduledAt: Date?
    @State private var realtimeCancellable: AnyCancellable?

    private let service = SessionsService()
    private let updater = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "session_join_title", subtitle: "session_join_hint")

                VStack(alignment: .leading, spacing: 14) {
                    if let err = error {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.error)
                    }

                    if let session = session {
                        sessionCard(session)
                    } else if error == nil {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await load() }
        .refreshable { await load() }
        .onAppear {
            authVM.reconnectRealtime()
            RealtimeSocket.shared.joinSession(sessionId: sessionId)
            subscribeRealtime()
            updateJoinStatus()
        }
        .onDisappear {
            RealtimeSocket.shared.leaveSession(sessionId: sessionId)
            realtimeCancellable?.cancel()
        }
        .onReceive(updater) { _ in updateJoinStatus() }
    }

    private func sessionCard(_ session: SessionItem) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(format: NSLocalizedString("session_join_type", comment: ""), labelForType(session.type)))
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.placeholder)
                Text(String(format: NSLocalizedString("session_join_schedule", comment: ""), formatSchedule(session.scheduled_at)))
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.placeholder)

                Text("session_join_status")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SanadTheme.placeholder)
                Text(joinStatus)
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)

                HStack(spacing: 10) {
                    if let chatId = session.chat_id, chatId > 0 {
                        NavigationLink(destination: ChatRoomView(
                            chatId: chatId,
                            chatTitle: labelForType(session.type),
                            sessionId: session.id,
                            sessionEndsAt: session.ends_at,
                            canExtend: isSpecialist
                        )) {
                            Text("session_join_open_chat")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                                .foregroundColor(SanadTheme.primary)
                        }
                        .disabled(!enableJoin)
                    }

                    if let link = session.join_url, !link.isEmpty {
                        NavigationLink(destination: SessionCallView(sessionId: sessionId, joinUrl: link, callMode: session.type ?? "video")) {
                            Text("session_join_in_app_call")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(SanadTheme.primary))
                                .foregroundColor(SanadTheme.onPrimary)
                        }
                        .disabled(!enableJoin)

                        Button("session_join_copy_link") {
                            UIPasteboard.general.string = link
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                        .foregroundColor(SanadTheme.primary)
                    } else {
                        NavigationLink(destination: SessionCallView(sessionId: sessionId, joinUrl: nil, callMode: session.type ?? "video")) {
                            Text("session_join_in_app_call")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(SanadTheme.primary))
                                .foregroundColor(SanadTheme.onPrimary)
                        }
                        .disabled(!enableJoin)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        do {
            let res = try await service.show(id: sessionId, token: token)
            await MainActor.run {
                self.session = res
                self.error = nil
                self.scheduledAt = parseIsoDate(res.scheduled_at)
                updateJoinStatus()
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("session_join_load_failed", comment: "") }
        }
    }

    private func updateJoinStatus() {
        guard let session = session else { return }
        let gate = SessionActionGate.evaluate(
            status: session.status,
            scheduledAt: scheduledAt ?? SessionActionGate.parseIsoDate(session.scheduled_at),
            isSpecialist: isSpecialist
        )
        enableJoin = gate.canJoin
        joinStatus = NSLocalizedString(gate.joinHintKey, comment: "")
        if let ends = session.ends_at, !ends.isEmpty {
            joinStatus += "\n" + String(format: NSLocalizedString("session_join_ends", comment: ""), formatSchedule(ends))
        }
    }

    private func labelForType(_ type: String?) -> String {
        guard let type = type, !type.isEmpty else { return NSLocalizedString("common_session", comment: "") }
        let value = type.lowercased()
        if value.contains("video") { return NSLocalizedString("session_type_video_label", comment: "") }
        if value.contains("voice") || value.contains("audio") { return NSLocalizedString("session_type_voice_label", comment: "") }
        if value.contains("chat") { return NSLocalizedString("session_type_chat_label", comment: "") }
        return type
    }

    private func formatSchedule(_ iso: String?) -> String {
        guard let iso = iso, let date = parseIsoDate(iso) else { return iso ?? NSLocalizedString("common_no_schedule", comment: "") }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd - hh:mm a"
        return formatter.string(from: date)
    }

    private func parseIsoDate(_ iso: String?) -> Date? {
        guard let iso = iso else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) { return date }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: iso)
    }

    private func subscribeRealtime() {
        realtimeCancellable = RealtimeSocket.shared.events
            .compactMap { event -> (String, [String: Any]?)? in
                if case .sessionStatus(let id, let status, let meta) = event, id == sessionId {
                    return (status, meta)
                }
                return nil
            }
            .receive(on: DispatchQueue.main)
            .sink { status, meta in
                if var current = session {
                    current = SessionItem(id: current.id,
                                          type: current.type,
                                          status: status,
                                          scheduled_at: current.scheduled_at,
                                          ends_at: meta?["ends_at"] as? String ?? current.ends_at,
                                          notes: current.notes,
                                          specialist_notes: current.specialist_notes,
                                          rating: current.rating,
                                          survey_submitted: current.survey_submitted,
                                          transferred_at: current.transferred_at,
                                          transfer_reason: current.transfer_reason,
                                          join_url: current.join_url,
                                          chat_id: current.chat_id,
                                          points_cost: current.points_cost,
                                          duration_minutes: current.duration_minutes,
                                          extended_minutes: current.extended_minutes,
                                          specialist: current.specialist,
                                          organization: current.organization,
                                          user: current.user)
                    session = current
                    updateJoinStatus()
                }
            }
    }
}

#Preview { NavigationView { SessionJoinView(sessionId: 1, isSpecialist: false) } }
