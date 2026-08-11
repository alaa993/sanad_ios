import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVKit

struct VentView: View {
    @State private var posts: [VentPostModel] = []
    @State private var loading = false
    @State private var error: String?
    @State private var composerText = ""
    @State private var showSelfChat = false

    private let service = VentService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "community_vent_title", subtitle: "community_vent_subtitle")

                VStack(alignment: .leading, spacing: 14) {
                    safeSpaceBanner

                    if let err = error {
                        SanadInlineBanner(err, style: .error)
                    }

                    composer

                    if loading && posts.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
                    }

                    if posts.isEmpty && !loading {
                        SanadEmptyState(message: "community_empty_feed")
                    }

                    ForEach(posts) { post in
                        postCard(post)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
        .background(SanadAtmosphereBackground())
        .navigationBarHidden(true)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showSelfChat) {
            NavigationView {
                SelfChatView()
            }
        }
    }

    private var safeSpaceBanner: some View {
        SanadListCard {
            HStack(spacing: 12) {
                SanadIcon.safePlace.image
                    .font(.system(size: 22))
                    .foregroundColor(SanadTheme.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("shortcuts_safe_place")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(SanadTheme.onBg)
                    Text("community_vent_hint")
                        .font(.system(size: 13))
                        .foregroundColor(SanadTheme.placeholder)
                }
            }
        }
    }

    private var composer: some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("community_vent_hint")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SanadTheme.placeholder)
                TextEditor(text: $composerText)
                    .frame(height: 100)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(SanadTheme.fieldStroke)
                    )

                HStack {
                    Button("community_vent_post") {
                        Task { await submitVent() }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(SanadTheme.primary))
                    .foregroundColor(SanadTheme.onPrimary)

                    Button("community_vent_chat") {
                        showSelfChat = true
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                    .foregroundColor(SanadTheme.primary)
                }
            }
        }
    }

    private func postCard(_ post: VentPostModel) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(post.alias ?? NSLocalizedString("community_vent_alias_default", comment: ""))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SanadTheme.placeholder)
                Text(post.body)
                    .font(.system(size: 15))
                    .foregroundColor(SanadTheme.onBg)
                if let created = post.created_at {
                    Text(created)
                        .font(.system(size: 11))
                        .foregroundColor(SanadTheme.placeholder)
                }
                HStack(spacing: 8) {
                    reactionButton(
                        title: String(format: NSLocalizedString("community_vent_empathy_count", comment: ""), post.empathy_count ?? 0),
                        icon: "heart.fill",
                        active: post.user_empathy == true
                    ) {
                        Task { await react(post: post, type: "empathy") }
                    }

                    reactionButton(
                        title: String(format: NSLocalizedString("community_vent_support_count", comment: ""), post.support_count ?? 0),
                        icon: "hand.thumbsup.fill",
                        active: post.user_support == true
                    ) {
                        Task { await react(post: post, type: "support") }
                    }

                    Button(NSLocalizedString("community_vent_report", comment: "")) {
                        Task { await report(post: post) }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundColor(SanadTheme.placeholder)
                }
            }
        }
    }

    private func reactionButton(title: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label { Text(title) } icon: { SanadIcon.forShortcut(id: icon).image }
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(active ? SanadTheme.primary : SanadTheme.primary.opacity(0.12)))
                .foregroundColor(active ? SanadTheme.onPrimary : SanadTheme.primary)
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("community_vent_login_required", comment: "")
            return
        }
        loading = true
        do {
            let res = try await service.list(token: token)
            await MainActor.run {
                posts = res
                error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("community_vent_load_failed", comment: "") }
        }
        loading = false
    }

    private func submitVent() async {
        guard let token = KeychainHelper.getToken(),
              !composerText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            try await service.create(body: composerText, token: token)
            await MainActor.run { composerText = "" }
            await load()
        } catch {
            await MainActor.run { self.error = NSLocalizedString("community_vent_post_failed", comment: "") }
        }
    }

    private func react(post: VentPostModel, type: String) async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            _ = try await service.react(postId: post.id, type: type, token: token)
            await load()
        } catch {
            await MainActor.run { self.error = NSLocalizedString("vent_error", comment: "") }
        }
    }

    private func report(post: VentPostModel) async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await service.report(postId: post.id, reason: nil, token: token)
        } catch {
            await MainActor.run { self.error = NSLocalizedString("vent_error", comment: "") }
        }
    }
}

#if DEBUG
#Preview { VentView() }
#endif
