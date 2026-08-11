import SwiftUI

struct AdminDashboardView: View {
    let mode: DashboardMode
    @EnvironmentObject var authVM: AuthViewModel
    @State private var dashboard: AdminDashboard?
    @State private var loading = false
    @State private var error: String?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var legacyRoute: AdminRoute?
    @State private var navPath: [AdminRoute] = []

    private let service = AdminDashboardService()

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
                    .navigationDestination(for: AdminRoute.self) { route in
                        adminDestination(for: route)
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

    private var dashboardScrollContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "admin_home_title", subtitle: "admin_home_subtitle")

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Button("admin_dashboard_action_specialists") { push(.specialists) }
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                            .foregroundColor(SanadTheme.primary)
                        Button("admin_dashboard_action_orgs") { push(.organizations) }
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                            .foregroundColor(SanadTheme.primary)
                    }
                    .coachMarkTarget("admin_header")

                    if let err = error {
                        Text(err)
                            .foregroundColor(SanadTheme.error)
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    countersGrid()

                    Button("shortcut_community") { push(.community) }
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                        .foregroundColor(SanadTheme.primary)

                    Text("dashboard_alerts")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(SanadTheme.onBg)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    alertsCard()
                        .coachMarkTarget("admin_alerts")

                    adminManagementLinks()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .refreshable { await load() }
        .background(SanadAtmosphereBackground())
        .navigationBarHidden(true)
        .coachMarks(key: "tour_admin_home", steps: [
            CoachMarkStep(id: "admin_users", title: "tour_admin_users_title", desc: "tour_admin_users_desc", targetId: "admin_users"),
            CoachMarkStep(id: "admin_sessions", title: "tour_admin_sessions_title", desc: "tour_admin_sessions_desc", targetId: "admin_sessions")
        ])
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
            await MainActor.run { self.error = NSLocalizedString("admin_dashboard_load_failed", comment: "") }
        }
        loading = false
    }

    @ViewBuilder
    private func countersGrid() -> some View {
        let c = dashboard?.counters
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                counterCard(title: "admin_dashboard_users", value: "\(c?.users ?? 0)")
                    .coachMarkTarget("admin_users")
                counterCard(title: "admin_dashboard_specialists", value: "\(c?.specialists ?? 0)")
            }
            HStack(spacing: 12) {
                counterCard(title: "admin_dashboard_orgs", value: "\(c?.organizations ?? 0)")
                counterCard(title: "admin_dashboard_sessions_week", value: "\(c?.sessions_week ?? 0)")
                    .coachMarkTarget("admin_sessions")
            }
            HStack(spacing: 12) {
                counterCard(title: "admin_dashboard_specialists_pending", value: "\(c?.specialists_pending ?? 0)")
                counterCard(title: "admin_dashboard_orgs_pending", value: "\(c?.organizations_pending ?? 0)")
            }
            HStack(spacing: 12) {
                counterCard(title: "admin_dashboard_appointments_today", value: "\(c?.appointments_today ?? 0)")
                counterCard(title: "admin_dashboard_library_posts", value: "\(c?.posts ?? 0)")
            }
        }
    }

    private func counterCard(title: LocalizedStringKey, value: String) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SanadTheme.placeholder)
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func alertsCard() -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("dashboard_alerts")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SanadTheme.placeholder)

                let alerts = dashboard?.alerts ?? []
                if alerts.isEmpty {
                    SanadEmptyState(message: "dashboard_alerts_empty")
                } else {
                    ForEach(alerts) { alert in
                        Button {
                            handleAlert(alert.raw_id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(alert.title ?? NSLocalizedString("dashboard_alert_default", comment: ""))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(SanadTheme.onBg)
                                Text(alert.message ?? "")
                                    .font(.system(size: 12))
                                    .foregroundColor(SanadTheme.placeholder)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(SanadTheme.surfaceAlt))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func handleAlert(_ alertId: String?) {
        guard let alertId else { return }
        switch alertId {
        case "pending_specialists":
            push(.specialists)
        case "pending_orgs":
            push(.organizations)
        default:
            break
        }
    }

    @ViewBuilder
    private func adminManagementLinks() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("admin_profile_quick_manage")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                adminLinkButton("admin_specialists_title") { push(.specialists) }
                adminLinkButton("admin_orgs_title") { push(.organizations) }
                adminLinkButton("admin_sessions_view") { push(.sessions) }
                adminLinkButton("admin_users_title") { push(.users) }
                adminLinkButton("shortcut_community") { push(.community) }
                adminLinkButton("admin_profile_title") { push(.settings) }
            }
        }
    }

    private func adminLinkButton(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(titleKey)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SanadTheme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).stroke(SanadTheme.primary.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func defaultQuickActions() -> [AdminDashboard.QuickAction] {
        [
            AdminDashboard.QuickAction(id: "approve_specialists", label: NSLocalizedString("admin_dashboard_action_specialists", comment: "")),
            AdminDashboard.QuickAction(id: "approve_orgs", label: NSLocalizedString("admin_dashboard_action_orgs", comment: "")),
            AdminDashboard.QuickAction(id: "sessions", label: NSLocalizedString("admin_dashboard_action_sessions", comment: "")),
            AdminDashboard.QuickAction(id: "users", label: NSLocalizedString("admin_dashboard_action_users", comment: "")),
            AdminDashboard.QuickAction(id: "library", label: NSLocalizedString("admin_dashboard_action_library", comment: "")),
            AdminDashboard.QuickAction(id: "wallet", label: NSLocalizedString("admin_dashboard_action_wallet", comment: "")),
            AdminDashboard.QuickAction(id: "reports", label: NSLocalizedString("reports_nav_title", comment: "")),
            AdminDashboard.QuickAction(id: "community", label: NSLocalizedString("shortcut_community", comment: "")),
            AdminDashboard.QuickAction(id: "vent", label: NSLocalizedString("admin_dashboard_action_vent", comment: "")),
            AdminDashboard.QuickAction(id: "daily_tips", label: NSLocalizedString("admin_dashboard_action_daily_tips", comment: "")),
            AdminDashboard.QuickAction(id: "settings", label: NSLocalizedString("admin_profile_title", comment: ""))
        ]
    }

    private func mergeQuickActions(_ fromApi: [AdminDashboard.QuickAction]?) -> [AdminDashboard.QuickAction] {
        let defaults = defaultQuickActions()
        guard let fromApi, !fromApi.isEmpty else { return defaults }
        var seen = Set<String>()
        var merged: [AdminDashboard.QuickAction] = []
        for action in fromApi {
            guard !action.id.isEmpty else { continue }
            seen.insert(action.id)
            if let localized = defaults.first(where: { $0.id == action.id }) {
                merged.append(localized)
            } else {
                merged.append(action)
            }
        }
        for action in defaults where !seen.contains(action.id) {
            merged.append(action)
        }
        return merged
    }

    private func shortcutItems() -> [ShortcutAction] {
        return mergeQuickActions(dashboard?.quick_actions).map { action in
            let route = adminRoute(for: action.id)
            return ShortcutAction(
                id: action.id,
                title: shortcutTitle(for: action.id, fallback: action.label),
                icon: shortcutIcon(for: action.id),
                actionTitle: shortcutActionTitle(for: action.id),
                destination: route.map { route in AnyView(adminDestination(for: route)) },
                onTap: route == nil ? { handleQuickAction(action.id) } : nil
            )
        }
    }

    private func adminRoute(for id: String) -> AdminRoute? {
        switch id {
        case "approve_specialists": return .specialists
        case "approve_orgs": return .organizations
        case "sessions": return .sessions
        case "users": return .users
        case "library": return .library
        case "wallet": return .wallet
        case "reports": return .reports
        case "community": return .community
        case "vent": return .vent
        case "daily_tips": return .dailyTips
        case "settings": return .settings
        default: return nil
        }
    }

    private func shortcutTitle(for id: String, fallback: String?) -> String {
        switch id {
        case "approve_specialists":
            return NSLocalizedString("admin_dashboard_action_specialists", comment: "")
        case "approve_orgs":
            return NSLocalizedString("admin_dashboard_action_orgs", comment: "")
        case "sessions":
            return NSLocalizedString("admin_dashboard_action_sessions", comment: "")
        case "users":
            return NSLocalizedString("admin_dashboard_action_users", comment: "")
        case "library":
            return NSLocalizedString("admin_dashboard_action_library", comment: "")
        case "wallet":
            return NSLocalizedString("admin_dashboard_action_wallet", comment: "")
        case "reports":
            return NSLocalizedString("reports_nav_title", comment: "")
        case "community":
            return NSLocalizedString("shortcut_community", comment: "")
        case "vent":
            return NSLocalizedString("admin_dashboard_action_vent", comment: "")
        case "daily_tips":
            return NSLocalizedString("admin_dashboard_action_daily_tips", comment: "")
        case "settings":
            return NSLocalizedString("admin_dashboard_action_settings", comment: "")
        default:
            return fallback ?? NSLocalizedString("dashboard_action_default", comment: "")
        }
    }

    private func shortcutIcon(for id: String) -> String {
        switch id {
        case "approve_specialists":
            return "checkmark.seal"
        case "approve_orgs":
            return "building.2"
        case "sessions":
            return "calendar"
        case "users":
            return "person.2"
        case "library":
            return "books.vertical"
        case "wallet":
            return "wallet.pass"
        case "reports":
            return "chart.bar"
        case "community":
            return "person.3.fill"
        case "vent":
            return "bubble.left.and.bubble.right"
        case "daily_tips":
            return "lightbulb"
        case "settings":
            return "gearshape"
        default:
            return "square.grid.2x2"
        }
    }

    private func shortcutActionTitle(for id: String) -> String {
        switch id {
        case "sessions":
            return NSLocalizedString("shortcuts_action_book", comment: "")
        default:
            return NSLocalizedString("shortcuts_action_explore", comment: "")
        }
    }

    private func handleQuickAction(_ id: String) {
        switch id {
        case "approve_specialists":
            push(.specialists)
        case "approve_orgs":
            push(.organizations)
        case "sessions":
            push(.sessions)
        case "users":
            push(.users)
        case "library":
            push(.library)
        case "wallet":
            push(.wallet)
        case "reports":
            push(.reports)
        case "community":
            push(.community)
        case "vent":
            push(.vent)
        case "daily_tips":
            push(.dailyTips)
        case "settings":
            push(.settings)
        default:
            showInfo(id)
        }
    }

    private func push(_ route: AdminRoute) {
        if #available(iOS 16.0, *) {
            navPath.append(route)
        } else {
            legacyRoute = route
        }
    }

    @ViewBuilder
    private func adminDestination(for route: AdminRoute) -> some View {
        NestedNavigationHost {
            switch route {
            case .community:
                CommunityListView().environmentObject(authVM)
            default:
                adminScreen(for: route)
            }
        }
    }

    @ViewBuilder
    private func adminScreen(for route: AdminRoute) -> some View {
        switch route {
        case .users: AdminUsersView()
        case .specialists: AdminSpecialistsView()
        case .organizations: AdminOrganizationsView()
        case .sessions: AdminSessionsView()
        case .library: AdminLibraryPostsView()
        case .wallet: AdminWalletView()
        case .reports: ReportsView()
        case .vent: AdminVentView()
        case .dailyTips: AdminDailyTipsView()
        case .settings: AdminProfileView().environmentObject(authVM)
        case .community: EmptyView()
        }
    }

    private func showInfo(_ message: String) {
        alertMessage = message
        showAlert = true
    }

    @ViewBuilder
    private func legacyNavigationLinks() -> some View {
        NavigationLink(destination: adminDestination(for: .users), tag: AdminRoute.users, selection: $legacyRoute) { EmptyView() }
        NavigationLink(destination: adminDestination(for: .specialists), tag: AdminRoute.specialists, selection: $legacyRoute) { EmptyView() }
        NavigationLink(destination: adminDestination(for: .organizations), tag: AdminRoute.organizations, selection: $legacyRoute) { EmptyView() }
        NavigationLink(destination: adminDestination(for: .sessions), tag: AdminRoute.sessions, selection: $legacyRoute) { EmptyView() }
        NavigationLink(destination: adminDestination(for: .library), tag: AdminRoute.library, selection: $legacyRoute) { EmptyView() }
        NavigationLink(destination: adminDestination(for: .wallet), tag: AdminRoute.wallet, selection: $legacyRoute) { EmptyView() }
        NavigationLink(destination: adminDestination(for: .reports), tag: AdminRoute.reports, selection: $legacyRoute) { EmptyView() }
        NavigationLink(destination: adminDestination(for: .vent), tag: AdminRoute.vent, selection: $legacyRoute) { EmptyView() }
        NavigationLink(destination: adminDestination(for: .dailyTips), tag: AdminRoute.dailyTips, selection: $legacyRoute) { EmptyView() }
        NavigationLink(destination: adminDestination(for: .settings), tag: AdminRoute.settings, selection: $legacyRoute) { EmptyView() }
        NavigationLink(destination: adminDestination(for: .community), tag: AdminRoute.community, selection: $legacyRoute) { EmptyView() }
    }
}

#Preview { AdminDashboardView(mode: .dashboard) }

private enum AdminRoute: String, Identifiable {
    case users
    case specialists
    case organizations
    case sessions
    case library
    case wallet
    case reports
    case vent
    case dailyTips
    case settings
    case community

    var id: String { rawValue }
}
