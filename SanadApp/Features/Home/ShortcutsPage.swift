import SwiftUI

struct ShortcutAction: Identifiable {
    let id: String
    let title: String
    let icon: String
    let actionTitle: String
    let destination: AnyView?
    let onTap: (() -> Void)?
    var subtitleKey: String = "care_hub_link_subtitle"

    init(
        id: String,
        title: String,
        icon: String,
        actionTitle: String,
        destination: AnyView? = nil,
        onTap: (() -> Void)? = nil,
        subtitleKey: String = "care_hub_link_subtitle"
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.actionTitle = actionTitle
        self.destination = destination
        self.onTap = onTap
        self.subtitleKey = subtitleKey
    }
}

/// Care hub — calm destinations list (replaces dense shortcut grid).
struct ShortcutsPage: View {
    let items: [ShortcutAction]
    var showsSafePlace: Bool = true
    var primaryDestination: AnyView? = nil
    var primaryAction: (() -> Void)? = nil
    var primaryTitle: LocalizedStringKey = "cta_new_session"
    @State private var showSafePlace = false
    @State private var appear = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                brandHeader
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 8)

                if primaryAction != nil || primaryDestination != nil {
                    Group {
                        if let primaryAction {
                            Button(action: primaryAction) {
                                primaryButtonLabel
                            }
                            .buttonStyle(.plain)
                        } else if let primaryDestination {
                            NavigationLink {
                                primaryDestination
                            } label: {
                                primaryButtonLabel
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .coachMarkTarget("sp_primary")
                }

                Text("care_hub_title")
                    .font(SanadFont.title(20))
                    .foregroundColor(SanadTheme.onBg)

                VStack(spacing: 10) {
                    ForEach(items) { item in
                        careRow(item)
                    }
                }
                .coachMarkTarget("sp_shortcuts")

                if showsSafePlace {
                    Button {
                        showSafePlace = true
                    } label: {
                        SanadCareLinkRow(
                            icon: .safePlace,
                            title: "shortcut_safe_place",
                            subtitle: "care_hub_safe_subtitle"
                        )
                    }
                    .buttonStyle(.plain)
                    .coachMarkTarget("sp_safe")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .background(SanadAtmosphereBackground())
        .onAppear {
            withAnimation(.easeOut(duration: 0.28)) { appear = true }
        }
        .coachMarks(
            key: showsSafePlace ? "tour_shortcuts_safe" : "tour_shortcuts",
            steps: showsSafePlace
                ? [
                    CoachMarkStep(id: "sp_shortcuts", title: "tour_home_shortcuts_title", desc: "tour_home_shortcuts_desc", targetId: "sp_shortcuts"),
                    CoachMarkStep(id: "sp_safe", title: "tour_home_safe_title", desc: "tour_home_safe_desc", targetId: "sp_safe")
                ]
                : [
                    CoachMarkStep(id: "sp_shortcuts", title: "tour_home_shortcuts_title", desc: "tour_home_shortcuts_desc", targetId: "sp_shortcuts")
                ]
        )
        .sheet(isPresented: $showSafePlace) {
            NavigationView {
                SelfChatView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("common_close") { showSafePlace = false }
                        }
                    }
            }
        }
    }

    private var primaryButtonLabel: some View {
        Text(primaryTitle)
            .font(SanadFont.button(16))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(SanadTheme.primary)
            )
            .foregroundColor(SanadTheme.onPrimary)
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(SanadTheme.logoName(background: false))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("app_name")
                        .font(SanadFont.display(26))
                        .foregroundColor(SanadTheme.primary)
                    Text("care_hub_subtitle")
                        .font(SanadFont.body(14))
                        .foregroundColor(SanadTheme.placeholder)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func careRow(_ item: ShortcutAction) -> some View {
        if let destination = item.destination {
            NavigationLink {
                destination
            } label: {
                SanadCareLinkRow(
                    icon: SanadIcon.forShortcut(id: item.id.isEmpty ? item.icon : item.id),
                    title: LocalizedStringKey(localizedTitleKey(for: item)),
                    subtitle: LocalizedStringKey(item.subtitleKey)
                )
            }
            .buttonStyle(.plain)
        } else {
            Button {
                item.onTap?()
            } label: {
                SanadCareLinkRow(
                    icon: SanadIcon.forShortcut(id: item.id.isEmpty ? item.icon : item.id),
                    title: LocalizedStringKey(localizedTitleKey(for: item)),
                    subtitle: LocalizedStringKey(item.subtitleKey)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func localizedTitleKey(for item: ShortcutAction) -> String {
        let key = item.id.lowercased()
        if key.contains("session") || key.contains("book") {
            return "patient_dashboard_shortcut_sessions"
        }
        if key.contains("community") || key.contains("group") {
            return "shortcut_community"
        }
        if key.contains("appointments") || key.contains("calendar") {
            return "calendar_appointments_title"
        }
        if key.contains("wallet") {
            return "nav_wallet"
        }
        if key.contains("library") {
            return "nav_library"
        }
        if key.contains("patient") {
            return "nav_patients"
        }
        if key.contains("chat") || key.contains("message") {
            return "chat_list_title"
        }
        if key.contains("notification") {
            return "notifications_title"
        }
        if key.contains("availability") {
            return "calendar_availability_title"
        }
        if key.contains("specialist") {
            return "patient_dashboard_shortcut_specialists"
        }
        if key.contains("report") {
            return "org_dashboard_action_reports"
        }
        if key.contains("user") {
            return "admin_users_title"
        }
        if key.contains("vent") {
            return "nav_vent"
        }
        if key.contains("task") {
            return "nav_tasks"
        }
        if key.contains("coach") {
            return "nav_coach"
        }
        return item.title
    }
}
