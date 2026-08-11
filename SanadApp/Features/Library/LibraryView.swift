import SwiftUI
import AVKit
import Combine

struct LibraryView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var categories: [LibraryCategory] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showComposer = false
    @State private var newTitle = ""
    @State private var newBody = ""
    @State private var publishNow = true
    @State private var dailyTip: LibraryDailyTip?
    @State private var curatedArticles: [LibraryArticleItem] = []
    @State private var tags: [String] = []
    @State private var selectedTag: String?
    @State private var realtimeCancellable: AnyCancellable?

    private let service = LibraryService()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    SanadHeroHeader(title: "library_title", subtitle: "library_subtitle", showsBackButton: true)

                    VStack(alignment: .leading, spacing: 16) {
                        dailyTipCard
                        curatedSection
                        tagFilter
                        errorView
                        publishButton
                        loadingView
                        emptyStateView
                        categoriesList
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
            .background(SanadAtmosphereBackground())
            .navigationBarHidden(true)
        }
        .task { await load() }
        .refreshable { await load() }
        .onAppear { subscribeRealtime() }
        .onDisappear { realtimeCancellable?.cancel() }
        .sheet(isPresented: $showComposer) { composerSheet }
    }

    private func subscribeRealtime() {
        authVM.reconnectRealtime()
        realtimeCancellable = RealtimeSocket.shared.events
            .receive(on: DispatchQueue.main)
            .sink { event in
                if case .notification(let type, _) = event, type == "library:updated" || type.hasPrefix("library") {
                    Task { await load() }
                }
            }
    }

    @ViewBuilder
    private var dailyTipCard: some View {
        if let tip = dailyTip, let body = tip.body, !body.isEmpty {
            VStack(alignment: .trailing, spacing: 6) {
                Text("library_daily_tip_label")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                if let title = tip.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                Text(body)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .background(RoundedRectangle(cornerRadius: 16).fill(SanadTheme.primary))
        }
    }

    @ViewBuilder
    private var curatedSection: some View {
        if !curatedArticles.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("library_curated_syria_europe_title")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(SanadTheme.onBg)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(curatedArticles) { article in
                            NavigationLink {
                                LibraryDetailView(articleId: article.id)
                            } label: {
                                curatedCoverCard(article)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func curatedCoverCard(_ article: LibraryArticleItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            libraryCover(path: article.thumbnail ?? article.image, height: 150, width: 120)
            Text(localizedValue(article.title) ?? NSLocalizedString("library_article_default", comment: ""))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)
                .lineLimit(2)
                .frame(width: 120, alignment: .leading)
            Text(authorLine(name: article.author_name, title: article.author_title))
                .font(.system(size: 11))
                .foregroundColor(SanadTheme.placeholder)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)
        }
    }

    @ViewBuilder
    private var tagFilter: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    tagChip(label: NSLocalizedString("library_all_tags", comment: ""), value: nil)
                    ForEach(tags, id: \.self) { tag in
                        tagChip(label: tag, value: tag)
                    }
                }
            }
        }
    }

    private func tagChip(label: String, value: String?) -> some View {
        let selected = selectedTag == value || (selectedTag == nil && value == nil)
        return Button(label) {
            selectedTag = value
            Task { await load() }
        }
        .font(.system(size: 13, weight: .semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(selected ? SanadTheme.primary : SanadTheme.card))
        .foregroundColor(selected ? SanadTheme.onPrimary : SanadTheme.onBg)
    }

    @ViewBuilder
    private var errorView: some View {
        if let err = error {
            SanadInlineBanner(err, style: .error)
        }
    }

    @ViewBuilder
    private var publishButton: some View {
        if canPublish {
            Button {
                showComposer = true
            } label: {
                HStack {
                    SanadIcon.addSession.image
                    Text("library_add_article")
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(SanadTheme.primary))
                .foregroundColor(SanadTheme.onPrimary)
            }
        }
    }

    @ViewBuilder
    private var loadingView: some View {
        if loading {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if categories.isEmpty && !loading {
            SanadEmptyState(message: "library_empty")
        }
    }

    private var categoriesList: some View {
        VStack(alignment: .trailing, spacing: 16) {
            ForEach(categories) { category in
                if let title = localizedValue(category.title), !title.isEmpty {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(SanadTheme.onBg)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                ForEach(category.articles ?? []) { article in
                    articleLink(article)
                }
            }
        }
    }

    private func articleCard(_ article: LibraryArticleItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            libraryCover(path: article.thumbnail ?? article.image, height: 160, width: nil)
            VStack(alignment: .leading, spacing: 6) {
                Text(localizedValue(article.title) ?? NSLocalizedString("library_article_default", comment: ""))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(SanadTheme.onBg)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                Text(authorLine(name: article.author_name, title: article.author_title))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
                    .lineLimit(1)

                if let meta = article.duration ?? (article.type == "video" ? NSLocalizedString("library_type_video", comment: "") : article.type), !meta.isEmpty {
                    Text(meta)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(SanadTheme.primary)
                }
            }
            .padding(14)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SanadTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(SanadTheme.fieldStroke.opacity(0.6), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func libraryCover(path: String?, height: CGFloat, width: CGFloat? = nil) -> some View {
        let url = AppConfig.storageURL(for: path) ?? (path.flatMap { URL(string: $0) })
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SanadTheme.primary.opacity(0.10))
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        SanadIcon.library.image
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(SanadTheme.primary)
                    default:
                        ProgressView()
                    }
                }
            } else {
                SanadIcon.library.image
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(SanadTheme.primary)
            }
        }
        .frame(width: width, height: height)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: width == nil ? 0 : 14, style: .continuous))
    }

    private func articleLink(_ article: LibraryArticleItem) -> some View {
        NavigationLink {
            LibraryDetailView(articleId: article.id)
        } label: {
            articleCard(article)
        }
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        do {
            async let listTask = service.listLibrary(token: token, tag: selectedTag)
            async let tipTask = service.dailyTip(token: token)
            async let tagsTask = service.listTags(token: token)
            async let curatedTask = service.curatedSyriaEurope(token: token)
            let res = try await listTask
            let tip = try? await tipTask
            let tagList = (try? await tagsTask) ?? tags
            let curated = (try? await curatedTask) ?? []
            await MainActor.run {
                categories = res
                dailyTip = tip
                curatedArticles = curated
                if tags.isEmpty { tags = tagList }
                error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("library_load_failed", comment: "") }
        }
        loading = false
    }

    private var canPublish: Bool {
        guard let role = authVM.currentUser?.role else { return false }
        return role == "admin" || role == "specialist" || role == "organization"
    }

    private var composerSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("library_compose_title")) {
                    TextField("library_compose_title_placeholder", text: $newTitle)
                }
                Section(header: Text("library_compose_body")) {
                    TextEditor(text: $newBody)
                        .frame(minHeight: 160)
                }
                Section(header: Text("library_compose_status")) {
                    Toggle("library_compose_publish_now", isOn: $publishNow)
                }
            }
            .navigationTitle("library_compose_nav_title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_cancel") { showComposer = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common_save") {
                        Task { await createArticle() }
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty || newBody.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func createArticle() async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await service.createArticle(
                title: newTitle,
                body: newBody,
                publish: publishNow,
                categoryId: categories.first?.id,
                token: token
            )
            await MainActor.run {
                newTitle = ""
                newBody = ""
                publishNow = true
                showComposer = false
            }
            await load()
        } catch {
            await MainActor.run { self.error = NSLocalizedString("library_save_failed", comment: "") }
        }
    }

}

#Preview {
    LibraryView()
        .environmentObject(AuthViewModel())
}

struct LibraryDetailView: View {
    let articleId: Int

    @State private var article: LibraryArticleDetail?
    @State private var loading = false
    @State private var error: String?
    @State private var isFavorite = false
    @State private var favoriteBusy = false
    @State private var videoPlayer: AVPlayer?
    @State private var boundVideoURL: String?

    private let service = LibraryService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let err = error {
                    SanadInlineBanner(err, style: .error)
                }

                if loading {
                    ProgressView().frame(maxWidth: .infinity)
                }

                if let article = article {
                    libraryDetailCover(path: article.image ?? article.thumbnail)

                    Text(localizedValue(article.title) ?? NSLocalizedString("library_article_default", comment: ""))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(SanadTheme.onBg)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(authorLine(name: article.author_name, title: article.author_title))
                        .font(.system(size: 13))
                        .foregroundColor(SanadTheme.placeholder)

                    if let meta = article.duration ?? (article.type == "video" ? NSLocalizedString("library_type_video", comment: "") : article.type), !meta.isEmpty {
                        Text(meta)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(SanadTheme.primary)
                    }

                    if let player = videoPlayer {
                        VideoPlayer(player: player)
                            .frame(height: 220)
                            .cornerRadius(14)
                    }

                    if let body = localizedValue(article.body) {
                        Text(body)
                            .font(.system(size: 16))
                            .foregroundColor(SanadTheme.onBg)
                            .lineSpacing(5)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(20)
        }
        .background(SanadAtmosphereBackground())
        .navigationTitle("library_detail_title")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await toggleFavorite() }
                } label: {
                    SanadIcon.star.image
                        .foregroundColor(isFavorite ? SanadTheme.primary : SanadTheme.placeholder)
                        .opacity(isFavorite ? 1 : 0.7)
                }
                .disabled(favoriteBusy)
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .onDisappear {
            videoPlayer?.pause()
        }
    }

    @ViewBuilder
    private func libraryDetailCover(path: String?) -> some View {
        let url = AppConfig.storageURL(for: path) ?? (path.flatMap { URL(string: $0) })
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SanadTheme.primary.opacity(0.08))
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        SanadIcon.library.image
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(SanadTheme.primary)
                    default:
                        ProgressView()
                    }
                }
            } else {
                SanadIcon.library.image
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(SanadTheme.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func bindVideo(urlString: String?) {
        guard let urlString = urlString, !urlString.isEmpty, let url = URL(string: urlString) else {
            videoPlayer?.pause()
            videoPlayer = nil
            boundVideoURL = nil
            return
        }
        if boundVideoURL == urlString, videoPlayer != nil {
            return
        }
        boundVideoURL = urlString
        let player = AVPlayer(url: url)
        videoPlayer = player
        player.play()
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        do {
            let res = try await service.getArticle(id: articleId, token: token)
            await MainActor.run {
                article = res
                isFavorite = res.favorited == true
                bindVideo(urlString: res.video_url)
                error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("library_detail_load_failed", comment: "") }
        }
        loading = false
    }

    private func toggleFavorite() async {
        guard let token = KeychainHelper.getToken() else { return }
        favoriteBusy = true
        defer { favoriteBusy = false }
        do {
            let favorited: Bool
            if isFavorite {
                favorited = try await service.unfavorite(id: articleId, token: token)
            } else {
                favorited = try await service.favorite(id: articleId, token: token)
            }
            await MainActor.run { isFavorite = favorited }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("library_favorite_failed", comment: "") }
        }
    }
}

fileprivate func localizedValue(_ map: [String: String]?) -> String? {
    guard let map = map else { return nil }
    let lang = AppLanguage.currentCode
    if let value = map[lang] { return value }
    if let value = map["ar"] { return value }
    if let value = map["en"] { return value }
    return map.values.first
}

fileprivate func authorLine(name: String?, title: String?) -> String {
    let safeName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let safeTitle = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if safeName.isEmpty { return NSLocalizedString("library_author_unknown", comment: "") }
    if safeTitle.isEmpty { return String(format: NSLocalizedString("library_author_name", comment: ""), safeName) }
    return String(format: NSLocalizedString("library_author_name_title", comment: ""), safeName, safeTitle)
}
