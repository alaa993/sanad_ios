import SwiftUI

struct OrgDashboardView: View {
    let mode: DashboardMode
    @EnvironmentObject var authVM: AuthViewModel
    @State private var dashboard: OrgDashboard?
    @State private var loading = false
    @State private var error: String?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var legacyRoute: OrgRoute?
    @State private var navPath: [OrgRoute] = []

    private let service = OrgDashboardService()
    private let orgApi = OrgService()

    var body: some View {
        Group {
            if mode == .shortcutsOnly {
                shortcutsBody
            } else {
                dashboardNavigationBody
            }
        }
        .task { await load() }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("common_ok", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var shortcutsBody: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                ShortcutsPage(items: shortcutItems())
            }
        } else {
            NavigationView {
                ShortcutsPage(items: shortcutItems())
            }
        }
    }

    @ViewBuilder
    private var dashboardNavigationBody: some View {
        if #available(iOS 16.0, *) {
            NavigationStack(path: $navPath) {
                dashboardScrollContent
                    .navigationDestination(for: OrgRoute.self) { route in
                        orgDestination(for: route)
                    }
            }
        } else {
            NavigationView {
                ZStack {
                    dashboardScrollContent
                    legacyNavigationLinks()
                }
            }
        }
    }

    @ViewBuilder
    private func orgDestination(for route: OrgRoute) -> some View {
        NestedNavigationHost {
            orgScreen(for: route)
        }
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
        } catch {
            await MainActor.run { self.error = NSLocalizedString("org_dashboard_load_failed", comment: "") }
        }
        loading = false
    }

    private var dashboardScrollContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "app_name", subtitle: "org_dashboard_subtitle")

                VStack(alignment: .leading, spacing: 16) {
                    if let err = error {
                        Text(err)
                            .foregroundColor(SanadTheme.error)
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    countersGrid()

                    orgQuickActionsRow()

                    Text("dashboard_alerts")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(SanadTheme.onBg)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    alertsCard()
                        .coachMarkTarget("org_alerts")

                    DashboardToolsCard(
                        onGuide: { push(.library) },
                        onAccessibility: { push(.about) },
                        onSupport: { push(.contact) }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .refreshable { await load() }
        .background(SanadAtmosphereBackground())
        .navigationBarHidden(true)
        .coachMarks(key: "tour_org_home", steps: [
            CoachMarkStep(id: "org_beneficiaries", title: "tour_org_beneficiaries_title", desc: "tour_org_beneficiaries_desc", targetId: "org_beneficiaries"),
            CoachMarkStep(id: "org_sessions", title: "tour_org_sessions_title", desc: "tour_org_sessions_desc", targetId: "org_sessions")
        ])
    }

    @ViewBuilder
    private func orgQuickActionsRow() -> some View {
        let actions = dashboard?.quick_actions ?? defaultQuickActions()
        if actions.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("dashboard_quick_actions")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(actions, id: \.id) { action in
                        Button(action.label ?? action.id) {
                            handleQuickAction(action.id)
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(SanadTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(SanadTheme.primary.opacity(0.1)))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func countersGrid() -> some View {
        let counters = dashboard?.counters
        let beneficiaries = counters?.beneficiaries ?? counters?.pending ?? 0
        let sessions = counters?.sessions_total ?? counters?.upcoming ?? 0
        let upcoming = counters?.upcoming_48h ?? counters?.upcoming ?? 0
        let specialists = counters?.specialists_active ?? 0
        let riskCases = counters?.high_risk_cases ?? 0

        VStack(spacing: 10) {
            HStack(spacing: 12) {
                counterCard(title: "org_dashboard_beneficiaries", value: "\(beneficiaries)")
                    .coachMarkTarget("org_beneficiaries")
                counterCard(title: "org_dashboard_sessions", value: "\(sessions)")
                    .coachMarkTarget("org_sessions")
            }
            HStack(spacing: 12) {
                counterCard(title: "org_dashboard_upcoming_48h", value: "\(upcoming)")
                counterCard(title: "org_dashboard_active_specialists", value: "\(specialists)")
            }
            counterCard(title: "org_dashboard_high_risk", value: "\(riskCases)")
        }
    }

    private func counterCard(title: LocalizedStringKey, value: String) -> some View {
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
    private func alertsCard() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("dashboard_alerts")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(SanadTheme.placeholder)

            let alerts = dashboard?.alerts ?? []
            if alerts.isEmpty {
                Text("dashboard_alerts_empty")
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
            } else {
                ForEach(alerts) { alert in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert.title ?? NSLocalizedString("dashboard_alert_default", comment: ""))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SanadTheme.onBg)
                        Text(alert.message ?? "")
                            .font(.system(size: 12))
                            .foregroundColor(SanadTheme.placeholder)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(SanadTheme.surface))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(SanadTheme.card))
        .shadow(color: SanadTheme.subtleShadow, radius: 6, y: 4)
    }

    private func defaultQuickActions() -> [OrgDashboard.QuickAction] {
        [
            OrgDashboard.QuickAction(id: "beneficiaries", label: NSLocalizedString("org_dashboard_action_manage_beneficiaries", comment: "")),
            OrgDashboard.QuickAction(id: "group_session", label: NSLocalizedString("org_dashboard_action_group_session", comment: "")),
            OrgDashboard.QuickAction(id: "reports", label: NSLocalizedString("org_dashboard_action_reports", comment: "")),
            OrgDashboard.QuickAction(id: "community_room", label: NSLocalizedString("org_dashboard_action_support_room", comment: ""))
        ]
    }

    private func shortcutItems() -> [ShortcutAction] {
        return defaultQuickActions().map { action in
            let route = orgRoute(for: action.id)
            return ShortcutAction(
                id: action.id,
                title: shortcutTitle(for: action.id, fallback: action.label),
                icon: shortcutIcon(for: action.id),
                actionTitle: shortcutActionTitle(for: action.id),
                destination: route.map { route in AnyView(orgDestination(for: route)) },
                onTap: route == nil ? { handleQuickAction(action.id) } : nil
            )
        }
    }

    private func orgRoute(for id: String) -> OrgRoute? {
        switch id {
        case "add_beneficiary": return .beneficiaries(openCreate: true)
        case "beneficiaries", "beneficiaries_list": return .beneficiaries(openCreate: false)
        case "specialists": return .specialists
        case "group_session": return .sessions
        case "reports": return .reports
        case "billing": return .billing
        default: return nil
        }
    }

    private func shortcutTitle(for id: String, fallback: String?) -> String {
        switch id {
        case "add_beneficiary":
            return NSLocalizedString("org_dashboard_action_add_beneficiary", comment: "")
        case "beneficiaries", "beneficiaries_list":
            return NSLocalizedString("org_dashboard_action_manage_beneficiaries", comment: "")
        case "specialists":
            return NSLocalizedString("org_specialists_title", comment: "")
        case "group_session":
            return NSLocalizedString("org_dashboard_action_group_session", comment: "")
        case "reports":
            return NSLocalizedString("org_dashboard_action_reports", comment: "")
        case "billing":
            return NSLocalizedString("org_dashboard_action_billing", comment: "")
        case "community_room":
            return NSLocalizedString("org_dashboard_action_support_room", comment: "")
        default:
            return fallback ?? NSLocalizedString("dashboard_action_default", comment: "")
        }
    }

    private func shortcutIcon(for id: String) -> String {
        switch id {
        case "add_beneficiary":
            return "person.crop.circle.badge.plus"
        case "beneficiaries", "beneficiaries_list":
            return "person.3"
        case "specialists":
            return "person.2.fill"
        case "group_session":
            return "calendar.badge.plus"
        case "reports":
            return "chart.bar"
        case "billing":
            return "creditcard"
        case "community_room":
            return "bubble.left.and.bubble.right"
        default:
            return "square.grid.2x2"
        }
    }

    private func shortcutActionTitle(for id: String) -> String {
        switch id {
        case "group_session", "sessions":
            return NSLocalizedString("shortcuts_action_book", comment: "")
        default:
            return NSLocalizedString("shortcuts_action_explore", comment: "")
        }
    }

    private func handleQuickAction(_ id: String) {
        switch id {
        case "add_beneficiary":
            push(.beneficiaries(openCreate: true))
        case "beneficiaries":
            push(.beneficiaries(openCreate: false))
        case "specialists":
            push(.specialists)
        case "group_session":
            push(.sessions)
        case "beneficiaries_list":
            push(.beneficiaries(openCreate: false))
        case "reports":
            push(.reports)
        case "billing":
            push(.billing)
        case "community_room":
            Task { await openSupportRoom() }
        default:
            showInfo(id)
        }
    }

    private func openSupportRoom() async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            let room = try await orgApi.supportRoom(token: token)
            let title = room.name ?? room.slug ?? NSLocalizedString("org_dashboard_action_support_room", comment: "")
            await MainActor.run { push(.supportRoom(id: room.community_id, title: title)) }
        } catch {
            await MainActor.run {
                showInfo(NSLocalizedString("org_dashboard_support_room_error", comment: ""))
            }
        }
    }

    private func showInfo(_ message: String) {
        alertMessage = message
        showAlert = true
    }

    private func push(_ route: OrgRoute) {
        if #available(iOS 16.0, *) {
            navPath.append(route)
        } else {
            legacyRoute = route
        }
    }

    @ViewBuilder
    private func orgScreen(for route: OrgRoute) -> some View {
        switch route {
        case .beneficiaries(let openCreate):
            OrgBeneficiariesView(openCreateOnAppear: openCreate)
        case .specialists:
            OrgSpecialistsView()
        case .sessions:
            OrgSessionsView()
        case .reports:
            OrgReportsView()
        case .billing:
            OrgBillingView()
        case .supportRoom(let id, let title):
            CommunityFeedView(communityId: id, communityTitle: title)
                .environmentObject(authVM)
        case .library:
            LibraryView().environmentObject(authVM)
        case .about:
            StaticPageView(type: .about)
        case .contact:
            StaticPageView(type: .contact)
        }
    }

    @ViewBuilder
    private func legacyNavigationLinks() -> some View {
        NavigationLink(destination: orgDestination(for: .beneficiaries(openCreate: false)), tag: OrgRoute.beneficiaries(openCreate: false), selection: $legacyRoute) { EmptyView() }
        NavigationLink(destination: orgDestination(for: .beneficiaries(openCreate: true)), tag: OrgRoute.beneficiaries(openCreate: true), selection: $legacyRoute) { EmptyView() }
        NavigationLink(destination: orgDestination(for: .specialists), tag: OrgRoute.specialists, selection: $legacyRoute) { EmptyView() }
        NavigationLink(destination: orgDestination(for: .sessions), tag: OrgRoute.sessions, selection: $legacyRoute) { EmptyView() }
        NavigationLink(destination: orgDestination(for: .reports), tag: OrgRoute.reports, selection: $legacyRoute) { EmptyView() }
        NavigationLink(destination: orgDestination(for: .billing), tag: OrgRoute.billing, selection: $legacyRoute) { EmptyView() }
        NavigationLink(destination: orgDestination(for: .library), tag: OrgRoute.library, selection: $legacyRoute) { EmptyView() }
        NavigationLink(destination: orgDestination(for: .about), tag: OrgRoute.about, selection: $legacyRoute) { EmptyView() }
        NavigationLink(destination: orgDestination(for: .contact), tag: OrgRoute.contact, selection: $legacyRoute) { EmptyView() }
        NavigationLink(destination: legacySupportRoomDestination, isActive: legacySupportRoomActive) { EmptyView() }
    }

    private var legacySupportRoomActive: Binding<Bool> {
        Binding(
            get: {
                if case .supportRoom = legacyRoute { return true }
                return false
            },
            set: { if !$0 { legacyRoute = nil } }
        )
    }

    @ViewBuilder
    private var legacySupportRoomDestination: some View {
        if case .supportRoom(let id, let title) = legacyRoute {
            orgDestination(for: .supportRoom(id: id, title: title))
        } else {
            EmptyView()
        }
    }
}

#Preview { OrgDashboardView(mode: .dashboard).environmentObject(AuthViewModel()) }

private enum OrgRoute: Hashable, Identifiable {
    case beneficiaries(openCreate: Bool)
    case specialists
    case sessions
    case reports
    case billing
    case supportRoom(id: Int, title: String)
    case library
    case about
    case contact

    var id: String {
        switch self {
        case .beneficiaries(let openCreate): return "beneficiaries-\(openCreate)"
        case .specialists: return "specialists"
        case .sessions: return "sessions"
        case .reports: return "reports"
        case .billing: return "billing"
        case .supportRoom(let id, _): return "support-\(id)"
        case .library: return "library"
        case .about: return "about"
        case .contact: return "contact"
        }
    }
}
