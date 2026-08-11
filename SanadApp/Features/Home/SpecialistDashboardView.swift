import SwiftUI
import Combine

private enum SpecialistRoute: Hashable {
    case sessions
    case patients
    case community
    case library
    case chat
    case about
    case contact
}

struct SpecialistDashboardView: View {
    @EnvironmentObject var authVM: AuthViewModel
    let mode: DashboardMode
    @State private var dashboard: SpecialistDashboard?
    @State private var sessions: [SpecialistAppointment] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var rescheduleTarget: SpecialistAppointment?
    @State private var rescheduleDate = Date()
    @State private var navPath: [SpecialistRoute] = []
    @State private var legacyRoute: SpecialistRoute?
    @State private var realtimeCancellable: AnyCancellable?
    @State private var selectedSessionId: Int?
    @State private var selectedPatientId: Int = -1
    @State private var showSessionDetail = false

    private let service = SpecialistService()
    private let extendMinutesDefault = 15

    var body: some View {
        Group {
            if mode == .shortcutsOnly {
                shortcutsBody
            } else {
                dashboardNavigationBody
            }
        }
        .onChange(of: authVM.pendingPushRoute) { _, route in
            guard let route else { return }
            handlePushRoute(route)
            authVM.pendingPushRoute = nil
        }
        .onAppear {
            if let route = authVM.pendingPushRoute {
                handlePushRoute(route)
                authVM.pendingPushRoute = nil
            }
        }
        .coachMarks(key: "tour_specialist_home", steps: [
            CoachMarkStep(id: "spec_today", title: "tour_spec_today_title", desc: "tour_spec_today_desc", targetId: "spec_today"),
            CoachMarkStep(id: "spec_upcoming", title: "tour_spec_upcoming_title", desc: "tour_spec_upcoming_desc", targetId: "spec_upcoming"),
            CoachMarkStep(id: "spec_pending", title: "tour_spec_pending_title", desc: "tour_spec_pending_desc", targetId: "spec_pending"),
            CoachMarkStep(id: "spec_list", title: "tour_spec_list_title", desc: "tour_spec_list_desc", targetId: "spec_list")
        ])
    }

    @ViewBuilder
    private var shortcutsBody: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                ShortcutsPage(
                    items: shortcutItems(),
                    showsSafePlace: false,
                    primaryDestination: AnyView(NestedNavigationHost { SpecialistSessionsView().environmentObject(authVM) }),
                    primaryTitle: "nav_sessions"
                )
                    .background(sessionPushNavigationLink)
            }
        } else {
            NavigationView {
                ShortcutsPage(
                    items: shortcutItems(),
                    showsSafePlace: false,
                    primaryDestination: AnyView(SpecialistSessionsView().environmentObject(authVM)),
                    primaryTitle: "nav_sessions"
                )
                    .background(sessionPushNavigationLink)
            }
        }
    }

    @ViewBuilder
    private var dashboardNavigationBody: some View {
        if #available(iOS 16.0, *) {
            NavigationStack(path: $navPath) {
                dashboardScrollContent
                    .background(sessionPushNavigationLink)
                    .navigationDestination(for: SpecialistRoute.self) { route in
                        destination(for: route)
                    }
            }
        } else {
            NavigationView {
                ZStack {
                    dashboardScrollContent
                    legacyNavigationLinks()
                    sessionPushNavigationLink
                }
            }
        }
    }

    private var sessionPushNavigationLink: some View {
        NavigationLink(
            destination: SpecialistSessionDetailView(
                sessionId: selectedSessionId ?? 0,
                patientId: selectedPatientId
            ),
            isActive: $showSessionDetail
        ) { EmptyView() }
    }

    private func handlePushRoute(_ route: PushDeepLink) {
        switch route {
        case .sessionDetail(let id):
            selectedSessionId = id
            if let match = sessions.first(where: { $0.id == id }) {
                selectedPatientId = match.patient_id ?? match.patient?.id ?? -1
            } else {
                selectedPatientId = -1
            }
            showSessionDetail = true
        case .bookSpecialist, .specialists:
            break
        }
    }

    private var dashboardScrollContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "specialist_home_title", subtitle: "specialist_home_subtitle")

                VStack(alignment: .leading, spacing: 16) {
                    if let err = error {
                        SanadInlineBanner(err, style: .error)
                    }

                    heroStatsCard()

                    Text("specialist_upcoming_header")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(SanadTheme.onBg)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    SanadListCard {
                        VStack(alignment: .leading, spacing: 10) {
                            if sessions.isEmpty && !loading {
                                SanadEmptyState(message: "specialist_dashboard_no_upcoming")
                            } else {
                                ForEach(sessions.prefix(3)) { session in
                                    sessionCard(session)
                                }
                            }
                        }
                        .coachMarkTarget("spec_list")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
        .background(SanadAtmosphereBackground())
        .navigationBarHidden(true)
        .task { await load() }
        .refreshable { await load() }
        .onAppear { subscribeRealtime() }
        .onDisappear { realtimeCancellable?.cancel() }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("common_ok", role: .cancel) {}
        }
        .sheet(item: $rescheduleTarget) { target in
            rescheduleSheet(target)
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

    @ViewBuilder
    private func destination(for route: SpecialistRoute) -> some View {
        NestedNavigationHost {
            switch route {
            case .community:
                CommunityListView().environmentObject(authVM)
            default:
                specialistScreen(for: route)
            }
        }
    }

    @ViewBuilder
    private func specialistScreen(for route: SpecialistRoute) -> some View {
        switch route {
        case .sessions:
            SpecialistSessionsView().environmentObject(authVM)
        case .patients:
            SpecialistPatientsView()
        case .community:
            EmptyView()
        case .library:
            LibraryView().environmentObject(authVM)
        case .chat:
            ChatListView().environmentObject(authVM)
        case .about:
            StaticPageView(type: .about)
        case .contact:
            StaticPageView(type: .contact)
        }
    }

    @ViewBuilder
    private func legacyNavigationLinks() -> some View {
        Group {
            NavigationLink(
                destination: destination(for: .sessions),
                tag: SpecialistRoute.sessions,
                selection: $legacyRoute
            ) { EmptyView() }
            NavigationLink(
                destination: destination(for: .patients),
                tag: SpecialistRoute.patients,
                selection: $legacyRoute
            ) { EmptyView() }
            NavigationLink(
                destination: destination(for: .community),
                tag: SpecialistRoute.community,
                selection: $legacyRoute
            ) { EmptyView() }
            NavigationLink(
                destination: destination(for: .library),
                tag: SpecialistRoute.library,
                selection: $legacyRoute
            ) { EmptyView() }
            NavigationLink(
                destination: destination(for: .chat),
                tag: SpecialistRoute.chat,
                selection: $legacyRoute
            ) { EmptyView() }
            NavigationLink(
                destination: destination(for: .about),
                tag: SpecialistRoute.about,
                selection: $legacyRoute
            ) { EmptyView() }
            NavigationLink(
                destination: destination(for: .contact),
                tag: SpecialistRoute.contact,
                selection: $legacyRoute
            ) { EmptyView() }
        }
        .hidden()
    }

    private func push(_ route: SpecialistRoute) {
        if #available(iOS 16.0, *) {
            navPath.append(route)
        } else {
            legacyRoute = route
        }
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        do {
            async let dash = service.dashboard(token: token)
            async let list = service.sessions(scope: "upcoming", token: token)
            let (dashRes, listRes) = try await (dash, list)
            await MainActor.run {
                self.dashboard = dashRes
                self.sessions = listRes
                self.error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("specialist_dashboard_load_failed", comment: "") }
        }
        loading = false
    }

    private func heroStatsCard() -> some View {
        SanadListCard {
            HStack(spacing: 12) {
                heroStat(icon: "calendar", title: "specialist_stat_today", value: "\(dashboard?.counters?.today ?? 0)")
                    .coachMarkTarget("spec_today")
                Divider().frame(height: 48)
                heroStat(icon: "calendar.badge.clock", title: "specialist_stat_upcoming", value: "\(dashboard?.counters?.upcoming ?? 0)")
                    .coachMarkTarget("spec_upcoming")
                Divider().frame(height: 48)
                heroStat(icon: "hourglass", title: "specialist_stat_pending", value: "\(dashboard?.counters?.pending ?? 0)")
                    .coachMarkTarget("spec_pending")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func heroStat(icon: String, title: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 6) {
            SanadIcon.forShortcut(id: icon).image
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(SanadTheme.primary)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(SanadTheme.placeholder)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(SanadTheme.onBg)
        }
        .frame(maxWidth: .infinity)
    }

    private func shortcutItems() -> [ShortcutAction] {
        return [
            ShortcutAction(
                id: "sessions",
                title: NSLocalizedString("specialist_dashboard_my_sessions", comment: ""),
                icon: "calendar",
                actionTitle: NSLocalizedString("shortcuts_action_explore", comment: ""),
                destination: AnyView(destination(for: .sessions))
            ),
            ShortcutAction(
                id: "patients",
                title: NSLocalizedString("nav_patients", comment: ""),
                icon: "person.2.fill",
                actionTitle: NSLocalizedString("shortcuts_action_explore", comment: ""),
                destination: AnyView(destination(for: .patients))
            ),
            ShortcutAction(
                id: "community",
                title: NSLocalizedString("shortcut_community", comment: ""),
                icon: "person.3.fill",
                actionTitle: NSLocalizedString("shortcuts_action_explore", comment: ""),
                destination: AnyView(destination(for: .community))
            ),
            ShortcutAction(
                id: "library",
                title: NSLocalizedString("nav_library", comment: ""),
                icon: "books.vertical.fill",
                actionTitle: NSLocalizedString("shortcuts_action_explore", comment: ""),
                destination: AnyView(destination(for: .library))
            )
        ]
    }

    @ViewBuilder
    private func sessionCard(_ session: SpecialistAppointment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.patient_name ?? session.patient?.name ?? NSLocalizedString("role_patient", comment: ""))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)
            Text(formatSchedule(session.scheduled_at))
                .font(.system(size: 12))
                .foregroundColor(SanadTheme.placeholder)
            if let status = session.status {
                Text(status)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SanadTheme.primary)
            }

            HStack(spacing: 8) {
                if isPending(session) {
                    Button("specialist_dashboard_accept") { Task { await performAction { try await service.accept(id: session.id, token: token()) } } }
                    Button("specialist_dashboard_reject") { Task { await performAction { try await service.reject(id: session.id, token: token()) } } }
                }
                Button("specialist_dashboard_reschedule") { rescheduleTarget = session }
                if isActive(session) {
                    Button("chat_extend") { Task { await performAction { try await service.extend(id: session.id, minutes: extendMinutesDefault, token: token()) } } }
                    Button("specialist_dashboard_complete") { Task { await performAction { try await service.complete(id: session.id, token: token()) } } }
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(SanadTheme.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(SanadTheme.surface))
    }

    private func rescheduleSheet(_ session: SpecialistAppointment) -> some View {
        NavigationView {
            VStack(spacing: 20) {
                DatePicker("specialist_dashboard_reschedule_pick", selection: $rescheduleDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)

                Button("specialist_dashboard_reschedule_save") {
                    Task {
                        await performAction {
                            try await service.reschedule(id: session.id, startsAt: rescheduleDate, token: token())
                        }
                        rescheduleTarget = nil
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Capsule().fill(SanadTheme.primary))
                .foregroundColor(SanadTheme.onPrimary)

                Spacer()
            }
            .padding(20)
            .navigationTitle("specialist_dashboard_reschedule_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common_close") { rescheduleTarget = nil }
                }
            }
        }
    }

    private func isPending(_ session: SpecialistAppointment) -> Bool {
        (session.status ?? "").lowercased() == "pending"
    }

    private func isActive(_ session: SpecialistAppointment) -> Bool {
        let status = (session.status ?? "").lowercased()
        return ["accepted", "confirmed", "in_progress", "started", "scheduled", "upcoming"].contains(status)
    }

    private func showComingSoon(_ message: String) {
        alertMessage = message
        showAlert = true
    }

    private func token() -> String {
        KeychainHelper.getToken() ?? ""
    }

    private func performAction(_ action: @escaping () async throws -> Void) async {
        guard !token().isEmpty else {
            showComingSoon(NSLocalizedString("error_not_logged_in", comment: ""))
            return
        }
        do {
            try await action()
            await load()
        } catch {
            showComingSoon(NSLocalizedString("specialist_dashboard_action_failed", comment: ""))
        }
    }

    private func formatSchedule(_ iso: String?) -> String {
        guard let iso = iso, let date = parseIsoDate(iso) else {
            return NSLocalizedString("common_no_schedule", comment: "")
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd - hh:mm a"
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
}

#Preview { SpecialistDashboardView(mode: .dashboard) }
