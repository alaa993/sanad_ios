import SwiftUI
import Combine

/// نقطة الدخول للمجتمع — قائمة ثم خلاصة (مثل Android).
/// Use only inside an existing `NavigationStack` (e.g. profile tab). For typed dashboard routes, push `CommunityListView` via `NestedNavigationHost` instead.
struct CommunityView: View {
    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack { CommunityListView() }
            } else {
                NavigationView { CommunityListView() }
            }
        }
    }
}

struct CommunityFeedView: View {
    @EnvironmentObject var authVM: AuthViewModel
    let communityId: Int
    let communityTitle: String

    private var policy: CommunityRolePolicy {
        CommunityRolePolicy(rawRole: authVM.userRole)
    }

    @State private var posts: [CommunityPost] = []
    @State private var loading = false
    @State private var error: String?
    @State private var composerText = ""
    @State private var commentText = ""
    @State private var threadPost: CommunityPost?
    @State private var showThreadSheet = false
    @State private var imagePickerPresented = false
    @State private var selectedImageData: Data?
    @State private var uploadedMediaUrl: String?
    @State private var uploadLoading = false
    @State private var uploadError = false
    @State private var filter: String = "all"
    @State private var feedKind: String = "discussion"
    @State private var community: CommunitySummary?
    @State private var membershipLoading = false
    @State private var communityCancellable: AnyCancellable?
    @State private var answerPost: CommunityPost?
    @State private var answerText = ""
    @State private var showAnswerSheet = false
    @State private var didAttemptSpecialistAutoJoin = false

    private let service = CommunityService()
    private let mediaService = MediaUploadService()

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    SanadHeroHeader(
                        title: LocalizedStringKey(communityTitle.isEmpty ? NSLocalizedString("community_feed_title", comment: "") : communityTitle),
                        subtitle: "community_feed_meta"
                    )

                    VStack(alignment: .leading, spacing: 16) {
                        if let community = community {
                            membershipButton
                            if let subtitle = communitySubtitleOptional(community) {
                                Text(subtitle)
                                    .font(.system(size: 12))
                                    .foregroundColor(SanadTheme.placeholder)
                            }
                        }

                        if let err = error {
                            Text(err)
                                .foregroundColor(SanadTheme.error)
                                .font(.system(size: 13))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if filteredPosts.isEmpty && !loading {
                            SanadEmptyState(message: "community_empty_feed")
                        } else {
                            ForEach(filteredPosts) { post in
                                postCard(post)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 120)
                }
            }
            .background(SanadAtmosphereBackground())

            postBar
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .navigationBarHidden(true)
        .task { await refreshData() }
        .refreshable { await refreshData() }
        .onAppear {
            authVM.reconnectRealtime()
            subscribeCommunityEvents()
        }
        .onDisappear { communityCancellable?.cancel() }
        .sheet(isPresented: $showThreadSheet) {
            if let post = threadPostResolved {
                PostThreadSheet(
                    post: post,
                    isQa: isQaCommunity,
                    canAnswer: policy.canAnswerQA(),
                    canAccept: canAcceptAnswer(for: post),
                    commentText: $commentText,
                    onLike: { Task { await toggleLike(post) } },
                    onComment: { Task { await submitComment() } },
                    onAnswer: {
                        answerPost = post
                        showAnswerSheet = true
                    },
                    onAccept: { answer in
                        Task { await acceptAnswer(question: post, answer: answer) }
                    },
                    onClose: {
                        showThreadSheet = false
                        commentText = ""
                        threadPost = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showAnswerSheet) {
            answerSheet
        }
        .sheet(isPresented: $imagePickerPresented) {
            imagePicker
        }
    }

    private var threadPostResolved: CommunityPost? {
        guard let id = threadPost?.id else { return threadPost }
        return posts.first(where: { $0.id == id }) ?? threadPost
    }

    private func communitySubtitleOptional(_ community: CommunitySummary) -> String? {
        communitySubtitle(community)
    }

    @ViewBuilder
    private var membershipButton: some View {
        if policy.canJoinFreely, let community = community {
            Button {
                Task { await toggleMembership() }
            } label: {
                HStack(spacing: 6) {
                    if membershipLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    Text(community.joined == true ? NSLocalizedString("community_leave", comment: "") : NSLocalizedString("community_join", comment: ""))
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                .foregroundColor(SanadTheme.primary)
            }
            .disabled(membershipLoading)
        }
    }

    private var isQaCommunity: Bool {
        (community?.kind ?? feedKind) == "qa"
    }

    private var postBar: some View {
        let joined = community?.joined == true
        let canPost = policy.canPost(in: community)
        let hintKey = canPost
            ? (isQaCommunity ? "community_qa_question_hint" : "community_post_hint")
            : "community_post_hint_locked"
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                TextField(NSLocalizedString(hintKey, comment: ""), text: $composerText)
                    .textInputAutocapitalization(.sentences)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 8)
                    .background(Color.clear)
                    .disabled(!canPost)
                if canPost {
                    Button(action: { imagePickerPresented = true }) {
                        SanadIcon.attach.image
                            .foregroundColor(SanadTheme.primary)
                    }
                }
                Button(action: { Task { await submit() } }) {
                    SanadIcon.send.image
                        .foregroundColor(SanadTheme.primary)
                }
                .disabled(!canPost || (composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && uploadedMediaUrl == nil))
            }
            if uploadLoading {
                Text("community_attachment_uploading")
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
            } else if uploadError {
                Text("community_attachment_error")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            } else if uploadedMediaUrl != nil {
                Text("community_attachment_ready")
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.primary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(SanadTheme.card))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(SanadTheme.fieldStroke, lineWidth: 1)
        )
        .shadow(color: SanadTheme.subtleShadow, radius: 6, y: 4)
    }

    private func postCard(_ post: CommunityPost) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(SanadTheme.surfaceAlt)
                    .frame(width: 36, height: 36)
                    .overlay(
                        SanadIcon.profile.image
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SanadTheme.primary)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author.name ?? "—")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SanadTheme.onBg)
                    Text(post.type?.label ?? NSLocalizedString("community_post_type_personal", comment: ""))
                        .font(.system(size: 11))
                        .foregroundColor(SanadTheme.placeholder)
                }
                Spacer()
            }
            Text(post.body)
                .font(.system(size: 15))
                .foregroundColor(SanadTheme.onBg)
                .fixedSize(horizontal: false, vertical: true)
            if let media = post.media_url, let url = AppConfig.storageURL(for: media) ?? URL(string: media) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(SanadTheme.surfaceAlt)
                            .overlay(SanadIcon.image.image.foregroundColor(SanadTheme.placeholder))
                    default:
                        RoundedRectangle(cornerRadius: 12).fill(SanadTheme.surfaceAlt)
                            .overlay(ProgressView())
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()
                .cornerRadius(12)
            }
            HStack(spacing: 12) {
                Button(post.liked == true ? NSLocalizedString("community_unlike", comment: "") : NSLocalizedString("community_like", comment: "")) {
                    Task { await toggleLike(post) }
                }
                .font(.system(size: 12, weight: .semibold))
                Button("community_comment") {
                    threadPost = post
                    showThreadSheet = true
                }
                .font(.system(size: 12, weight: .semibold))
                if isQaCommunity && isQuestionPost(post) && policy.canAnswerQA() {
                    Button("community_qa_answer") {
                        answerPost = post
                        showAnswerSheet = true
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                if let count = post.likes_count {
                    Text(String(format: NSLocalizedString("community_likes_count", comment: ""), count))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
                if let commentsCount = post.comments?.count, commentsCount > 0 {
                    Text(String(format: NSLocalizedString("community_comments_count", comment: ""), commentsCount))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
            }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            threadPost = post
            showThreadSheet = true
        }
    }

    private var filteredPosts: [CommunityPost] {
        let base: [CommunityPost]
        if filter == "all" {
            base = posts
        } else {
            base = posts.filter { $0.type == filter }
        }
        return base.sorted { lhs, rhs in
            (lhs.created_at ?? "") > (rhs.created_at ?? "")
        }
    }

    private func loadCommunities() async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            let list = try await service.list(token: token)
            await MainActor.run {
                self.community = list.first(where: { $0.id == communityId }) ?? list.first
            }
            await autoJoinIfSpecialist()
        } catch _ {
            await MainActor.run { self.error = NSLocalizedString("community_load_failed", comment: "") }
        }
    }

    /// مطابق لـ `CommunityFeedFragment.renderCommunity` — انضمام تلقائي للأخصائي.
    private func autoJoinIfSpecialist() async {
        let role = (authVM.userRole ?? "").lowercased()
        guard role == "specialist" else { return }
        guard !didAttemptSpecialistAutoJoin else { return }
        guard let community = community, community.joined != true else { return }
        didAttemptSpecialistAutoJoin = true
        await toggleMembership()
    }

    private func loadFeed() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        let communityId = self.communityId
        loading = true
        do {
            let payload = try await service.feed(communityId: communityId, token: token)
            await MainActor.run {
                posts = payload.posts.sorted { ($0.created_at ?? "") > ($1.created_at ?? "") }
                feedKind = payload.kind ?? community?.kind ?? "discussion"
                error = nil
            }
        } catch let loadError {
            let message = communityErrorMessage(loadError, prefix: "community_detail_failed")
            await MainActor.run { self.error = message }
        }
        loading = false
    }

    private func refreshData() async {
        await loadCommunities()
        await loadFeed()
    }

    private func toggleMembership() async {
        guard let token = KeychainHelper.getToken() else { return }
        guard var community = self.community else { return }
        let communityId = community.id
        membershipLoading = true
        defer { membershipLoading = false }
        do {
            let response = try await (community.joined == true
                                       ? service.leave(communityId: communityId, token: token)
                                       : service.join(communityId: communityId, token: token))
            await MainActor.run {
                community.joined = response.joined
                community.members_count = response.members_count
                self.community = community
                error = nil
            }
            await loadFeed()
        } catch _ {
            await MainActor.run { self.error = NSLocalizedString("community_membership_update_failed", comment: "") }
        }
    }

    private func toggleLike(_ post: CommunityPost) async {
        guard let token = KeychainHelper.getToken() else { return }
        let communityId = self.communityId
        do {
            try await service.like(communityId: communityId, postId: post.id, token: token)
            await loadFeed()
        } catch _ {
            await MainActor.run { self.error = NSLocalizedString("community_like_update_failed", comment: "") }
        }
    }

    private func submit() async {
        guard let token = KeychainHelper.getToken() else { return }
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasMedia = uploadedMediaUrl != nil
        guard !text.isEmpty || hasMedia else { return }
        let communityId = self.communityId
        do {
            let type = policy.defaultPostType
            try await service.post(communityId: communityId,
                                   body: text,
                                   type: type,
                                   mediaUrl: uploadedMediaUrl,
                                   postKind: isQaCommunity ? "question" : nil,
                                   questionId: nil,
                                   token: token)
            composerText = ""
            uploadedMediaUrl = nil
            await loadFeed()
        } catch _ {
            await MainActor.run { self.error = NSLocalizedString("community_post_publish_failed", comment: "") }
        }
    }

    private var answerSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("community_qa_answer")) {
                    TextField("community_qa_answer_hint", text: $answerText)
                }
            }
            .navigationTitle("community_qa_answer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_cancel") {
                        showAnswerSheet = false
                        answerText = ""
                        answerPost = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common_send") {
                        Task { await submitAnswer() }
                    }
                    .disabled(answerText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func isQuestionPost(_ post: CommunityPost) -> Bool {
        let kind = post.post_kind ?? "post"
        return kind == "question" || kind == "post"
    }

    private func canAcceptAnswer(for question: CommunityPost) -> Bool {
        let role = (authVM.userRole ?? "").lowercased()
        if role == "admin" || role == "organization" { return true }
        return question.author.id == authVM.currentUser?.id
    }

    private func submitAnswer() async {
        guard let token = KeychainHelper.getToken(),
              let question = answerPost,
              !answerText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let communityId = self.communityId
        do {
            try await service.post(communityId: communityId,
                                   body: answerText,
                                   type: "awareness",
                                   postKind: "answer",
                                   questionId: question.id,
                                   token: token)
            await MainActor.run {
                answerText = ""
                showAnswerSheet = false
                answerPost = nil
            }
            await loadFeed()
        } catch _ {
            await MainActor.run { self.error = NSLocalizedString("community_post_publish_failed", comment: "") }
        }
    }

    private func acceptAnswer(question: CommunityPost, answer: CommunityPost) async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await service.acceptAnswer(communityId: communityId, questionId: question.id, answerId: answer.id, token: token)
            await loadFeed()
        } catch _ {
            await MainActor.run { self.error = NSLocalizedString("community_qa_accept_failed", comment: "") }
        }
    }

    private func submitComment() async {
        guard let token = KeychainHelper.getToken(),
              let post = threadPost,
              !commentText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let communityId = self.communityId
        do {
            try await service.comment(communityId: communityId, postId: post.id, text: commentText, token: token)
            await MainActor.run {
                commentText = ""
            }
            await loadFeed()
        } catch _ {
            await MainActor.run { self.error = NSLocalizedString("community_comment_failed", comment: "") }
        }
    }

    private func uploadMedia() async {
        guard let data = selectedImageData, let token = KeychainHelper.getToken() else { return }
        uploadLoading = true
        uploadError = false
        do {
            let url = try await mediaService.uploadImage(data, filename: "community.jpg", token: token)
            await MainActor.run { self.uploadedMediaUrl = url }
        } catch _ {
            await MainActor.run {
                self.uploadError = true
                self.error = NSLocalizedString("community_attachment_error", comment: "")
            }
        }
        uploadLoading = false
    }

    private var imagePicker: some View {
        ImagePicker(data: $selectedImageData, onDismiss: {
            if selectedImageData != nil {
                Task { await uploadMedia() }
            }
        })
    }

    private func subscribeCommunityEvents() {
        communityCancellable = RealtimeSocket.shared.events
            .receive(on: DispatchQueue.main)
            .sink { event in
                switch event {
                case .communityPost(let id, let post):
                    guard id == communityId else { return }
                    guard !posts.contains(where: { $0.id == post.id }) else { return }
                    posts.insert(post, at: 0)
                case .communityComment(let id, let postId, let comment):
                    guard id == communityId else { return }
                    if let index = posts.firstIndex(where: { $0.id == postId }) {
                        let current = posts[index]
                        var list = current.comments ?? []
                        if !list.contains(where: { $0.id == comment.id }) {
                            list.insert(comment, at: 0)
                        }
                        list.sort { ($0.created_at ?? "") > ($1.created_at ?? "") }
                        let updated = CommunityPost(id: current.id,
                                                    body: current.body,
                                                    media_url: current.media_url,
                                                    type: current.type,
                                                    post_kind: current.post_kind,
                                                    question_id: current.question_id,
                                                    accepted_at: current.accepted_at,
                                                    author: current.author,
                                                    created_at: current.created_at,
                                                    likes_count: current.likes_count,
                                                    liked: current.liked,
                                                    comments: list,
                                                    answers: current.answers,
                                                    answers_count: current.answers_count,
                                                    accepted_answer_id: current.accepted_answer_id)
                        posts[index] = updated
                    }
                case .communityLike(let id, let postId, let likesCount, let liked):
                    guard id == communityId else { return }
                    if let index = posts.firstIndex(where: { $0.id == postId }) {
                        let current = posts[index]
                        let updated = CommunityPost(id: current.id,
                                                    body: current.body,
                                                    media_url: current.media_url,
                                                    type: current.type,
                                                    post_kind: current.post_kind,
                                                    question_id: current.question_id,
                                                    accepted_at: current.accepted_at,
                                                    author: current.author,
                                                    created_at: current.created_at,
                                                    likes_count: likesCount ?? current.likes_count,
                                                    liked: liked ?? current.liked,
                                                    comments: current.comments,
                                                    answers: current.answers,
                                                    answers_count: current.answers_count,
                                                    accepted_answer_id: current.accepted_answer_id)
                        posts[index] = updated
                    }
                default:
                    break
                }
            }
    }
}

private extension String {
    var label: String {
        switch self {
        case "personal": return NSLocalizedString("community_post_type_personal", comment: "")
        case "awareness": return NSLocalizedString("community_post_type_awareness", comment: "")
        case "official": return NSLocalizedString("community_post_type_official", comment: "")
        default: return self
        }
    }
    var color: Color {
        switch self {
        case "personal": return SanadTheme.primary
        case "awareness": return .orange
        case "official": return .red
        default: return SanadTheme.primary
        }
    }
}

private func communitySubtitle(_ community: CommunitySummary) -> String {
    let count = community.members_count ?? 0
    let visibility = community.visibility ?? NSLocalizedString("community_visibility_public", comment: "")
    return String(format: NSLocalizedString("community_members_visibility", comment: ""), count, visibility)
}

private func communityErrorMessage(_ error: Error, prefix: String) -> String {
    if let serviceError = error as? CommunityServiceError {
        switch serviceError {
        case .unauthorized:
            return NSLocalizedString(prefix + "_auth", comment: "")
        case .forbidden:
            return NSLocalizedString(prefix + "_forbidden", comment: "")
        case .invalidStatus(let code):
            return String(format: NSLocalizedString(prefix + "_status", comment: ""), code)
        case .decoding:
            return NSLocalizedString(prefix + "_format", comment: "")
        }
    }
    if error is URLError {
        return NSLocalizedString(prefix + "_network", comment: "")
    }
    if error is DecodingError {
        return NSLocalizedString(prefix + "_format", comment: "")
    }
    return NSLocalizedString(prefix + "_unknown", comment: "")
}

#Preview {
    CommunityView().environmentObject(AuthViewModel())
}

private struct PostThreadSheet: View {
    let post: CommunityPost
    let isQa: Bool
    let canAnswer: Bool
    let canAccept: Bool
    @Binding var commentText: String
    let onLike: () -> Void
    let onComment: () -> Void
    let onAnswer: () -> Void
    let onAccept: (CommunityPost) -> Void
    let onClose: () -> Void

    private var comments: [CommunityPost.Comment] {
        (post.comments ?? []).sorted { ($0.created_at ?? "") > ($1.created_at ?? "") }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(SanadTheme.surfaceAlt)
                            .frame(width: 36, height: 36)
                            .overlay(SanadIcon.profile.image.foregroundColor(SanadTheme.primary))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.author.name ?? "—")
                                .font(.system(size: 14, weight: .semibold))
                            Text(post.type?.label ?? NSLocalizedString("community_post_type_personal", comment: ""))
                                .font(.system(size: 11))
                                .foregroundColor(SanadTheme.placeholder)
                        }
                        Spacer()
                    }

                    Text(post.body)
                        .font(.system(size: 16))
                        .foregroundColor(SanadTheme.onBg)

                    if let media = post.media_url, let url = AppConfig.storageURL(for: media) ?? URL(string: media) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                RoundedRectangle(cornerRadius: 12).fill(SanadTheme.surfaceAlt)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipped()
                        .cornerRadius(12)
                    }

                    HStack(spacing: 12) {
                        Button(post.liked == true ? "community_unlike" : "community_like", action: onLike)
                            .font(.system(size: 13, weight: .semibold))
                        if isQa && canAnswer {
                            Button("community_qa_answer", action: onAnswer)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        if let count = post.likes_count {
                            Text(String(format: NSLocalizedString("community_likes_count", comment: ""), count))
                                .font(.system(size: 12))
                                .foregroundColor(SanadTheme.placeholder)
                        }
                    }

                    if isQa, let answers = post.answers, !answers.isEmpty {
                        Text("community_qa_answers_label")
                            .font(.system(size: 13, weight: .semibold))
                        ForEach(answers) { answer in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(answer.body)
                                    .font(.system(size: 14))
                                HStack {
                                    Text(answer.author.name ?? "—")
                                        .font(.system(size: 11))
                                        .foregroundColor(SanadTheme.placeholder)
                                    Spacer()
                                    if answer.accepted_at != nil {
                                        Text("community_qa_accepted")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(SanadTheme.primary)
                                    } else if canAccept {
                                        Button("community_qa_accept") { onAccept(answer) }
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                }
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(SanadTheme.surfaceAlt))
                        }
                    }

                    Divider()

                    Text(String(format: NSLocalizedString("community_comments_count", comment: ""), comments.count))
                        .font(.system(size: 14, weight: .semibold))

                    if comments.isEmpty {
                        Text("community_comments_empty")
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.placeholder)
                    } else {
                        ForEach(comments) { comment in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(comment.author.name ?? "—")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(SanadTheme.primary)
                                Text(comment.body)
                                    .font(.system(size: 14))
                                    .foregroundColor(SanadTheme.onBg)
                                if let created = comment.created_at {
                                    Text(created)
                                        .font(.system(size: 11))
                                        .foregroundColor(SanadTheme.placeholder)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("community_comment_hint", text: $commentText)
                            .textFieldStyle(.roundedBorder)
                        Button("common_send", action: onComment)
                            .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.top, 8)
                }
                .padding(16)
            }
            .background(SanadAtmosphereBackground())
            .navigationTitle("community_comment_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_close", action: onClose)
                }
            }
        }
    }
}

