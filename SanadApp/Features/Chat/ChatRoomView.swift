import SwiftUI
import UIKit
import Combine

/// Chat room: REST history + RealtimeSocket appends; also polls messages every 4s while the view is alive.
struct ChatRoomView: View {
    @EnvironmentObject var authVM: AuthViewModel
    let chatId: Int
    let chatTitle: String?
    let sessionId: Int?
    let sessionEndsAt: String?
    let canExtend: Bool

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var loading = false
    @State private var error: String?
    @State private var isSending = false
    @State private var inputLocked = false
    @State private var remainingText: String?
    @State private var lastCreatedAt: String?
    @State private var showImagePicker = false
    @State private var pickedImageData: Data?
    @State private var realtimeCancellable: AnyCancellable?

    private let service = ChatService()
    private let sessionsService = SessionsService()
    /// Fallback while socket is flaky; prefer socket when connected.
    private let poller = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    private let countdown = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            SanadHeroHeader(
                title: LocalizedStringKey(chatTitle ?? NSLocalizedString("chat_default_title", comment: "")),
                subtitle: "chat_input_placeholder"
            )

            if let remainingText = remainingText {
                HStack {
                    Text(remainingText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(SanadTheme.onPrimary)
                    Spacer()
                    if canExtend, let sessionId = sessionId {
                        Button("chat_extend") {
                            Task { await extendSession(sessionId) }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(SanadTheme.onPrimary.opacity(0.2)))
                        .foregroundColor(SanadTheme.onPrimary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(SanadTheme.primary)
            }
            if let err = error {
                SanadInlineBanner(err, style: .error)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            if messages.isEmpty && !loading {
                SanadEmptyState(message: "chat_empty")
                    .padding(.vertical, 20)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { msg in
                            messageRow(msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 10) {
                Button {
                    showImagePicker = true
                } label: {
                    SanadIcon.attach.image
                        .foregroundColor(SanadTheme.primary)
                        .frame(width: 32, height: 32)
                }
                .disabled(inputLocked)

                inputField

                Button {
                    Task { await sendText() }
                } label: {
                    SanadIcon.send.image
                        .font(.system(size: 22))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || inputLocked ? SanadTheme.placeholder : SanadTheme.primary)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending || inputLocked)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(SanadTheme.surface)
                    .shadow(color: SanadTheme.subtleShadow, radius: 8, y: -2)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(Color(hex: "#F5F7FC").ignoresSafeArea())
        .navigationBarHidden(true)
            .task { await initialLoad() }
            .refreshable { await initialLoad() }
        .onReceive(poller) { _ in
            Task { await pollUpdates() }
        }
        .onReceive(countdown) { _ in
            updateCountdown()
        }
        .onAppear {
            authVM.reconnectRealtime()
            RealtimeSocket.shared.joinChat(chatId: chatId)
            subscribeRealtimeMessages()
        }
        .onDisappear {
            RealtimeSocket.shared.leaveChat(chatId: chatId)
            realtimeCancellable?.cancel()
        }
        .onAppear { updateCountdown() }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(data: $pickedImageData)
        }
        .onChange(of: pickedImageData) {
            guard let data = pickedImageData else { return }
            Task { await sendImage(data) }
        }
    }

    private func initialLoad() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        do {
            let res = try await service.messages(chatId: chatId, since: nil, token: token)
            await MainActor.run {
                self.messages = res
                self.lastCreatedAt = res.last?.created_at
                self.error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("chat_messages_load_failed", comment: "") }
        }
        loading = false
    }

    private func pollUpdates() async {
        guard !loading, error == nil, let token = KeychainHelper.getToken() else { return }
        do {
            let res = try await service.messages(chatId: chatId, since: lastCreatedAt, token: token)
            guard !res.isEmpty else { return }
            await MainActor.run {
                self.messages.append(contentsOf: res)
                self.lastCreatedAt = res.last?.created_at ?? lastCreatedAt
            }
        } catch { }
    }

    private func subscribeRealtimeMessages() {
        let currentUserId = authVM.currentUser?.id
        realtimeCancellable = RealtimeSocket.shared.events
            .compactMap { event -> ChatMessage? in
                if case .chatMessage(let id, let message) = event, id == chatId {
                    if let currentUserId, let senderId = message.sender?.id, senderId == currentUserId {
                        return nil
                    }
                    return message
                }
                return nil
            }
            .receive(on: DispatchQueue.main)
            .sink { msg in
                guard !messages.contains(where: { $0.id == msg.id }) else { return }
                messages.append(msg)
                lastCreatedAt = msg.created_at ?? lastCreatedAt
            }
    }

    private func sendText() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return }
        await sendMessage(type: "text", body: text)
        await MainActor.run { inputText = "" }
    }

    @ViewBuilder
    private var inputField: some View {
        if #available(iOS 16.0, *) {
            TextField("chat_input_placeholder", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .disabled(inputLocked)
        } else {
            ZStack(alignment: .topLeading) {
                if inputText.isEmpty {
                    Text("chat_input_placeholder")
                        .foregroundColor(SanadTheme.placeholder)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .font(.system(size: 15))
                }
                TextEditor(text: $inputText)
                    .frame(minHeight: 36, maxHeight: 110)
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(SanadTheme.fieldStroke))
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(.systemBackground)))
                    .disabled(inputLocked)
            }
        }
    }

    private func sendImage(_ data: Data) async {
        let base64 = data.base64EncodedString()
        let body = "data:image/jpeg;base64," + base64
        await sendMessage(type: "image", body: body)
        await MainActor.run { pickedImageData = nil }
    }

    private func sendMessage(type: String, body: String) async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        isSending = true
        do {
            let msg = try await service.send(chatId: chatId, type: type, body: body, token: token)
            await MainActor.run {
                self.messages.append(msg)
                self.lastCreatedAt = msg.created_at ?? lastCreatedAt
                self.error = nil
            }
            RealtimeSocket.shared.emitChatMessage(chatId: chatId, content: body, type: type)
        } catch let err as ChatServiceError {
            await MainActor.run { handleSendError(err) }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("chat_send_failed", comment: "") }
        }
        isSending = false
    }

    private func handleSendError(_ err: ChatServiceError) {
        if case .server(let message) = err {
            if message == "session_time_expired" {
                error = NSLocalizedString("chat_session_expired", comment: "")
                inputLocked = true
                return
            }
            if message == "group_session_ended" {
                error = NSLocalizedString("chat_group_session_ended", comment: "")
                inputLocked = true
                return
            }
            error = message
            return
        }
        error = err.errorDescription
    }

    private func updateCountdown() {
        guard let endsAt = sessionEndsAt, let endDate = parseIsoDate(endsAt) else {
            remainingText = nil
            return
        }
        let remaining = Int(endDate.timeIntervalSince(Date()))
        if remaining <= 0 {
            remainingText = NSLocalizedString("chat_session_expired", comment: "")
            inputLocked = true
            return
        }
        let minutes = remaining / 60
        let seconds = remaining % 60
        remainingText = String(format: NSLocalizedString("chat_time_remaining", comment: ""), String(format: "%02d:%02d", minutes, seconds))
        inputLocked = false
    }

    private func extendSession(_ sessionId: Int) async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await sessionsService.extend(id: sessionId, minutes: 15, token: token)
        } catch {
            await MainActor.run {
                self.error = NSLocalizedString("chat_extend_failed", comment: "")
            }
        }
    }

    @ViewBuilder
    private func messageRow(_ msg: ChatMessage) -> some View {
        let myId = authVM.currentUser?.id
        let isMine = msg.sender?.id == myId
        HStack {
            if isMine { Spacer(minLength: 30) }
            VStack(alignment: .leading, spacing: 6) {
                Text(senderLabel(msg, isMine: isMine))
                    .font(SanadFont.caption(12))
                    .foregroundColor(SanadTheme.placeholder)

                if isImageMessage(msg) {
                    imageBody(msg)
                } else {
                    Text(msg.body ?? "")
                        .font(SanadFont.body(15))
                        .foregroundColor(isMine ? SanadTheme.onPrimary : SanadTheme.onBg)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(bubbleBackground(isMine: isMine))
                }

                Text(relativeTime(msg.created_at))
                    .font(SanadFont.caption(11))
                    .foregroundColor(SanadTheme.placeholder)
            }
            if !isMine { Spacer(minLength: 30) }
        }
    }

    private func senderLabel(_ msg: ChatMessage, isMine: Bool) -> String {
        if isMine { return NSLocalizedString("chat_me", comment: "") }
        let name = msg.sender?.name ?? NSLocalizedString("common_user", comment: "")
        if let role = msg.sender?.role, !role.isEmpty {
            return name + " • " + mapRole(role)
        }
        return name
    }

    private func bubbleBackground(isMine: Bool) -> some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: isMine ? 18 : 6,
            bottomTrailingRadius: isMine ? 6 : 18,
            topTrailingRadius: 18,
            style: .continuous
        )
        return shape
            .fill(isMine ? SanadTheme.primary : SanadTheme.surface)
            .overlay(shape.stroke(isMine ? Color.clear : SanadTheme.fieldStroke, lineWidth: 1))
    }

    private func isImageMessage(_ msg: ChatMessage) -> Bool {
        return msg.type?.lowercased().contains("image") == true
    }

    @ViewBuilder
    private func imageBody(_ msg: ChatMessage) -> some View {
        if let body = msg.body, let url = URL(string: body), body.lowercased().hasPrefix("http") {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                ProgressView()
            }
            .frame(maxWidth: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if let body = msg.body, let data = decodeBase64Image(body), let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            Text(msg.body ?? "")
                .font(.system(size: 14))
                .foregroundColor(SanadTheme.onBg)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14).fill(SanadTheme.card))
        }
    }

    private func decodeBase64Image(_ body: String) -> Data? {
        if let comma = body.firstIndex(of: ",") {
            let trimmed = String(body[body.index(after: comma)...])
            return Data(base64Encoded: trimmed)
        }
        return Data(base64Encoded: body)
    }

    private func relativeTime(_ iso: String?) -> String {
        guard let iso = iso, let date = parseIsoDate(iso) else { return "" }
        let diff = max(0, Int(Date().timeIntervalSince(date)))
        if diff < 60 { return NSLocalizedString("chat_time_now", comment: "") }
        let minutes = diff / 60
        if minutes < 60 { return String(format: NSLocalizedString("chat_time_minutes_ago", comment: ""), minutes) }
        let hours = minutes / 60
        if hours < 24 { return String(format: NSLocalizedString("chat_time_hours_ago", comment: ""), hours) }
        let days = hours / 24
        return String(format: NSLocalizedString("chat_time_days_ago", comment: ""), days)
    }

    private func parseIsoDate(_ iso: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) { return date }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: iso)
    }

    private func mapRole(_ role: String) -> String {
        switch role.lowercased() {
        case "specialist": return NSLocalizedString("role_specialist", comment: "")
        case "user": return NSLocalizedString("role_patient", comment: "")
        case "support": return NSLocalizedString("role_support", comment: "")
        default: return role
        }
    }
}

extension ChatRoomView {
    init(chatId: Int, chatTitle: String?, sessionId: Int? = nil, sessionEndsAt: String? = nil, canExtend: Bool = false) {
        self.chatId = chatId
        self.chatTitle = chatTitle
        self.sessionId = sessionId
        self.sessionEndsAt = sessionEndsAt
        self.canExtend = canExtend
    }
}

#Preview { ChatRoomView(chatId: 1, chatTitle: "Chat").environmentObject(AuthViewModel()) }
