import SwiftUI
import Combine

struct SessionsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var upcoming: [SessionItem] = []
    @State private var history: [SessionItem] = []
    @State private var error: String?
    @State private var loading = false
    @State private var showBook = false
    @State private var selectedStatus: String = "all"
    @State private var dateFrom: Date?
    @State private var dateTo: Date?
    @State private var showDateSheet = false
    @State private var realtimeCancellable: AnyCancellable?

    private let service = SessionsService()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    SanadHeroHeader(title: "sessions_title", subtitle: "sessions_header_subtitle")

                VStack(alignment: .leading, spacing: 16) {
                    headerCard

                    filterCard

                    if loading {
                        ProgressView()
                            .scaleEffect(0.8, anchor: .center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }

                    if let err = error {
                        SanadInlineBanner(err, style: .error)
                    }

                    sessionsSections
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
                }
            }
            .background(SanadTheme.surface.ignoresSafeArea())
            .navigationBarHidden(true)
            .task { await load() }
            .refreshable { await load() }
            .onAppear { subscribeRealtime() }
            .onDisappear { realtimeCancellable?.cancel() }
            .sheet(isPresented: $showBook) {
                BookSessionView(onCompleted: { showBook = false })
            }
            .sheet(isPresented: $showDateSheet) {
                datePickerSheet
            }
        }
        .coachMarks(key: "tour_sessions", steps: [
            CoachMarkStep(id: "ss_book", title: "tour_sessions_book_title", desc: "tour_sessions_book_desc", targetId: "ss_book"),
            CoachMarkStep(id: "ss_groups", title: "tour_sessions_groups_title", desc: "tour_sessions_groups_desc", targetId: "ss_groups"),
            CoachMarkStep(id: "ss_filter", title: "tour_sessions_filter_title", desc: "tour_sessions_filter_desc", targetId: "ss_filter"),
            CoachMarkStep(id: "ss_date", title: "tour_sessions_date_title", desc: "tour_sessions_date_desc", targetId: "ss_date")
        ])
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        do {
            let res = try await service.list(token: token)
            await MainActor.run {
                self.upcoming = res.upcoming
                self.history = res.history
                self.error = nil
            }
        } catch {
            await MainActor.run {
                self.error = NSLocalizedString("sessions_load_failed", comment: "")
            }
        }
        loading = false
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

    private var headerCard: some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("sessions_header_title")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(SanadTheme.onBg)
                Text("sessions_header_subtitle")
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.placeholder)
                HStack(spacing: 12) {
                    if isPatientRole {
                        Button("cta_new_session") { showBook = true }
                            .coachMarkTarget("ss_book")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .stroke(SanadTheme.primary, lineWidth: 1)
                            )
                            .foregroundColor(SanadTheme.primary)
                    }
                    NavigationLink(destination: GroupsView()) {
                        Text("sessions_group_cta")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .stroke(SanadTheme.primary, lineWidth: 1)
                            )
                            .foregroundColor(SanadTheme.primary)
                    }
                    .coachMarkTarget("ss_groups")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var filterCard: some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("sessions_filter_title")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(SanadTheme.onBg)
                filterChips
                    .coachMarkTarget("ss_filter")
                HStack(spacing: 10) {
                    Button("sessions_filter_clear") { clearFilters() }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                        .foregroundColor(SanadTheme.primary)
                    Button("sessions_filter_date_pick") { showDateSheet = true }
                        .coachMarkTarget("ss_date")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .stroke(SanadTheme.primary, lineWidth: 1)
                        )
                        .foregroundColor(SanadTheme.primary)
                    if dateFrom != nil || dateTo != nil {
                        Text(dateRangeText)
                            .font(.system(size: 12))
                            .foregroundColor(SanadTheme.placeholder)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var filterChips: some View {
        let items: [(String, LocalizedStringKey)] = [
            ("all", "sessions_filter_all"),
            ("pending", "sessions_filter_pending"),
            ("accepted", "sessions_filter_accepted"),
            ("completed", "sessions_filter_completed"),
            ("canceled", "sessions_filter_canceled")
        ]
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.0) { item in
                    Button {
                        selectedStatus = item.0
                    } label: {
                        Text(item.1)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedStatus == item.0 ? SanadTheme.primary : SanadTheme.primary.opacity(0.1))
                            )
                            .foregroundColor(selectedStatus == item.0 ? SanadTheme.onPrimary : SanadTheme.primary)
                    }
                }
            }
        }
    }

    private var sessionsSections: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(sectionOrder, id: \.self) { status in
                if selectedStatus == "all" || selectedStatus == status {
                    statusSection(status)
                }
            }
        }
    }

    private func statusSection(_ status: String) -> some View {
        let items = filteredSessions.filter { normalizeStatus($0.status) == status }
        return VStack(alignment: .leading, spacing: 10) {
            Text(sectionTitleKey(status))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(SanadTheme.primary)
            if items.isEmpty {
                SanadEmptyState(message: sectionEmptyKey(status))
            } else {
                ForEach(items) { s in
                    NavigationLink(destination: SessionDetailView(sessionId: s.id)) {
                        sessionCard(s)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var isPatientRole: Bool {
        let role = authVM.currentUser?.role.lowercased()
        return role == nil || role?.isEmpty == true || role == "patient"
    }

    private var allSessions: [SessionItem] {
        (upcoming + history)
    }

    private var filteredSessions: [SessionItem] {
        allSessions.filter { session in
            let statusMatch = selectedStatus == "all" || normalizeStatus(session.status) == selectedStatus
            let dateMatch = matchDateRange(session.scheduled_at)
            return statusMatch && dateMatch
        }
    }

    private var sectionOrder: [String] {
        ["pending", "accepted", "completed", "canceled"]
    }

    private func normalizeStatus(_ status: String?) -> String {
        SessionActionGate.normalizeBucket(status)
    }

    private func matchDateRange(_ iso: String?) -> Bool {
        guard let iso = iso, let date = parseIsoDate(iso) else { return true }
        if let from = dateFrom, date < Calendar.current.startOfDay(for: from) { return false }
        if let to = dateTo {
            let end = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: to) ?? to
            if date > end { return false }
        }
        return true
    }

    private func parseIsoDate(_ iso: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) { return date }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: iso)
    }

    private func clearFilters() {
        selectedStatus = "all"
        dateFrom = nil
        dateTo = nil
    }

    private var dateRangeText: String {
        guard dateFrom != nil || dateTo != nil else {
            return NSLocalizedString("sessions_filter_date_any", comment: "")
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let fromText = dateFrom.map { formatter.string(from: $0) } ?? "—"
        let toText = dateTo.map { formatter.string(from: $0) } ?? "—"
        return "\(fromText) - \(toText)"
    }

    private var datePickerSheet: some View {
        NavigationView {
            Form {
                DatePicker("sessions_filter_date_from", selection: Binding(get: { dateFrom ?? Date() }, set: { dateFrom = $0 }), displayedComponents: [.date])
                DatePicker("sessions_filter_date_to", selection: Binding(get: { dateTo ?? Date() }, set: { dateTo = $0 }), displayedComponents: [.date])
            }
            .navigationTitle("sessions_filter_date_pick")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common_done") { showDateSheet = false }
                }
            }
        }
    }

    private func sessionCard(_ s: SessionItem) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(s.type ?? NSLocalizedString("common_session", comment: ""))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                Text(s.scheduled_at ?? NSLocalizedString("common_no_schedule", comment: ""))
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.placeholder)
                if let cost = s.points_cost {
                    Text(String(format: NSLocalizedString("sessions_points", comment: ""), cost))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
                if let spec = s.specialist?.name {
                    Text(String(format: NSLocalizedString("sessions_specialist", comment: ""), spec))
                        .font(.system(size: 13))
                        .foregroundColor(SanadTheme.placeholder)
                }
                if let status = s.status {
                    Text(status)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(SanadTheme.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sectionTitleKey(_ status: String) -> LocalizedStringKey {
        switch status {
        case "pending": return "sessions_section_pending"
        case "accepted": return "sessions_section_accepted"
        case "completed": return "sessions_section_completed"
        default: return "sessions_section_canceled"
        }
    }

    private func sectionEmptyKey(_ status: String) -> LocalizedStringKey {
        switch status {
        case "pending": return "sessions_empty_pending"
        case "accepted": return "sessions_empty_accepted"
        case "completed": return "sessions_empty_completed"
        default: return "sessions_empty_canceled"
        }
    }
}

#Preview { SessionsView().environmentObject(AuthViewModel()) }
