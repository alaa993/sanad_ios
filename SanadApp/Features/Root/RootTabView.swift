import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selection: TabKind = .shortcuts
    @State private var tabBarHeight: CGFloat = 0

    private var visibleTabs: [TabKind] {
        let tabs = RoleTabConfiguration.tabs(for: authVM.userRole)
        return tabs.isEmpty ? [.shortcuts] : tabs
    }

    var body: some View {
        tabDisplay
            .padding(.bottom, tabBarHeight)
            .overlay(alignment: .bottom) {
                HStack {
                    Spacer(minLength: 0)
                    CustomTabBar(selection: $selection, tabs: visibleTabs)
                    Spacer(minLength: 0)
                }
                    .environmentObject(authVM)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: TabBarHeightKey.self, value: proxy.size.height)
                        }
                    )
            }
            .onPreferenceChange(TabBarHeightKey.self) { height in
                if tabBarHeight != height {
                    tabBarHeight = height
                }
            }
        .onAppear {
            selection = RoleRouter.defaultTab(for: authVM.userRole)
        }
        .onChange(of: authVM.userRole) {
            selection = RoleRouter.defaultTab(for: authVM.userRole)
        }
        .onChange(of: authVM.preferredTab) { _, tab in
            guard let tab else { return }
            if visibleTabs.contains(tab) {
                selection = tab
            }
            authVM.preferredTab = nil
        }
        .onChange(of: authVM.pendingPushRoute) { _, route in
            guard route != nil else { return }
            let homeTab: TabKind = visibleTabs.contains(.dashboard) ? .dashboard : .shortcuts
            if visibleTabs.contains(homeTab) {
                selection = homeTab
            }
        }
        .coachMarks(key: "tour_nav", steps: [
            CoachMarkStep(id: "tab_bar", title: "tour_nav_title", desc: "tour_nav_desc", targetId: "tab_bar")
        ])
        .sanadTypography()
        .preferredColorScheme(.light)
        .background(SanadTheme.tabBarBackground.ignoresSafeArea(edges: .bottom))
        .onAppear {
            SanadSystemChrome.apply(tabBarTint: SanadTheme.tabBarBackground)
        }
    }

    @ViewBuilder
    private var tabDisplay: some View {
        let active = visibleTabs.contains(selection) ? selection : visibleTabs.first ?? .shortcuts
        tabContent(for: active)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.easeInOut(duration: 0.2), value: selection)
    }

    @ViewBuilder
    private func tabContent(for tab: TabKind) -> some View {
        switch tab {
        case .dashboard:
            HomeView(mode: .dashboard)
        case .shortcuts:
            HomeView(mode: .shortcutsOnly)
        case .profile:
            ProfileTabView()
        }
    }
}

private struct TabBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct CustomTabBar: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Binding var selection: TabKind
    let tabs: [TabKind]

    var body: some View {
        if tabs.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    button(for: tab)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .coachMarkTarget("tab_bar")
            .background(
                SanadTheme.tabBarBackground
                    .shadow(color: SanadTheme.tabBarShadow, radius: 12, x: 0, y: -2)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(SanadTheme.tabBarBorder)
                            .frame(height: 1)
                    }
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    private func button(for tab: TabKind) -> some View {
        let selected = selection == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 4) {
                tab.sanadIcon.view(size: selected ? 22 : 20)
                    .foregroundColor(selected ? SanadTheme.tabBarActive : SanadTheme.tabBarInactive)
                    .frame(width: 44, height: 28)
                Text(tab.title(for: authVM.userRole))
                    .font(SanadFont.caption(11))
                    .foregroundColor(selected ? SanadTheme.tabBarActive : SanadTheme.tabBarInactive)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .coachMarkTarget(targetId(for: tab))
    }

    private func targetId(for tab: TabKind) -> String {
        switch tab {
        case .dashboard: return "tab_dashboard"
        case .shortcuts: return "tab_shortcuts"
        case .profile: return "tab_profile"
        }
    }
}

enum TabKind: Hashable {
    case dashboard
    case shortcuts
    case profile

    func title(for role: String?) -> LocalizedStringKey {
        switch self {
        case .dashboard: return "nav_home"
        case .shortcuts: return "nav_care"
        case .profile:
            if (role ?? "").lowercased() == "admin" { return "admin_profile_title" }
            return "nav_me"
        }
    }

    var sanadIcon: SanadIcon {
        switch self {
        case .dashboard: return .home
        case .shortcuts: return .care
        case .profile: return .profile
        }
    }
}

struct RoleTabConfiguration {
    static func tabs(for rawRole: String?) -> [TabKind] {
        return [.dashboard, .shortcuts, .profile]
    }
}

#Preview { RootTabView().environmentObject(AuthViewModel()) }
