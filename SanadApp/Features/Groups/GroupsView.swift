import SwiftUI

struct GroupsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var groups: [GroupSession] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showCreate = false
    @State private var ageFilter: String?
    @State private var disorderFilter: String?
    @State private var ageCategories: [CatalogCaseType] = []
    @State private var disorderTags: [CatalogCaseType] = []

    private let service = GroupSessionsService()
    private let catalogService = CatalogService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "groups_title", showsBackButton: true)

                VStack(alignment: .leading, spacing: 16) {
                    if !ageCategories.isEmpty || !disorderTags.isEmpty {
                        filterChips(title: "groups_filter_age", items: ageCategories, selected: $ageFilter)
                        filterChips(title: "groups_filter_disorder", items: disorderTags, selected: $disorderFilter)
                    }

                    if loading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }

                    if let err = error {
                        SanadInlineBanner(err, style: .error)
                    }

                    if groups.isEmpty && !loading {
                        SanadListCard {
                            SanadEmptyState(
                                message: "groups_empty",
                                actionTitle: canCreate ? "groups_create" : nil,
                                action: canCreate ? { showCreate = true } : nil
                            )
                        }
                    } else {
                        ForEach(groups) { group in
                            NavigationLink(destination: GroupDetailView(groupId: group.id)) {
                                groupCard(group)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if canCreate && !groups.isEmpty {
                        Button("groups_create") { showCreate = true }
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(SanadTheme.primary))
                            .foregroundColor(SanadTheme.onPrimary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await bootstrap() }
        .refreshable { await load() }
        .onChange(of: ageFilter) { _ in Task { await load() } }
        .onChange(of: disorderFilter) { _ in Task { await load() } }
        .sheet(isPresented: $showCreate) {
            GroupCreateView(onCreated: { Task { await load() } })
        }
    }

    private var canCreate: Bool {
        (authVM.userRole ?? "").lowercased() == "specialist"
    }

    private func bootstrap() async {
        if let token = KeychainHelper.getToken() {
            if let catalog = try? await catalogService.load(token: token) {
                await MainActor.run {
                    ageCategories = catalog.group_age_categories ?? []
                    disorderTags = catalog.group_disorder_tags ?? []
                }
            }
        }
        await load()
    }

    private func filterChips(title: LocalizedStringKey, items: [CatalogCaseType], selected: Binding<String?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(label: "community_filter_all", id: nil, selected: selected)
                    ForEach(items) { item in
                        filterChip(label: LocalizedStringKey(item.label(for: AppLanguage.currentCode)), id: item.id, selected: selected)
                    }
                }
            }
        }
    }

    private func filterChip(label: LocalizedStringKey, id: String?, selected: Binding<String?>) -> some View {
        let active = selected.wrappedValue == id
        return Button {
            selected.wrappedValue = id
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(active ? SanadTheme.primary : SanadTheme.primary.opacity(0.1)))
                .foregroundColor(active ? SanadTheme.onPrimary : SanadTheme.primary)
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        do {
            let res = try await service.list(token: token, ageCategory: ageFilter, disorderTag: disorderFilter)
            await MainActor.run {
                self.groups = res
                self.error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("groups_load_failed", comment: "") }
        }
        loading = false
    }

    private func groupCard(_ group: GroupSession) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(group.title ?? NSLocalizedString("groups_default_title", comment: ""))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                Text(group.topic ?? "—")
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.placeholder)
                Text(formatSchedule(start: group.start_at, end: group.end_at))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
                Text(statusLabel(group.status))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SanadTheme.primary)
                Text(metaLine(group))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
            }
        }
    }

    private func metaLine(_ group: GroupSession) -> String {
        let count = group.participants_count ?? 0
        let specialist = group.specialist_name ?? "—"
        var line = String(format: NSLocalizedString("groups_participants", comment: ""), count, specialist)
        if let spots = group.spots_left, spots > 0 {
            line += " · " + String(format: NSLocalizedString("group_sessions_spots_left", comment: ""), spots)
        }
        return line
    }

    private func statusLabel(_ raw: String?) -> String {
        let value = raw?.lowercased() ?? ""
        switch value {
        case "scheduled":
            return NSLocalizedString("group_status_upcoming", comment: "")
        case "ongoing", "in_progress":
            return NSLocalizedString("group_status_live", comment: "")
        case "finished", "completed":
            return NSLocalizedString("group_status_completed", comment: "")
        case "canceled", "cancelled":
            return NSLocalizedString("group_status_cancelled", comment: "")
        default:
            return raw ?? NSLocalizedString("common_unknown", comment: "")
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

#Preview { GroupsView().environmentObject(AuthViewModel()) }
