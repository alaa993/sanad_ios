import SwiftUI

struct AdminLibraryPostsView: View {
    @State private var posts: [AdminPost] = []
    @State private var error: String?
    @State private var showAlert = false
    @State private var alertMessage = ""

    private let service = AdminService()

    var body: some View {
        List {
            if let err = error {
                Text(err).foregroundColor(.red)
            }
            ForEach(posts) { post in
                VStack(alignment: .leading, spacing: 6) {
                    Text(post.title ?? NSLocalizedString("admin_library_post_default", comment: ""))
                        .font(.system(size: 15, weight: .semibold))
                    if let status = post.status {
                        Text(String(format: NSLocalizedString("admin_library_post_status", comment: ""), status))
                            .font(.system(size: 12))
                            .foregroundColor(SanadTheme.placeholder)
                    }
                    HStack(spacing: 10) {
                        if let author = post.author {
                            Text(String(format: NSLocalizedString("admin_library_post_author", comment: ""), author))
                                .font(.system(size: 12))
                                .foregroundColor(SanadTheme.placeholder)
                        }
                        if let likes = post.likes {
                            Text(String(format: NSLocalizedString("admin_library_post_likes", comment: ""), likes))
                                .font(.system(size: 12))
                                .foregroundColor(SanadTheme.placeholder)
                        }
                    }
                    Button("admin_library_post_toggle") {
                        Task { await toggle(post.id) }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SanadTheme.primary)
                }
                .padding(.vertical, 6)
            }
        }
        .listStyle(.plain)
        .navigationTitle("admin_library_posts_title")
        .task { await load() }
        .refreshable { await load() }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("common_ok", role: .cancel) {}
        }
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        do {
            let res = try await service.posts(token: token)
            await MainActor.run {
                self.posts = res
                self.error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("admin_library_posts_load_failed", comment: "") }
        }
    }

    private func toggle(_ id: Int) async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await service.togglePost(id: id, token: token)
            await load()
        } catch {
            alertMessage = NSLocalizedString("admin_library_posts_action_failed", comment: "")
            showAlert = true
        }
    }
}

#Preview { NavigationView { AdminLibraryPostsView() } }
