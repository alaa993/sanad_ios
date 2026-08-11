import SwiftUI
import Combine

private enum PatientShortcutRoute: Hashable {
    case community
    case vent
    case sessions
    case specialists
    case library
}

struct PatientDashboardView: View {
    @EnvironmentObject var authVM: AuthViewModel
    let mode: DashboardMode
    @State private var dashboard: DashboardResponse?
    @State private var error: String?
    @State private var loading = false
    @State private var showBook = false
    @State private var showPreSession = false
    @State private var showIntake = false
    @State private var bookWithSpecialistId: Int?
    @State private var bookSelectedSpecialist: DirectorySpecialist?
    @State private var selectedSessionId: Int?
    @State private var showSessionDetail = false
    @State private var showSessionJoin = false
    @State private var showNotifications = false
    @State private var showSessionsList = false
    @State private var showVent = false
    @State private var showChatList = false
    @State private var shortcutNavPath: [PatientShortcutRoute] = []
    @State private var legacyShortcutRoute: PatientShortcutRoute?
    @State private var realtimeCancellable: AnyCancellable?
    private let service = DashboardService()

    private var patientWelcomeTitle: String {
        let name = authVM.currentUser?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if name.isEmpty {
            return NSLocalizedString("patient_greeting", comment: "")
        }
        return String(format: NSLocalizedString("patient_welcome_name", comment: ""), name)
    }

    var body: some View {
        Group {
            if mode == .shortcutsOnly {
                shortcutsBody
            } else {
                NavigationView {
                    dashboardBody
                        .background(sessionPushNavigationLinks)
                }
                .environmentObject(authVM)
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
        .coachMarks(key: "tour_home", steps: [
            CoachMarkStep(id: "pd_new_session", title: "tour_home_primary_title", desc: "tour_home_primary_desc", targetId: "pd_new_session"),
            CoachMarkStep(id: "pd_join", title: "tour_home_join_title", desc: "tour_home_join_desc", targetId: "pd_join"),
            CoachMarkStep(id: "pd_intake", title: "tour_home_intake_title", desc: "tour_home_intake_desc", targetId: "pd_intake")
        ])
    }

    @ViewBuilder
    private var shortcutsBody: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                ShortcutsPage(
                    items: shortcutItems(),
                    primaryAction: { showBook = true },
                    primaryTitle: "cta_new_session"
                )
                .background(sessionPushNavigationLinks)
                .sheet(isPresented: $showBook) {
                    BookSessionView(onCompleted: { showBook = false })
                }
            }
        } else {
            NavigationView {
                ShortcutsPage(
                    items: shortcutItems(),
                    primaryAction: { showBook = true },
                    primaryTitle: "cta_new_session"
                )
                .background(sessionPushNavigationLinks)
                .sheet(isPresented: $showBook) {
                    BookSessionView(onCompleted: { showBook = false })
                }
            }
        }
    }

    private var sessionPushNavigationLinks: some View {
        Group {
            NavigationLink(
                destination: SessionDetailView(sessionId: selectedSessionId ?? 0).environmentObject(authVM),
                isActive: $showSessionDetail
            ) { EmptyView() }
            NavigationLink(
                destination: SessionDetailView(sessionId: selectedSessionId ?? 0).environmentObject(authVM),
                isActive: $showSessionJoin
            ) { EmptyView() }
        }
    }

    private var dashboardBody: some View {
        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("app_name")
                                .font(SanadFont.caption(13))
                                .foregroundColor(SanadTheme.primary)
                            Text(patientWelcomeTitle)
                                .font(SanadFont.title(24))
                                .foregroundColor(SanadTheme.onBg)
                            Text("patient_home_subtitle")
                                .font(SanadFont.body(14))
                                .foregroundColor(SanadTheme.placeholder)
                        }
                        Spacer()
                        Button {
                            showNotifications = true
                        } label: {
                            SanadIcon.notifications.image
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(SanadTheme.primary)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(SanadTheme.surface))
                                .overlay(Circle().stroke(SanadTheme.fieldStroke, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 12)

                    if let err = error {
                        SanadInlineBanner(err, style: .error)
                    }

                    nextSessionCard()
                        .coachMarkTarget("pd_next")

                    SanadButton(title: "cta_new_session", kind: .primary) {
                        showBook = true
                    }
                    .coachMarkTarget("pd_new_session")

                    quickCareRow

                    heroStatsCard()
                        .coachMarkTarget("pd_stats")

                    if shouldShowIntake {
                        intakeCard()
                            .coachMarkTarget("pd_intake")
                    }

                    if shouldShowOnboarding {
                        onboardingCard()
                    }

                    if shouldShowExternalPhysicianBanner {
                        externalPhysicianBanner()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(SanadAtmosphereBackground())
        .navigationBarHidden(true)
        .task { await load() }
        .refreshable { await load() }
        .onAppear { subscribeRealtime() }
        .onDisappear { realtimeCancellable?.cancel() }
        .onChange(of: showVent) { _, active in
            if !active { Task { await load() } }
        }
        .sheet(isPresented: $showBook) {
            BookSessionView(
                selectedSpecialist: bookSelectedSpecialist,
                onCompleted: {
                    showBook = false
                    bookSelectedSpecialist = nil
                    bookWithSpecialistId = nil
                }
            )
        }
        .sheet(isPresented: $showPreSession) {
            PreSessionSurveyView {
                Task { await load() }
            }
        }
        .sheet(isPresented: $showIntake, onDismiss: { Task { await load() } }) {
            NavigationView {
                PatientIntakeView(onCompleted: {
                    showIntake = false
                    Task { await load() }
                })
            }
        }
        .background(
            Group {
                NavigationLink(
                    destination: NotificationsView(),
                    isActive: $showNotifications
                ) { EmptyView() }
                NavigationLink(
                    destination: SessionsView().environmentObject(authVM),
                    isActive: $showSessionsList
                ) { EmptyView() }
                NavigationLink(
                    destination: VentView(),
                    isActive: $showVent
                ) { EmptyView() }
                NavigationLink(
                    destination: ChatListView().environmentObject(authVM),
                    isActive: $showChatList
                ) { EmptyView() }
            }
        )
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        do {
            let res = try await service.load(token: token)
            await MainActor.run {
                self.dashboard = res
                self.error = nil
            }
        } catch _ {
            await MainActor.run { self.error = NSLocalizedString("patient_dashboard_load_failed", comment: "") }
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

    @ViewBuilder
    private func heroStatsCard() -> some View {
        let stats = dashboard?.stats
        SanadListCard {
            HStack(spacing: 12) {
                Button {
                    showSessionsList = true
                } label: {
                    heroStat(icon: .sessions, title: "dashboard_next_sessions", value: "\(stats?.upcoming_sessions ?? 0)")
                }
                .buttonStyle(.plain)
                Divider().frame(height: 48)
                heroStat(icon: .unread, title: "dashboard_unread", value: "\(stats?.unread_messages ?? 0)")
                Divider().frame(height: 48)
                heroStat(icon: .star, title: "dashboard_points", value: "\(stats?.points ?? 0)")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func heroStat(icon: SanadIcon, title: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 6) {
            icon.view(size: 18)
                .foregroundColor(SanadTheme.primary)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(SanadTheme.placeholder)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)
        }
        .frame(maxWidth: .infinity)
    }

    private func statCard(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(SanadTheme.placeholder)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(SanadTheme.card))
        .shadow(color: SanadTheme.subtleShadow, radius: 4, y: 3)
    }

    @ViewBuilder
    private func nextSessionCard() -> some View {
        let next = dashboard?.next_session
        SanadListCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("next_session_title")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SanadTheme.placeholder)

                if let next = next {
                    Button {
                        selectedSessionId = next.id
                        showSessionDetail = true
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(next.specialist_name ?? next.organization_name ?? NSLocalizedString("session_fallback_title", comment: ""))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(SanadTheme.onBg)
                            Text(labelForType(next.type))
                                .font(.system(size: 13))
                                .foregroundColor(SanadTheme.placeholder)
                            Text(formatSchedule(next.scheduled_at))
                                .font(.system(size: 13))
                                .foregroundColor(SanadTheme.placeholder)
                        }
                    }
                    .buttonStyle(.plain)

                    if (next.can_join ?? false) {
                        Button("cta_join_now") {
                            selectedSessionId = next.id
                            showSessionJoin = true
                        }
                        .coachMarkTarget("pd_join")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .stroke(SanadTheme.primary, lineWidth: 1)
                        )
                        .foregroundColor(SanadTheme.primary)
                    }
                } else {
                    SanadEmptyState(message: "no_next_session")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func intakeCard() -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("home_intake_title")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SanadTheme.placeholder)

                let intake = dashboard?.intake
                let statusKey = (intake?.completed ?? false) ? "intake_status_complete" : "intake_status_incomplete"
                let status = NSLocalizedString(statusKey, comment: "")
                Text(String(format: NSLocalizedString("home_intake_updated", comment: ""), status))
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.onBg)

                Text(String(format: NSLocalizedString("home_intake_severity", comment: ""), localizedSeverity(intake?.severity_level)))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
                Text(String(format: NSLocalizedString("home_intake_impact", comment: ""), localizedImpact(intake?.impact_level)))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
                Text(String(format: NSLocalizedString("home_intake_preferred", comment: ""), localizedPreferred(intake?.preferred_session_mode)))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)

                let risks = intake?.risk_flags?.joined(separator: "، ") ?? NSLocalizedString("patient_dashboard_no_risk_flags", comment: "")
                Text(String(format: NSLocalizedString("home_intake_risk", comment: ""), risks))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)

                if let specialist = intake?.recommended_specialist?.name {
                    Text(String(format: NSLocalizedString("home_intake_specialist", comment: ""), specialist))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }

                if intake?.referral_physician_recommended == true {
                    Text("physician_referral_banner")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(SanadTheme.primary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(SanadTheme.primary.opacity(0.12)))
                }

                NavigationLink(destination: PatientIntakeView()) {
                    Text("home_intake_open")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                        .foregroundColor(SanadTheme.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func shortcutItems() -> [ShortcutAction] {
        patientShortcutItems()
    }

    private var quickCareRow: some View {
        HStack(spacing: 10) {
            quickChip(title: "chat_list_title", icon: .chat) {
                showChatList = true
            }
            quickChip(title: "nav_vent", icon: .vent) {
                showVent = true
            }
            quickChip(title: "nav_library", icon: .library) {
                pushShortcut(.library)
            }
        }
    }

    private func quickChip(title: LocalizedStringKey, icon: SanadIcon, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                icon.view(size: 18)
                Text(title)
                    .font(SanadFont.caption(11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(SanadTheme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SanadTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SanadTheme.fieldStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func patientShortcutItems() -> [ShortcutAction] {
        return [
            ShortcutAction(
                id: "sessions",
                title: NSLocalizedString("nav_sessions", comment: ""),
                icon: "calendar",
                actionTitle: actionTitleForShortcut("sessions"),
                destination: AnyView(shortcutDestination(for: .sessions)),
                subtitleKey: "care_hub_sessions_subtitle"
            ),
            ShortcutAction(
                id: "chat",
                title: NSLocalizedString("chat_list_title", comment: ""),
                icon: "bubble.left.and.bubble.right",
                actionTitle: actionTitleForShortcut("chat"),
                destination: AnyView(NestedNavigationHost { ChatListView().environmentObject(authVM) }),
                subtitleKey: "care_hub_chat_subtitle"
            ),
            ShortcutAction(
                id: "vent",
                title: NSLocalizedString("nav_vent", comment: ""),
                icon: "wind",
                actionTitle: actionTitleForShortcut("vent"),
                destination: AnyView(shortcutDestination(for: .vent)),
                subtitleKey: "care_hub_vent_subtitle"
            ),
            ShortcutAction(
                id: "community",
                title: NSLocalizedString("shortcut_community", comment: ""),
                icon: "person.3",
                actionTitle: actionTitleForShortcut("community"),
                destination: AnyView(shortcutDestination(for: .community)),
                subtitleKey: "care_hub_community_subtitle"
            ),
            ShortcutAction(
                id: "specialists",
                title: NSLocalizedString("nav_specialists", comment: ""),
                icon: "stethoscope",
                actionTitle: actionTitleForShortcut("specialists"),
                destination: AnyView(shortcutDestination(for: .specialists)),
                subtitleKey: "care_hub_specialists_subtitle"
            ),
            ShortcutAction(
                id: "library",
                title: NSLocalizedString("nav_library", comment: ""),
                icon: "books.vertical",
                actionTitle: actionTitleForShortcut("library"),
                destination: AnyView(shortcutDestination(for: .library)),
                subtitleKey: "care_hub_library_subtitle"
            )
        ]
    }

    @ViewBuilder
    private func shortcutDestination(for route: PatientShortcutRoute) -> some View {
        switch route {
        case .community:
            NestedNavigationHost { CommunityListView().environmentObject(authVM) }
        case .vent:
            NestedNavigationHost { VentView() }
        case .sessions:
            NestedNavigationHost { SessionsView().environmentObject(authVM) }
        case .specialists:
            NestedNavigationHost { PatientSpecialistsView().environmentObject(authVM) }
        case .library:
            NestedNavigationHost { LibraryView().environmentObject(authVM) }
        }
    }

    private func pushShortcut(_ route: PatientShortcutRoute) {
        if #available(iOS 16.0, *) {
            shortcutNavPath.append(route)
        } else {
            legacyShortcutRoute = route
        }
    }

    @ViewBuilder
    private func legacyShortcutLinks() -> some View {
        Group {
            NavigationLink(destination: shortcutDestination(for: .community), tag: PatientShortcutRoute.community, selection: $legacyShortcutRoute) { EmptyView() }
            NavigationLink(destination: shortcutDestination(for: .vent), tag: PatientShortcutRoute.vent, selection: $legacyShortcutRoute) { EmptyView() }
            NavigationLink(destination: shortcutDestination(for: .sessions), tag: PatientShortcutRoute.sessions, selection: $legacyShortcutRoute) { EmptyView() }
            NavigationLink(destination: shortcutDestination(for: .specialists), tag: PatientShortcutRoute.specialists, selection: $legacyShortcutRoute) { EmptyView() }
            NavigationLink(destination: shortcutDestination(for: .library), tag: PatientShortcutRoute.library, selection: $legacyShortcutRoute) { EmptyView() }
        }
        .hidden()
    }

    private func actionTitleForShortcut(_ key: String) -> String {
        if key.contains("session") || key.contains("book") {
            return NSLocalizedString("shortcuts_action_book", comment: "")
        }
        return NSLocalizedString("shortcuts_action_explore", comment: "")
    }

    private var shouldShowIntake: Bool {
        let completed = dashboard?.intake?.completed ?? false
        if completed { return false }
        if dashboard?.onboarding?.needs_intake == true { return false }
        return true
    }

    private var shouldShowOnboarding: Bool {
        guard let onboarding = dashboard?.onboarding else { return false }
        return onboarding.needs_intake == true || onboarding.needs_pre_session == true || onboarding.needs_vent == true
    }

    private var shouldShowExternalPhysicianBanner: Bool {
        dashboard?.intake?.external_physician_recommended == true
    }

    @ViewBuilder
    private func onboardingCard() -> some View {
        let onboarding = dashboard?.onboarding
        SanadListCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("onboarding_steps_title")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SanadTheme.placeholder)

                if onboarding?.needs_intake == true {
                    onboardingStepRow(
                        title: "onboarding_step_intake",
                        actionTitle: "home_intake_open",
                        action: { showIntake = true }
                    )
                }
                if onboarding?.needs_pre_session == true {
                    onboardingStepRow(
                        title: "onboarding_step_pre_session",
                        actionTitle: "pre_session_survey_open",
                        action: { showPreSession = true }
                    )
                }
                if onboarding?.needs_vent == true {
                    onboardingStepRow(
                        title: "onboarding_step_vent",
                        actionTitle: "onboarding_step_vent_action",
                        action: { showVent = true }
                    )
                }
                if onboarding?.journal_unlocked == true {
                    Text("onboarding_journal_unlocked")
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func onboardingStepRow(title: LocalizedStringKey, actionTitle: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(SanadTheme.onBg)
            Spacer()
            Button(actionTitle, action: action)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(SanadTheme.primary)
        }
    }

    @ViewBuilder
    private func externalPhysicianBanner() -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("external_physician_banner")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SanadTheme.primary)
                Text("external_physician_banner_desc")
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
                Button("external_physician_find_specialist") {
                    pushShortcut(.specialists)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SanadTheme.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func handlePushRoute(_ route: PushDeepLink) {
        switch route {
        case .sessionDetail(let id):
            selectedSessionId = id
            showSessionDetail = true
        case .bookSpecialist(let specialistId):
            bookWithSpecialistId = specialistId
            Task { await prepareBookSheet(specialistId: specialistId) }
        case .specialists:
            pushShortcut(.specialists)
        }
    }

    private func prepareBookSheet(specialistId: Int?) async {
        if let specialistId, let token = KeychainHelper.getToken() {
            bookSelectedSpecialist = try? await DirectoryService().specialistDetail(id: specialistId, token: token)
        } else {
            bookSelectedSpecialist = nil
        }
        showBook = true
    }

    private func formatSchedule(_ iso: String?) -> String {
        guard let iso = iso, let date = parseIsoDate(iso) else {
            return NSLocalizedString("patient_dashboard_no_schedule", comment: "")
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

    private func labelForType(_ type: String?) -> String {
        guard let type = type, !type.isEmpty else {
            return NSLocalizedString("session_fallback_title", comment: "")
        }
        return type
    }

    private func localizedSeverity(_ value: String?) -> String {
        guard let value = value, !value.isEmpty else {
            return NSLocalizedString("common_unavailable", comment: "")
        }
        switch value.lowercased() {
        case "mild": return NSLocalizedString("intake_severity_mild", comment: "")
        case "moderate": return NSLocalizedString("intake_severity_moderate", comment: "")
        case "severe": return NSLocalizedString("intake_severity_severe", comment: "")
        default: return value
        }
    }

    private func localizedImpact(_ value: String?) -> String {
        guard let value = value, !value.isEmpty else {
            return NSLocalizedString("common_unavailable", comment: "")
        }
        switch value.lowercased() {
        case "low": return NSLocalizedString("intake_impact_low", comment: "")
        case "medium": return NSLocalizedString("intake_impact_medium", comment: "")
        case "high": return NSLocalizedString("intake_impact_high", comment: "")
        default: return value
        }
    }

    private func localizedPreferred(_ value: String?) -> String {
        guard let value = value, !value.isEmpty else {
            return NSLocalizedString("common_unavailable", comment: "")
        }
        switch value.lowercased() {
        case "voice": return NSLocalizedString("intake_mode_voice", comment: "")
        case "video": return NSLocalizedString("intake_mode_video", comment: "")
        case "text", "chat": return NSLocalizedString("intake_mode_text", comment: "")
        default: return value
        }
    }
}

#Preview {
    PatientDashboardView(mode: .dashboard)
}
