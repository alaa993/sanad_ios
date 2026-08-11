import SwiftUI

/// مطابق لـ `SpecialistSessionDetailFragment`.
struct SpecialistSessionDetailView: View {
    let sessionId: Int
    let patientId: Int

    @Environment(\.dismiss) private var dismiss
    @State private var session: SessionItem?
    @State private var tasks: [SessionTask] = []
    @State private var intake: SpecialistPatientIntake?
    @State private var intakeSummary = ""
    @State private var loading = true
    @State private var error: String?
    @State private var toast: String?
    @State private var showReschedule = false
    @State private var showCompleteSheet = false
    @State private var showTriageSheet = false
    @State private var selectedTriageTags: Set<String> = []
    @State private var triageReason = ""
    @State private var diagnosisNotes = ""
    @State private var patientFeedback = 5
    @State private var rescheduleDate = Date()

    private let sessionsService = SessionsService()
    private let actions = SessionActionsService()
    private let specialist = SpecialistService()
    private let triageOptions: [(key: String, value: String)] = [
        ("intake_case_bipolar", "bipolar"),
        ("intake_case_anx_dep", "anx_dep"),
        ("intake_case_schizophrenia", "schizophrenia"),
        ("intake_case_children", "children"),
        ("intake_case_mild", "mild"),
        ("intake_case_identity", "identity")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(
                    title: LocalizedStringKey(session?.user?.name ?? NSLocalizedString("session_detail_title", comment: "")),
                    subtitle: "specialist_session_detail_title"
                )

                VStack(alignment: .leading, spacing: 14) {
                    if loading { ProgressView().frame(maxWidth: .infinity) }
                    if let err = error { Text(err).foregroundColor(SanadTheme.error) }

                    if let session {
                        SanadListCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(format: NSLocalizedString("specialist_session_detail_title", comment: ""), sessionId))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(SanadTheme.onBg)
                                Text(session.status ?? "—")
                                    .font(.system(size: 13))
                                    .foregroundColor(SanadTheme.placeholder)
                                Text(session.scheduled_at ?? "—")
                                    .font(.system(size: 13))
                                    .foregroundColor(SanadTheme.placeholder)
                                if !intakeSummary.isEmpty {
                                    Text(intakeSummary)
                                        .font(.system(size: 13))
                                        .foregroundColor(SanadTheme.onBg)
                                        .padding(12)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(SanadTheme.surfaceAlt))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        SanadListCard {
                            actionButtons(for: session)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        tasksSection
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
        .sheet(isPresented: $showReschedule) { rescheduleSheet }
        .sheet(isPresented: $showCompleteSheet) { completeSheet }
        .sheet(isPresented: $showTriageSheet) { triageSheet }
        .alert(toast ?? "", isPresented: Binding(get: { toast != nil }, set: { if !$0 { toast = nil } })) {
            Button("common_ok", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func actionButtons(for session: SessionItem) -> some View {
        let gate = SessionActionGate.evaluate(
            status: session.status,
            scheduledAt: SessionActionGate.parseIsoDate(session.scheduled_at),
            isSpecialist: true
        )
        VStack(spacing: 10) {
            Text(LocalizedStringKey(gate.joinHintKey))
                .font(SanadFont.caption(12))
                .foregroundColor(SanadTheme.placeholder)
                .frame(maxWidth: .infinity, alignment: .leading)

            if gate.canAccept || gate.canReject {
                HStack {
                    if gate.canAccept {
                        Button("session_accept") { Task { await accept() } }
                            .font(SanadFont.bodyMedium(13))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(SanadTheme.primary))
                            .foregroundColor(SanadTheme.onPrimary)
                    }
                    if gate.canReject {
                        Button("session_reject") { Task { await reject() } }
                            .font(SanadFont.bodyMedium(13))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().stroke(SanadTheme.primary, lineWidth: 1))
                            .foregroundColor(SanadTheme.primary)
                    }
                }
            }

            let type = (session.type ?? "video").lowercased()
            let isChat = type.contains("chat")
            if isChat, let chatId = session.chat_id, chatId > 0 {
                NavigationLink(destination: ChatRoomView(
                    chatId: chatId,
                    chatTitle: type,
                    sessionId: sessionId,
                    sessionEndsAt: session.ends_at,
                    canExtend: true
                )) {
                    Text("session_hub_join")
                        .font(SanadFont.bodyMedium(14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(gate.canJoin ? SanadTheme.primary : SanadTheme.primary.opacity(0.35)))
                        .foregroundColor(SanadTheme.onPrimary)
                }
                .disabled(!gate.canJoin)
            } else if !gate.canAccept {
                NavigationLink(destination: SessionCallView(
                    sessionId: sessionId,
                    joinUrl: session.join_url,
                    callMode: session.type ?? "video"
                )) {
                    Text(gate.phase == .inProgress ? LocalizedStringKey("session_hub_rejoin") : LocalizedStringKey("session_hub_join"))
                        .font(SanadFont.bodyMedium(14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(gate.canJoin ? SanadTheme.primary : SanadTheme.primary.opacity(0.35)))
                        .foregroundColor(SanadTheme.onPrimary)
                }
                .disabled(!gate.canJoin)

                Button("session_reschedule") { showReschedule = true }
                    .font(SanadFont.bodyMedium(13))
                    .foregroundColor(SanadTheme.primary)
            }

            if gate.canComplete {
                Button("session_complete") { showCompleteSheet = true }
                    .font(SanadFont.bodyMedium(13))
                    .foregroundColor(SanadTheme.primary)
            }

            if patientId > 0 {
                Button("patient_intake_triage") {
                    selectedTriageTags = Set(intake?.risk_flags ?? [])
                    triageReason = ""
                    showTriageSheet = true
                }
                .font(SanadFont.bodyMedium(13))
                .foregroundColor(SanadTheme.primary)

                NavigationLink(destination: SpecialistPatientFileView(sessionId: sessionId, patientId: patientId)) {
                    Text("specialist_patient_file")
                        .font(SanadFont.bodyMedium(13))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().stroke(SanadTheme.primary, lineWidth: 1))
                        .foregroundColor(SanadTheme.primary)
                }
            }
        }
    }

    private var tasksSection: some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("session_tasks_title")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                if tasks.isEmpty {
                    SanadEmptyState(message: "session_tasks_empty")
                } else {
                    ForEach(tasks) { task in
                        Text(task.title ?? "—")
                            .font(.system(size: 14))
                            .foregroundColor(SanadTheme.onBg)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var completeSheet: some View {
        NavigationView {
            Form {
                TextField("session_diagnosis_notes", text: $diagnosisNotes, axis: .vertical)
                    .lineLimit(3...8)
                Picker("session_detail_rating", selection: $patientFeedback) {
                    ForEach(1..<6) { value in
                        Text("\(value)").tag(value)
                    }
                }
            }
            .navigationTitle("session_complete")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_cancel") { showCompleteSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common_save") {
                        Task { await complete() }
                    }
                }
            }
        }
    }

    private var triageSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("patient_intake_triage")) {
                    ForEach(triageOptions, id: \.value) { option in
                        Toggle(LocalizedStringKey(option.key), isOn: Binding(
                            get: { selectedTriageTags.contains(option.value) },
                            set: { enabled in
                                if enabled {
                                    selectedTriageTags.insert(option.value)
                                } else {
                                    selectedTriageTags.remove(option.value)
                                }
                            }
                        ))
                    }
                }
                Section(header: Text("session_triage_reason_hint")) {
                    TextField("session_triage_reason_hint", text: $triageReason, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("patient_intake_triage")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_cancel") { showTriageSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common_save") { Task { await saveTriage() } }
                }
            }
        }
    }

    private var rescheduleSheet: some View {
        NavigationView {
            VStack(spacing: 16) {
                DatePicker("session_reschedule_pick", selection: $rescheduleDate, displayedComponents: [.date, .hourAndMinute])
                Button("session_reschedule_confirm") {
                    Task {
                        guard let token = KeychainHelper.getToken() else { return }
                        try? await specialist.reschedule(id: sessionId, startsAt: rescheduleDate, token: token)
                        showReschedule = false
                        toast = NSLocalizedString("session_rescheduled", comment: "")
                        await load()
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Capsule().fill(SanadTheme.primary))
                .foregroundColor(SanadTheme.onPrimary)
            }
            .padding(20)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_cancel") { showReschedule = false }
                }
            }
        }
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else { return }
        loading = true
        defer { loading = false }
        do {
            let s = try await sessionsService.show(id: sessionId, token: token)
            let t = try await actions.listTasks(sessionId: sessionId, token: token)
            var loadedIntake: SpecialistPatientIntake?
            if patientId > 0 {
                loadedIntake = try? await specialist.patientIntake(patientId: patientId, token: token)
            }
            await MainActor.run {
                session = s
                tasks = t
                intake = loadedIntake
                error = nil
                if let flags = loadedIntake?.risk_flags, !flags.isEmpty {
                    intakeSummary = flags.joined(separator: "، ")
                } else if let notes = s.notes, !notes.isEmpty {
                    intakeSummary = notes
                }
            }
        } catch _ {
            await MainActor.run { self.error = NSLocalizedString("session_detail_load_failed", comment: "") }
        }
    }

    private func saveTriage() async {
        guard let token = KeychainHelper.getToken(), patientId > 0 else { return }
        do {
            let updated = try await specialist.updateIntake(
                patientId: patientId,
                triageTags: Array(selectedTriageTags),
                triageReason: triageReason.isEmpty ? nil : triageReason,
                token: token
            )
            await MainActor.run {
                intake = updated
                intakeSummary = (updated.risk_flags ?? []).joined(separator: "، ")
                showTriageSheet = false
                toast = NSLocalizedString("session_triage_saved", comment: "")
            }
        } catch {
            await MainActor.run {
                toast = NSLocalizedString("session_triage_save_failed", comment: "")
            }
        }
    }

    private func accept() async {
        guard let token = KeychainHelper.getToken() else { return }
        try? await specialist.accept(id: sessionId, token: token)
        toast = NSLocalizedString("session_accepted", comment: "")
        await load()
    }

    private func reject() async {
        guard let token = KeychainHelper.getToken() else { return }
        try? await specialist.reject(id: sessionId, token: token)
        toast = NSLocalizedString("session_rejected", comment: "")
        await load()
    }

    private func complete() async {
        guard let token = KeychainHelper.getToken() else { return }
        try? await specialist.complete(
            id: sessionId,
            diagnosisNotes: diagnosisNotes,
            patientFeedback: patientFeedback,
            token: token
        )
        showCompleteSheet = false
        diagnosisNotes = ""
        toast = NSLocalizedString("session_completed", comment: "")
        await load()
    }
}
