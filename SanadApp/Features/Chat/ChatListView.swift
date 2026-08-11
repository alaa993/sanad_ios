import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var chats: [ChatSummary] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showSpecialistPicker = false
    @State private var specialists: [DirectorySpecialist] = []
    @State private var pickerLoading = false
    @State private var pickerError: String?
    @State private var creatingChat = false
    @State private var createdChatId: Int?
    @State private var createdChatTitle = ""
    @State private var navigateToChat = false

    private let service = ChatService()
    private let directory = DirectoryService()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    SanadHeroHeader(title: "chat_list_title")

                    VStack(alignment: .leading, spacing: 14) {
                        Text(subtitleText())
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.placeholder)

                        Button("tour_chat_start_title") {
                            showSpecialistPicker = true
                        }
                        .coachMarkTarget("chat_start")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                        .foregroundColor(SanadTheme.primary)

                        if let err = error {
                            VStack(spacing: 12) {
                                Text(err)
                                    .font(.system(size: 13))
                                    .foregroundColor(SanadTheme.error)
                                Button("chat_retry") { Task { await load() } }
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                                    .foregroundColor(SanadTheme.primary)
                            }
                            .frame(maxWidth: .infinity)
                        } else if loading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        } else if chats.isEmpty {
                            SanadEmptyState(
                                message: "chat_empty",
                                actionTitle: "chat_refresh",
                                action: { Task { await load() } }
                            )
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(chats) { chat in
                                    NavigationLink(destination: ChatRoomView(chatId: chat.id, chatTitle: chatTitle(chat))) {
                                        chatCard(chat)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .coachMarkTarget("chat_list")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
            }
            .background(SanadTheme.surface.ignoresSafeArea())
            .navigationBarHidden(true)
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showSpecialistPicker) {
                specialistPickerSheet
            }
            .background(
                NavigationLink(
                    destination: ChatRoomView(chatId: createdChatId ?? 0, chatTitle: createdChatTitle),
                    isActive: $navigateToChat
                ) { EmptyView() }
            )
            .coachMarks(key: "tour_chat", steps: [
                CoachMarkStep(id: "chat_list", title: "tour_chat_list_title", desc: "tour_chat_list_desc", targetId: "chat_list"),
                CoachMarkStep(id: "chat_start", title: "tour_chat_start_title", desc: "tour_chat_start_desc", targetId: "chat_start")
            ])
        }
    }

    private var specialistPickerSheet: some View {
        NavigationView {
            Group {
                if pickerLoading {
                    ProgressView()
                } else if let pickerError {
                    VStack(spacing: 12) {
                        Text(pickerError)
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.error)
                        Button("chat_retry") { Task { await loadSpecialists() } }
                    }
                    .padding(20)
                } else if specialists.isEmpty {
                    VStack(spacing: 12) {
                        Text("patient_specialists_empty")
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.placeholder)
                        NavigationLink(destination: PatientSpecialistsView()) {
                            Text("patient_specialists_title")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                                .foregroundColor(SanadTheme.primary)
                        }
                    }
                    .padding(20)
                } else {
                    List(specialists) { specialist in
                        Button {
                            Task { await startChat(with: specialist) }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(specialist.name ?? "—")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(SanadTheme.onBg)
                                if let specialty = specialist.specialty, !specialty.isEmpty {
                                    Text(specialty)
                                        .font(.system(size: 12))
                                        .foregroundColor(SanadTheme.placeholder)
                                }
                            }
                        }
                        .disabled(creatingChat)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("patient_specialists_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common_close") { showSpecialistPicker = false }
                }
            }
            .task { await loadSpecialists() }
        }
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        do {
            let res = try await service.list(token: token)
            await MainActor.run {
                self.chats = res
                self.error = nil
            }
        } catch {
            await MainActor.run {
                self.error = NSLocalizedString("chat_load_failed", comment: "")
            }
        }
        loading = false
    }

    private func loadSpecialists() async {
        guard let token = KeychainHelper.getToken() else {
            pickerError = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        pickerLoading = true
        defer { pickerLoading = false }
        do {
            let list = try await directory.specialists(query: nil, token: token)
            await MainActor.run {
                specialists = list
                pickerError = nil
            }
        } catch {
            await MainActor.run {
                pickerError = NSLocalizedString("patient_specialists_load_failed", comment: "")
            }
        }
    }

    private func startChat(with specialist: DirectorySpecialist) async {
        guard let token = KeychainHelper.getToken() else { return }
        creatingChat = true
        defer { creatingChat = false }
        do {
            let chatId = try await service.create(participantIds: [specialist.id], subject: specialist.name, token: token)
            await MainActor.run {
                createdChatId = chatId
                createdChatTitle = specialist.name ?? NSLocalizedString("chat_default_title", comment: "")
                showSpecialistPicker = false
                navigateToChat = true
            }
            await load()
        } catch {
            await MainActor.run {
                pickerError = NSLocalizedString("chat_create_failed", comment: "")
            }
        }
    }

    private func subtitleText() -> String {
        if let first = chats.first, let updated = first.updated_at, !updated.isEmpty {
            return String(format: NSLocalizedString("chat_last_updated", comment: ""), updated)
        }
        return NSLocalizedString("chat_last_updated_short", comment: "")
    }

    private func chatTitle(_ chat: ChatSummary) -> String {
        if let subject = chat.subject, !subject.isEmpty { return subject }
        let names = participantsList(chat, includeSelf: false)
        return names.isEmpty ? NSLocalizedString("chat_default_title", comment: "") : names
    }

    private func participantsList(_ chat: ChatSummary, includeSelf: Bool) -> String {
        let myId = authVM.currentUser?.id
        let names = (chat.participants ?? []).compactMap { participant -> String? in
            guard let id = participant.id else { return nil }
            if !includeSelf, let myId = myId, id == myId { return nil }
            var label = participant.name ?? NSLocalizedString("common_user", comment: "")
            if let role = participant.role, !role.isEmpty {
                label += " (\(mapRole(role)))"
            }
            return label
        }
        return names.joined(separator: " • ")
    }

    private func myRole(_ chat: ChatSummary) -> String? {
        let myId = authVM.currentUser?.id
        guard let myId = myId else { return nil }
        return chat.participants?.first(where: { $0.id == myId })?.role
    }

    @ViewBuilder
    private func chatCard(_ chat: ChatSummary) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(chatTitle(chat))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(SanadTheme.onBg)
                    Spacer(minLength: 8)
                    if let unread = chat.unread_count, unread > 0 {
                        Text("\(unread)")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(SanadTheme.primary))
                            .foregroundColor(SanadTheme.onPrimary)
                    }
                }

                let participants = participantsList(chat, includeSelf: false)
                if !participants.isEmpty {
                    Text(participants)
                        .font(.system(size: 13))
                        .foregroundColor(SanadTheme.placeholder)
                }
                if let role = myRole(chat) {
                    Text(String(format: NSLocalizedString("chat_you_role", comment: ""), mapRole(role)))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }

                Text(chat.last_message ?? NSLocalizedString("chat_no_messages", comment: ""))
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.onBg)
                    .lineLimit(2)

                if let updated = chat.updated_at {
                    Text(updated)
                        .font(.system(size: 11))
                        .foregroundColor(SanadTheme.placeholder)
                }
            }
        }
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

#Preview { ChatListView().environmentObject(AuthViewModel()) }
