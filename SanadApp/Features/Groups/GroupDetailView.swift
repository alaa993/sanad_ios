import SwiftUI
import Combine

struct GroupDetailView: View {
    let groupId: Int

    @State private var group: GroupSession?
    @State private var loading = false
    @State private var error: String?
    @State private var liveCount: Int?
    @State private var presenceCancellable: AnyCancellable?

    private let service = GroupSessionsService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let err = error {
                    Text(err).foregroundColor(.red)
                }

                if loading {
                    ProgressView()
                }

                if let group = group {
                    headerCard(group)
                    actionsCard(group)
                }
            }
            .padding(20)
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationTitle("group_detail_title")
        .task { await load() }
        .refreshable { await load() }
        .onAppear {
            RealtimeSocket.shared.joinGroup(groupId: groupId)
            subscribePresence()
        }
        .onDisappear {
            RealtimeSocket.shared.leaveGroup(groupId: groupId)
            presenceCancellable?.cancel()
        }
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        do {
            let res = try await service.show(id: groupId, token: token)
            await MainActor.run {
                group = res
                liveCount = res.participants_count
                error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("group_detail_load_failed", comment: "") }
        }
        loading = false
    }

    private func headerCard(_ group: GroupSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.title ?? NSLocalizedString("groups_default_title", comment: ""))
                .font(.system(size: 20, weight: .semibold))
            if let status = group.status {
                Text(String(format: NSLocalizedString("group_detail_status", comment: ""), statusLabel(status)))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
            }
            Text(String(format: NSLocalizedString("group_detail_schedule", comment: ""), formatSchedule(start: group.start_at, end: group.end_at)))
                .font(.system(size: 12))
                .foregroundColor(SanadTheme.placeholder)
            if let topic = group.topic, !topic.isEmpty {
                Text(String(format: NSLocalizedString("group_detail_topic", comment: ""), topic))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
            }
            if let specialist = group.specialist_name {
                Text(String(format: NSLocalizedString("group_detail_specialist", comment: ""), specialist))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
            }
            if let count = liveCount {
                Text(String(format: NSLocalizedString("group_detail_live_count", comment: ""), count))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(SanadTheme.card))
        .shadow(color: SanadTheme.subtleShadow, radius: 4, y: 3)
    }

    private func actionsCard(_ group: GroupSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if group.joined == true {
                if let chatId = group.chat_id, chatId > 0 {
                    NavigationLink(destination: ChatRoomView(
                        chatId: chatId,
                        chatTitle: group.title,
                        sessionId: nil,
                        sessionEndsAt: group.end_at,
                        canExtend: false
                    )) {
                        Text("group_detail_open_chat")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                            .foregroundColor(SanadTheme.primary)
                    }
                }

                if (group.type ?? "").lowercased() != "chat" {
                    NavigationLink(destination: GroupCallView(groupId: group.id, callMode: group.type ?? "video", joinUrl: group.join_url)) {
                        Text("session_join_in_app_call")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(SanadTheme.primary))
                            .foregroundColor(SanadTheme.onPrimary)
                    }
                }

                Button("group_detail_leave") { Task { await leaveGroup() } }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.red)
            } else {
                Button("group_detail_join") { Task { await joinGroup() } }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(SanadTheme.primary))
                    .foregroundColor(SanadTheme.onPrimary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(SanadTheme.card))
        .shadow(color: SanadTheme.subtleShadow, radius: 4, y: 3)
    }

    private func joinGroup() async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            let res = try await service.join(id: groupId, token: token)
            await MainActor.run {
                group = res
                liveCount = res.participants_count
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("group_detail_join_failed", comment: "") }
        }
    }

    private func leaveGroup() async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            let res = try await service.leave(id: groupId, token: token)
            await MainActor.run {
                group = res
                liveCount = res.participants_count
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("group_detail_leave_failed", comment: "") }
        }
    }

    private func subscribePresence() {
        presenceCancellable = RealtimeSocket.shared.events
            .compactMap { event -> (Int, Int)? in
                if case .groupPresence(let id, let count) = event {
                    return (id, count)
                }
                return nil
            }
            .receive(on: DispatchQueue.main)
            .sink { id, count in
                guard id == groupId else { return }
                liveCount = count
            }
    }

    private func statusLabel(_ raw: String) -> String {
        switch raw.lowercased() {
        case "scheduled":
            return NSLocalizedString("group_status_upcoming", comment: "")
        case "ongoing", "in_progress":
            return NSLocalizedString("group_status_live", comment: "")
        case "finished", "completed":
            return NSLocalizedString("group_status_completed", comment: "")
        case "canceled", "cancelled":
            return NSLocalizedString("group_status_cancelled", comment: "")
        default:
            return raw
        }
    }

    private func formatSchedule(start: String?, end: String?) -> String {
        guard let start = start, let startDate = parseIsoDate(start) else { return start ?? "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd - hh:mm a"
        let startText = formatter.string(from: startDate)
        if let end = end, let endDate = parseIsoDate(end) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "hh:mm a"
            return startText + " - " + timeFormatter.string(from: endDate)
        }
        return startText
    }

    private func parseIsoDate(_ iso: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) { return date }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: iso)
    }
}

#Preview { NavigationView { GroupDetailView(groupId: 1) } }
