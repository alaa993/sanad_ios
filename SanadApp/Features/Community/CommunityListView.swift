import SwiftUI

/// قائمة المجتمعات — مبسّطة مع صلاحيات حسب الدور.
struct CommunityListView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var communities: [CommunitySummary] = []
    @State private var search = ""
    @State private var filterMode = 0
    @State private var categoryFilter: String?
    @State private var catalogCategories: [CatalogCaseType] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showCreate = false
    @State private var newSlug = ""
    @State private var newName = ""
    @State private var newAbout = ""
    @State private var newVisibility = "public"
    @State private var newKind = "discussion"

    private let service = CommunityService()
    private let catalogService = CatalogService()

    private var policy: CommunityRolePolicy {
        CommunityRolePolicy(rawRole: authVM.userRole)
    }

    private var roleFiltered: [CommunitySummary] {
        policy.filters(communities)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(
                    title: LocalizedStringKey(policy.screenTitleKey),
                    subtitle: LocalizedStringKey(policy.screenSubtitleKey),
                    showsBackButton: true
                )

                VStack(alignment: .leading, spacing: 14) {
                    if policy.showsSearch {
                        SanadSearchField(text: $search)
                    }

                    if policy.showsVent || policy.showsAnonymousMatch || policy.showsCoach || policy.showsPublicFeedCta {
                        supportToolsSection
                    }

                    if policy.showsFilters {
                        Picker("community_filter", selection: $filterMode) {
                            Text("community_filter_all").tag(0)
                            Text("community_filter_joined").tag(1)
                            Text("community_filter_discover").tag(2)
                        }
                        .pickerStyle(.segmented)

                        if !catalogCategories.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    categoryChip(label: "community_filter_all", id: nil)
                                    ForEach(catalogCategories) { cat in
                                        categoryChip(label: LocalizedStringKey(cat.label(for: AppLanguage.currentCode)), id: cat.id)
                                    }
                                }
                            }
                        }
                    }

                    if policy.canCreateCommunity {
                        Button("community_create") { showCreate = true }
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                            .foregroundColor(SanadTheme.primary)
                    }

                    if let err = error {
                        SanadInlineBanner(err, style: .error)
                    }

                    if loading {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 8)
                    }

                    if !filteredCommunities.isEmpty {
                        Text("community_list_title")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(SanadTheme.onBg)
                    }

                    if filteredCommunities.isEmpty && !loading {
                        SanadListCard {
                            SanadEmptyState(message: "community_empty")
                        }
                    }

                    ForEach(filteredCommunities) { community in
                        communityRow(community)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .background(SanadAtmosphereBackground())
        .navigationBarHidden(true)
        .task { await bootstrap() }
        .refreshable { await load() }
        .onChange(of: categoryFilter) { _ in Task { await load() } }
        .onAppear { authVM.reconnectRealtime() }
        .sheet(isPresented: $showCreate) { createCommunitySheet }
    }

    private var createCommunitySheet: some View {
        NavigationView {
            Form {
                Section(header: Text("community_create_slug")) {
                    TextField("community_create_slug", text: $newSlug)
                        .textInputAutocapitalization(.never)
                }
                Section(header: Text("community_create_name")) {
                    TextField("community_create_name", text: $newName)
                }
                Section(header: Text("community_create_about")) {
                    TextField("community_create_about", text: $newAbout, axis: .vertical)
                }
                Picker("community_create_visibility", selection: $newVisibility) {
                    Text("community_visibility_public").tag("public")
                    Text("community_visibility_private").tag("private")
                }
                Picker("community_create_kind", selection: $newKind) {
                    Text("community_kind_discussion").tag("discussion")
                    Text("community_kind_qa").tag("qa")
                }
            }
            .navigationTitle("community_create")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_cancel") { showCreate = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common_save") { Task { await createCommunity() } }
                        .disabled(newSlug.trimmingCharacters(in: .whitespaces).isEmpty || newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var supportToolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(policy.role == "specialist" ? "community_specialist_cta_title" : "community_cta_title"))
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(SanadTheme.onBg)
            Text(LocalizedStringKey(policy.role == "specialist" ? "community_specialist_cta_subtitle" : "community_cta_subtitle"))
                .font(.system(size: 13))
                .foregroundColor(SanadTheme.placeholder)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if policy.showsPublicFeedCta, let community = firstPublicCommunity() {
                        NavigationLink(
                            destination: CommunityFeedView(
                                communityId: community.id,
                                communityTitle: community.name ?? community.slug ?? ""
                            ).environmentObject(authVM)
                        ) {
                            supportToolChip(title: "community_open_feed", icon: "person.3.fill")
                        }
                        .buttonStyle(.plain)
                    }
                    if policy.showsVent {
                        NavigationLink(destination: VentView().environmentObject(authVM)) {
                            supportToolChip(title: "community_vent_title", icon: "bubble.left.and.bubble.right.fill")
                        }
                        .buttonStyle(.plain)
                    }
                    if policy.showsAnonymousMatch {
                        NavigationLink(destination: AnonymousMatchView().environmentObject(authVM)) {
                            supportToolChip(title: "anonymous_match_title", icon: "person.2.circle")
                        }
                        .buttonStyle(.plain)
                    }
                    if policy.showsCoach {
                        NavigationLink(destination: CoachView()) {
                            supportToolChip(title: "coach_title", icon: "sparkles")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SanadTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(SanadTheme.fieldStroke.opacity(0.7), lineWidth: 1)
                )
        )
    }

    private func supportToolChip(title: LocalizedStringKey, icon: String) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(SanadTheme.primary.opacity(0.12))
                .frame(width: 48, height: 48)
                .overlay(SanadIcon.forShortcut(id: icon).image.foregroundColor(SanadTheme.primary))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 88)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SanadTheme.surface)
        )
    }

    private func firstPublicCommunity() -> CommunitySummary? {
        policy.filters(communities).first
    }

    private var filteredCommunities: [CommunitySummary] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return roleFiltered.filter { c in
            let joined = c.joined == true
            switch filterMode {
            case 1: if !joined { return false }
            case 2: if joined { return false }
            default: break
            }
            if q.isEmpty { return true }
            let title = (c.name ?? c.slug ?? "").lowercased()
            let about = (c.about ?? "").lowercased()
            return title.contains(q) || about.contains(q)
        }
    }

    private func communityRow(_ c: CommunitySummary) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 10) {
                NavigationLink(destination: CommunityFeedView(communityId: c.id, communityTitle: c.name ?? c.slug ?? "").environmentObject(authVM)) {
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(SanadTheme.primary.opacity(0.12))
                            .frame(width: 44, height: 44)
                            .overlay(
                                (c.kind == "qa" ? SanadIcon.info.image : SanadIcon.community.image)
                                    .foregroundColor(SanadTheme.primary)
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(c.name ?? c.slug ?? "—")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(SanadTheme.onBg)
                            if let about = c.about, about.trimmingCharacters(in: .whitespacesAndNewlines).count > 1,
                               about.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                != (c.name ?? c.slug ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                                Text(about)
                                    .font(.system(size: 12))
                                    .foregroundColor(SanadTheme.placeholder)
                                    .lineLimit(2)
                            }
                            Text(String(format: NSLocalizedString("community_members_count", comment: ""), c.members_count ?? 0))
                                .font(.system(size: 11))
                                .foregroundColor(SanadTheme.placeholder)
                        }
                        Spacer(minLength: 0)
                        SanadIcon.chevronLeft.image
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(SanadTheme.placeholder)
                    }
                }
                .buttonStyle(.plain)

                if policy.canJoinFreely {
                    let joined = c.joined == true
                    Button(joined ? "community_leave" : "community_join") {
                        Task { await toggleMembership(c) }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(joined ? SanadTheme.error.opacity(0.12) : SanadTheme.primary)
                    )
                    .foregroundColor(joined ? SanadTheme.error : SanadTheme.onPrimary)
                }
            }
        }
    }

    private func toggleMembership(_ c: CommunitySummary) async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            let response = try await (c.joined == true
                ? service.leave(communityId: c.id, token: token)
                : service.join(communityId: c.id, token: token))
            await MainActor.run {
                if let idx = communities.firstIndex(where: { $0.id == c.id }) {
                    var updated = communities[idx]
                    updated.joined = response.joined
                    updated.members_count = response.members_count
                    communities[idx] = updated
                }
                error = nil
            }
        } catch _ {
            await MainActor.run { self.error = NSLocalizedString("community_membership_update_failed", comment: "") }
        }
    }

    private func categoryChip(label: LocalizedStringKey, id: String?) -> some View {
        let active = categoryFilter == id
        return Button {
            categoryFilter = id
            Task { await load() }
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

    private func bootstrap() async {
        if let token = KeychainHelper.getToken() {
            if let catalog = try? await catalogService.load(token: token) {
                await MainActor.run { catalogCategories = catalog.community_categories ?? [] }
            }
        }
        await load()
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else { return }
        loading = true
        defer { loading = false }
        do {
            let list = try await service.list(token: token, category: categoryFilter)
            await MainActor.run {
                communities = list
                error = nil
            }
        } catch _ {
            await MainActor.run { self.error = NSLocalizedString("community_load_failed", comment: "") }
        }
    }

    private func createCommunity() async {
        guard let token = KeychainHelper.getToken() else { return }
        let slug = newSlug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slug.isEmpty, !name.isEmpty else { return }
        do {
            _ = try await service.create(
                slug: slug,
                nameAr: name,
                nameEn: name,
                about: newAbout.isEmpty ? nil : newAbout,
                visibility: newVisibility,
                kind: newKind,
                token: token
            )
            await MainActor.run {
                newSlug = ""
                newName = ""
                newAbout = ""
                showCreate = false
                error = NSLocalizedString("community_create_success", comment: "")
            }
            await load()
        } catch {
            await MainActor.run { self.error = NSLocalizedString("community_create_failed", comment: "") }
        }
    }
}
