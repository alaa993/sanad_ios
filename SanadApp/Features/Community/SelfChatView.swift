import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVKit

struct SelfChatMessage: Identifiable, Codable {
    enum Kind: String, Codable {
        case text
        case image
        case video
    }

    let id: UUID
    let journalId: Int?
    let kind: Kind
    let text: String?
    let fileName: String?
    let createdAt: Date
}

/// Private journal / self-chat UI backed by JournalService (not the community feed).
struct SelfChatView: View {
    @State private var messages: [SelfChatMessage] = []
    @State private var inputText = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var error: String?

    private let journalService = JournalService()

    var body: some View {
        VStack(spacing: 0) {
            SanadHeroHeader(title: "self_chat_title")

            if let err = error {
                SanadInlineBanner(err, style: .warning)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
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
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 3, matching: .any(of: [.images, .videos])) {
                    SanadIcon.attach.image
                        .foregroundColor(SanadTheme.primary)
                        .frame(width: 32, height: 32)
                }

                TextField("self_chat_hint", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button {
                    sendText()
                } label: {
                    SanadIcon.send.image
                        .font(.system(size: 22))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? SanadTheme.placeholder : SanadTheme.primary)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
            .background(SanadTheme.surface)
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationBarHidden(true)
        .dismissKeyboardOnTap()
        .task { await loadMessages() }
        .onChange(of: selectedItems) {
            Task { await handleSelectedItems(selectedItems) }
        }
    }

    private func loadMessages() async {
        if let token = KeychainHelper.getToken() {
            do {
                let entries = try await journalService.list(token: token)
                let mapped = entries.reversed().compactMap { entry -> SelfChatMessage? in
                    let trimmed = entry.entry.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return nil }
                    return SelfChatMessage(
                        id: UUID(),
                        journalId: entry.id,
                        kind: .text,
                        text: trimmed,
                        fileName: nil,
                        createdAt: parseJournalDate(entry.created_at)
                    )
                }
                if !mapped.isEmpty {
                    await MainActor.run {
                        messages = mapped
                        persistMessages()
                        error = nil
                    }
                    return
                }
            } catch let locked as JournalServiceError where locked == .locked {
                await MainActor.run {
                    self.error = NSLocalizedString("journal_locked_until_recovery", comment: "")
                }
            } catch {
                await MainActor.run {
                    self.error = NSLocalizedString("chat_load_failed", comment: "")
                }
            }
        }

        do {
            let local = try readMessages()
            await MainActor.run { messages = local }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("chat_load_failed", comment: "") }
        }
    }

    private func sendText() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let localId = UUID()
        let msg = SelfChatMessage(id: localId, journalId: nil, kind: .text, text: trimmed, fileName: nil, createdAt: Date())
        messages.append(msg)
        inputText = ""
        persistMessages()

        guard let token = KeychainHelper.getToken() else { return }
        Task {
            do {
                let created = try await journalService.create(entry: trimmed, token: token)
                await MainActor.run {
                    if let index = messages.firstIndex(where: { $0.id == localId }) {
                        let current = messages[index]
                        messages[index] = SelfChatMessage(
                            id: current.id,
                            journalId: created.id,
                            kind: current.kind,
                            text: current.text,
                            fileName: current.fileName,
                            createdAt: parseJournalDate(created.created_at)
                        )
                        persistMessages()
                    }
                    error = nil
                }
            } catch let locked as JournalServiceError where locked == .locked {
                await MainActor.run { self.error = NSLocalizedString("journal_locked_until_recovery", comment: "") }
            } catch {
                await MainActor.run { self.error = NSLocalizedString("chat_send_failed", comment: "") }
            }
        }
    }

    private func handleSelectedItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        for item in items {
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .image) }) {
                await handleImageItem(item)
            } else if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                await handleVideoItem(item)
            }
        }
        await MainActor.run { selectedItems = [] }
        persistMessages()
    }

    private func handleImageItem(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                let fileName = UUID().uuidString + "." + ext
                let url = try ensureMediaURL(fileName: fileName)
                try data.write(to: url, options: [.atomic])
                let msg = SelfChatMessage(id: UUID(), journalId: nil, kind: .image, text: nil, fileName: fileName, createdAt: Date())
                await MainActor.run { messages.append(msg) }
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("chat_send_failed", comment: "") }
        }
    }

    private func handleVideoItem(_ item: PhotosPickerItem) async {
        do {
            if let url = try await item.loadTransferable(type: URL.self) {
                let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
                let fileName = UUID().uuidString + "." + ext
                let dest = try ensureMediaURL(fileName: fileName)
                try copyItem(at: url, to: dest)
                let msg = SelfChatMessage(id: UUID(), journalId: nil, kind: .video, text: nil, fileName: fileName, createdAt: Date())
                await MainActor.run { messages.append(msg) }
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("chat_send_failed", comment: "") }
        }
    }

    private func messageRow(_ msg: SelfChatMessage) -> some View {
        HStack {
            Spacer(minLength: 30)
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("chat_me", comment: ""))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SanadTheme.placeholder)

                switch msg.kind {
                case .text:
                    Text(msg.text ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(SanadTheme.onPrimary)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 14).fill(SanadTheme.primary))
                case .image:
                    imageBody(msg)
                case .video:
                    videoBody(msg)
                }

                Text(relativeTime(msg.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(SanadTheme.placeholder)
            }
        }
    }

    private func imageBody(_ msg: SelfChatMessage) -> some View {
        let url = mediaURL(for: msg.fileName)
        return Group {
            if let url = url, let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text(NSLocalizedString("chat_send_failed", comment: ""))
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.onBg)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(SanadTheme.card))
            }
        }
    }

    private func videoBody(_ msg: SelfChatMessage) -> some View {
        let url = mediaURL(for: msg.fileName)
        return Group {
            if let url = url {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(width: 240, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text(NSLocalizedString("chat_send_failed", comment: ""))
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.onBg)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(SanadTheme.card))
            }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let diff = max(0, Int(Date().timeIntervalSince(date)))
        if diff < 60 { return NSLocalizedString("chat_time_now", comment: "") }
        let minutes = diff / 60
        if minutes < 60 { return String(format: NSLocalizedString("chat_time_minutes_ago", comment: ""), minutes) }
        let hours = minutes / 60
        if hours < 24 { return String(format: NSLocalizedString("chat_time_hours_ago", comment: ""), hours) }
        let days = hours / 24
        return String(format: NSLocalizedString("chat_time_days_ago", comment: ""), days)
    }

    private func persistMessages() {
        do {
            let data = try JSONEncoder().encode(messages)
            try data.write(to: messagesFileURL(), options: [.atomic])
        } catch {
            self.error = NSLocalizedString("chat_send_failed", comment: "")
        }
    }

    private func readMessages() throws -> [SelfChatMessage] {
        let url = messagesFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([SelfChatMessage].self, from: data)
    }

    private func messagesFileURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("self_chat_messages.json")
    }

    private func mediaDirectoryURL() throws -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let media = dir.appendingPathComponent("self_chat_media", isDirectory: true)
        if !FileManager.default.fileExists(atPath: media.path) {
            try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
        }
        return media
    }

    private func ensureMediaURL(fileName: String) throws -> URL {
        let mediaDir = try mediaDirectoryURL()
        return mediaDir.appendingPathComponent(fileName)
    }

    private func mediaURL(for fileName: String?) -> URL? {
        guard let fileName = fileName else { return nil }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("self_chat_media").appendingPathComponent(fileName)
    }

    private func parseJournalDate(_ raw: String?) -> Date {
        guard let raw, !raw.isEmpty else { return Date() }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw) ?? Date()
    }

    private func copyItem(at src: URL, to dest: URL) throws {
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: src, to: dest)
    }
}
