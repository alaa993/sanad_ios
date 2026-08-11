import SwiftUI
import Combine

/// مطابق لـ `SpecialistSessionsFragment` — جلسات الأخصائي مع قبول/رفض/إعادة جدولة.
struct SpecialistSessionsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var scope = "pending"
    @State private var sessions: [SpecialistAppointment] = []
    @State private var loading = false
    @State private var error: String?
    @State private var toast: String?
    @State private var rescheduleTarget: SpecialistAppointment?
    @State private var rescheduleDate = Date()
    @State private var realtimeCancellable: AnyCancellable?

    private let service = SpecialistService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(
                    title: "specialist_dashboard_my_sessions",
                    subtitle: "sessions_header_subtitle",
                    showsBackButton: true
                )

                VStack(alignment: .leading, spacing: 16) {
                    Picker("sessions_filter", selection: $scope) {
                        Text("specialist_sessions_pending").tag("pending")
                        Text("specialist_sessions_upcoming").tag("upcoming")
                        Text("specialist_sessions_history").tag("history")
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 10) {
                        NavigationLink(destination: GroupsView().environmentObject(authVM)) {
                            Text("specialist_dashboard_group_sessions")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Capsule().stroke(SanadTheme.primary, lineWidth: 1))
                                .foregroundColor(SanadTheme.primary)
                        }
                        NavigationLink(destination: GroupCreateView(onCreated: { Task { await load() } })) {
                            Text("specialist_create_group_session")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                                .foregroundColor(SanadTheme.primary)
                        }
                    }

                    if let err = error {
                        SanadInlineBanner(err, style: .error)
                    }

                    if loading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }

                    if sessions.isEmpty && !loading {
                        SanadListCard {
                            SanadEmptyState(message: "specialist_sessions_empty")
                        }
                    }

                    ForEach(sessions) { session in
                        NavigationLink(
                            destination: SpecialistSessionDetailView(
                                sessionId: session.id,
                                patientId: session.patient_id ?? session.patient?.id ?? -1
                            )
                        ) {
                            sessionRow(session)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationBarHidden(true)
        .task(id: scope) { await load() }
        .refreshable { await load() }
        .onAppear { subscribeRealtime() }
        .onDisappear { realtimeCancellable?.cancel() }
        .sheet(item: $rescheduleTarget) { target in
            rescheduleSheet(target)
        }
        .alert(toast ?? "", isPresented: Binding(
            get: { toast != nil },
            set: { if !$0 { toast = nil } }
        )) {
            Button("common_ok", role: .cancel) {}
        }
    }

    private func subscribeRealtime() {
        authVM.reconnectRealtime()
        realtimeCancellable = RealtimeSocket.shared.events
            .receive(on: DispatchQueue.main)
            .sink { event in
                switch event {
                case .sessionStatus:
                    Task { await load() }
                case .notification(let type, _):
                    if type == "session:status" || type.hasPrefix("session") {
                        Task { await load() }
                    }
                default:
                    break
                }
            }
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else { return }
        loading = true
        defer { loading = false }
        do {
            let list = try await service.sessions(scope: scope, token: token)
            await MainActor.run {
                sessions = list
                error = nil
            }
        } catch _ {
            await MainActor.run { self.error = NSLocalizedString("specialist_dashboard_load_failed", comment: "") }
        }
    }

    private func sessionRow(_ session: SpecialistAppointment) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(patientDisplayName(session))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                Text(formatSchedule(session.scheduled_at))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
                let gate = SessionActionGate.evaluate(
                    status: session.status,
                    scheduledAt: SessionActionGate.parseIsoDate(session.scheduled_at),
                    isSpecialist: true
                )
                HStack(spacing: 8) {
                    if gate.canAccept {
                        Button("session_accept") { Task { await accept(session.id) } }
                            .buttonStyle(.borderedProminent)
                    }
                    if gate.canReject {
                        Button("session_reject") { Task { await reject(session.id) } }
                            .buttonStyle(.bordered)
                    }
                    if gate.canJoin || gate.phase == .waitingWindow || gate.phase == .joinable || gate.phase == .inProgress {
                        NavigationLink(destination: SessionCallView(
                            sessionId: session.id,
                            joinUrl: session.join_url,
                            callMode: session.type ?? "video"
                        )) {
                            Text("session_hub_join")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .disabled(!gate.canJoin)
                    }
                    if scope == "upcoming" {
                        Button("session_reschedule") { rescheduleTarget = session }
                            .font(.system(size: 12))
                    }
                }
            }
        }
    }

    private func patientDisplayName(_ session: SpecialistAppointment) -> String {
        session.patient_name ?? session.patient?.name ?? NSLocalizedString("role_patient", comment: "")
    }

    private func formatSchedule(_ iso: String?) -> String {
        guard let iso, let date = parseIsoDate(iso) else {
            return iso ?? "—"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func parseIsoDate(_ iso: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) { return date }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: iso)
    }

    private func rescheduleSheet(_ session: SpecialistAppointment) -> some View {
        NavigationView {
            VStack(spacing: 16) {
                DatePicker("session_reschedule_pick", selection: $rescheduleDate, displayedComponents: [.date, .hourAndMinute])
                Button("session_reschedule_confirm") {
                    Task {
                        guard let token = KeychainHelper.getToken() else { return }
                        try? await service.reschedule(id: session.id, startsAt: rescheduleDate, token: token)
                        await MainActor.run {
                            rescheduleTarget = nil
                            toast = NSLocalizedString("session_rescheduled", comment: "")
                        }
                        await load()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
            .navigationTitle("session_reschedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_cancel") { rescheduleTarget = nil }
                }
            }
        }
    }

    private func accept(_ id: Int) async {
        guard let token = KeychainHelper.getToken() else { return }
        try? await service.accept(id: id, token: token)
        await MainActor.run { toast = NSLocalizedString("session_accepted", comment: "") }
        await load()
    }

    private func reject(_ id: Int) async {
        guard let token = KeychainHelper.getToken() else { return }
        try? await service.reject(id: id, token: token)
        await MainActor.run { toast = NSLocalizedString("session_rejected", comment: "") }
        await load()
    }
}
