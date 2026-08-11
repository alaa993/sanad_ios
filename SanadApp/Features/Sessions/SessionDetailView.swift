import SwiftUI
import UIKit

struct SessionDetailView: View {
    @EnvironmentObject var authVM: AuthViewModel
    let sessionId: Int
    @State private var session: SessionItem?
    @State private var tasks: [SessionTask] = []
    @State private var error: String?
    @State private var alertMessage: String?
    @State private var showAddTask = false
    @State private var showCompleteTask = false
    @State private var showRating = false
    @State private var selectedTask: SessionTask?
    @State private var ratingTargetIsPatient = false
    @State private var ratingScore = 5
    @State private var ratingComment = ""
    @State private var taskTitle = ""
    @State private var taskDescription = ""
    @State private var taskType = "task"
    @State private var taskAnswer = ""
    @State private var showSteps = false
    @State private var showCompleteSheet = false
    @State private var showSurvey = false
    @State private var showCancelConfirm = false
    @State private var diagnosisNotes = ""
    @State private var patientFeedback = 5

    private let service = SessionsService()
    private let actions = SessionActionsService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "session_detail_title", subtitle: "session_detail_join_section")

                VStack(alignment: .leading, spacing: 14) {
                    if let err = error {
                        Text(err).foregroundColor(SanadTheme.error)
                    }

                    headerCard()
                    joinCard()
                    stepsSection()
                    tasksCard()
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
        .alert(alertMessage ?? "", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("common_ok", role: .cancel) {}
        }
        .sheet(isPresented: $showAddTask) {
            addTaskSheet()
        }
        .sheet(isPresented: $showCompleteTask) {
            completeTaskSheet()
        }
        .sheet(isPresented: $showRating) {
            ratingSheet()
        }
        .sheet(isPresented: $showCompleteSheet) {
            completeSessionSheet()
        }
        .sheet(isPresented: $showSurvey) {
            PostSessionSurveyView(sessionId: sessionId) {
                Task { await load() }
            }
        }
        .confirmationDialog("session_cancel_action", isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button("session_cancel_action", role: .destructive) {
                Task { await cancelSession() }
            }
            Button("common_cancel", role: .cancel) {}
        }
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        do {
            let res = try await service.show(id: sessionId, token: token)
            let list = try await actions.listTasks(sessionId: sessionId, token: token)
            await MainActor.run {
                session = res
                tasks = list
                error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("session_detail_load_failed", comment: "") }
        }
    }

    private func headerCard() -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 8) {
                if let status = session?.status {
                    Text(String(format: NSLocalizedString("session_detail_status", comment: ""), mapStatus(status)))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
                Text(String(format: NSLocalizedString("session_detail_schedule", comment: ""), formatSchedule(session?.scheduled_at)))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
                if let spec = session?.specialist?.name {
                    Text(String(format: NSLocalizedString("session_detail_specialist", comment: ""), spec))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
                if let org = session?.organization?.name {
                    Text(String(format: NSLocalizedString("session_detail_org", comment: ""), org))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
                if let notes = session?.notes, !notes.isEmpty {
                    Text(String(format: NSLocalizedString("session_detail_notes", comment: ""), notes))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
                if let diagnosis = session?.specialist_notes, !diagnosis.isEmpty {
                    Text(String(format: NSLocalizedString("session_diagnosis_notes", comment: ""), diagnosis))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
                if session?.transferred_at != nil {
                    Text("session_transferred_banner")
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.primary)
                    if let reason = session?.transfer_reason, !reason.isEmpty {
                        Text(String(format: NSLocalizedString("session_transfer_reason", comment: ""), localizedTransferReason(reason)))
                            .font(.system(size: 12))
                            .foregroundColor(SanadTheme.placeholder)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func actionGate() -> SessionActionGate {
        SessionActionGate.evaluate(
            status: session?.status,
            scheduledAt: SessionActionGate.parseIsoDate(session?.scheduled_at),
            isSpecialist: isSpecialist()
        )
    }

    private func joinCard() -> some View {
        let gate = actionGate()
        return SanadListCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("session_detail_join_section")
                    .font(SanadFont.bodyMedium(15))
                    .foregroundColor(SanadTheme.placeholder)

                Text(LocalizedStringKey(gate.joinHintKey))
                    .font(SanadFont.caption(12))
                    .foregroundColor(SanadTheme.placeholder)

                hubPrimaryJoin(gate: gate)

                if gate.canComplete {
                    Button("session_detail_end_session") { showCompleteSheet = true }
                        .font(SanadFont.bodyMedium(13))
                        .foregroundColor(SanadTheme.error)
                }

                if gate.canCancel {
                    Button("session_cancel_action") { showCancelConfirm = true }
                        .font(SanadFont.bodyMedium(13))
                        .foregroundColor(SanadTheme.error)
                }

                if !isSpecialist() && shouldConfirmPayment() {
                    Button("session_confirm_payment") { Task { await confirmPayment() } }
                        .font(SanadFont.bodyMedium(13))
                        .foregroundColor(SanadTheme.primary)
                }

                if !isSpecialist() && shouldShowSurvey() {
                    Button("post_session_survey_title") { showSurvey = true }
                        .font(SanadFont.bodyMedium(13))
                        .foregroundColor(SanadTheme.primary)
                }

                if shouldShowRating() {
                    Button(isSpecialist() ? NSLocalizedString("session_detail_rate_patient", comment: "") : NSLocalizedString("session_detail_rate_specialist", comment: "")) {
                        ratingTargetIsPatient = isSpecialist()
                        showRating = true
                    }
                    .font(SanadFont.bodyMedium(13))
                    .foregroundColor(SanadTheme.primary)
                }

                if let link = session?.join_url, !link.isEmpty, gate.canJoin {
                    Button("session_join_copy_link") {
                        UIPasteboard.general.string = link
                    }
                    .font(SanadFont.caption(12))
                    .foregroundColor(SanadTheme.placeholder)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func hubPrimaryJoin(gate: SessionActionGate) -> some View {
        let type = (session?.type ?? "video").lowercased()
        let isChat = type.contains("chat")
        let joinTitle = gate.phase == .inProgress
            ? LocalizedStringKey("session_hub_rejoin")
            : LocalizedStringKey("session_hub_join")

        if isChat, let chatId = session?.chat_id, chatId > 0 {
            NavigationLink(destination: ChatRoomView(
                chatId: chatId,
                chatTitle: type,
                sessionId: sessionId,
                sessionEndsAt: session?.ends_at,
                canExtend: isSpecialist()
            )) {
                Text(joinTitle)
                    .font(SanadFont.bodyMedium(15))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(gate.canJoin ? SanadTheme.primary : SanadTheme.primary.opacity(0.35)))
                    .foregroundColor(SanadTheme.onPrimary)
            }
            .disabled(!gate.canJoin)
        } else {
            NavigationLink(destination: SessionCallView(
                sessionId: sessionId,
                joinUrl: session?.join_url,
                callMode: session?.type ?? "video"
            )) {
                Text(joinTitle)
                    .font(SanadFont.bodyMedium(15))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(gate.canJoin ? SanadTheme.primary : SanadTheme.primary.opacity(0.35)))
                    .foregroundColor(SanadTheme.onPrimary)
            }
            .disabled(!gate.canJoin)
        }
    }

    private func stepsSection() -> some View {
        VStack(alignment: .center, spacing: 10) {
            Button(showSteps ? "session_steps_toggle_hide" : "session_steps_toggle_show") {
                showSteps.toggle()
            }
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .stroke(SanadTheme.primary, lineWidth: 1)
            )
            .foregroundColor(SanadTheme.primary)

            if showSteps {
                SanadListCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("session_steps_title")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(SanadTheme.onBg)
                        Text(isSpecialist() ? "session_steps_specialist" : "session_steps_patient")
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.placeholder)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func tasksCard() -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("session_detail_tasks_title")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(SanadTheme.placeholder)
                    Spacer()
                    if isSpecialist() {
                        Button("session_detail_add_task") { showAddTask = true }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(SanadTheme.primary)
                    }
                }

                if tasks.isEmpty {
                    SanadEmptyState(message: "session_detail_no_tasks")
                } else {
                    ForEach(tasks) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title ?? NSLocalizedString("session_detail_task_default", comment: ""))
                                .font(.system(size: 14, weight: .semibold))
                            Text(taskStatus(task))
                                .font(.system(size: 12))
                                .foregroundColor(SanadTheme.placeholder)
                            if let answer = task.patient_answer, !answer.isEmpty {
                                Text(String(format: NSLocalizedString("session_detail_answer", comment: ""), answer))
                                    .font(.system(size: 12))
                                    .foregroundColor(SanadTheme.placeholder)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(SanadTheme.surfaceAlt))
                        .onTapGesture {
                            if !isSpecialist() && (task.status ?? "").lowercased() == "open" {
                                selectedTask = task
                                taskAnswer = ""
                                showCompleteTask = true
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func addTaskSheet() -> some View {
        NavigationView {
            Form {
                TextField("session_detail_task_title", text: $taskTitle)
                TextField("session_detail_task_description_optional", text: $taskDescription)
                Picker("session_detail_task_type", selection: $taskType) {
                    Text("session_detail_task_type_task").tag("task")
                    Text("session_detail_task_type_question").tag("question")
                    Text("session_detail_task_type_exercise").tag("exercise")
                }
            }
            .navigationTitle("session_detail_new_task")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common_save") { Task { await addTask() } }
                        .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common_cancel") { showAddTask = false }
                }
            }
        }
    }

    private func completeTaskSheet() -> some View {
        NavigationView {
            Form {
                TextField("session_detail_task_answer", text: $taskAnswer)
            }
            .navigationTitle("session_detail_complete_task")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common_send") { Task { await completeTask() } }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common_cancel") { showCompleteTask = false }
                }
            }
        }
    }

    private func ratingSheet() -> some View {
        NavigationView {
            Form {
                Picker("session_detail_rating", selection: $ratingScore) {
                    ForEach(1..<6) { value in
                        Text("\(value)").tag(value)
                    }
                }
                TextField("session_detail_rating_notes_optional", text: $ratingComment)
            }
            .navigationTitle("session_detail_rating_title")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common_send") { Task { await submitRating() } }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common_cancel") { showRating = false }
                }
            }
        }
    }

    private func completeSessionSheet() -> some View {
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
            .navigationTitle("session_detail_end_session")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common_cancel") { showCompleteSheet = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common_save") { Task { await completeSession() } }
                }
            }
        }
    }

    private func addTask() async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await actions.addTask(sessionId: sessionId, title: taskTitle, description: taskDescription, type: taskType, token: token)
            taskTitle = ""
            taskDescription = ""
            showAddTask = false
            await load()
        } catch {
            alertMessage = NSLocalizedString("session_detail_add_task_failed", comment: "")
        }
    }

    private func completeTask() async {
        guard let token = KeychainHelper.getToken(), let task = selectedTask else { return }
        do {
            try await actions.completeTask(taskId: task.id, answer: taskAnswer, token: token)
            taskAnswer = ""
            showCompleteTask = false
            await load()
        } catch {
            alertMessage = NSLocalizedString("session_detail_complete_task_failed", comment: "")
        }
    }

    private func submitRating() async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            if ratingTargetIsPatient {
                try await actions.ratePatient(sessionId: sessionId, score: ratingScore, comment: ratingComment, token: token)
            } else {
                try await actions.rateSpecialist(sessionId: sessionId, score: ratingScore, comment: ratingComment, token: token)
            }
            showRating = false
            ratingComment = ""
        } catch {
            alertMessage = NSLocalizedString("session_detail_save_rating_failed", comment: "")
        }
    }

    private func isSpecialist() -> Bool {
        (authVM.userRole ?? "").lowercased() == "specialist"
    }

    private func isActiveSession() -> Bool {
        guard let status = session?.status?.lowercased() else { return false }
        return ["accepted", "confirmed", "in_progress", "started", "scheduled", "upcoming"].contains(status)
    }

    private func shouldShowRating() -> Bool {
        guard let status = session?.status?.lowercased() else { return false }
        return status.contains("completed")
    }

    private func shouldShowSurvey() -> Bool {
        guard let status = session?.status?.lowercased() else { return false }
        if session?.survey_submitted == true { return false }
        return status.contains("completed")
    }

    private func canCancelSession() -> Bool {
        guard let status = session?.status?.lowercased() else { return false }
        return ["pending", "scheduled", "upcoming", "accepted", "confirmed"].contains(status)
    }

    private func shouldConfirmPayment() -> Bool {
        guard let status = session?.status?.lowercased() else { return false }
        return status == "pending"
    }

    private func cancelSession() async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await service.cancel(id: sessionId, reason: nil, token: token)
            await load()
        } catch {
            alertMessage = NSLocalizedString("session_cancel_failed", comment: "")
        }
    }

    private func confirmPayment() async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await service.confirmPayment(id: sessionId, method: "points", token: token)
            await load()
        } catch {
            alertMessage = NSLocalizedString("session_payment_failed", comment: "")
        }
    }

    private func taskStatus(_ task: SessionTask) -> String {
        let status = (task.status ?? "open").lowercased()
        if status == "completed" { return NSLocalizedString("session_status_completed", comment: "") }
        return NSLocalizedString("session_status_open", comment: "")
    }

    private func mapStatus(_ raw: String) -> String {
        switch raw.lowercased() {
        case "pending":
            return NSLocalizedString("session_status_pending", comment: "")
        case "scheduled", "upcoming", "accepted", "confirmed", "in_progress", "started":
            return NSLocalizedString("session_status_upcoming", comment: "")
        case "completed":
            return NSLocalizedString("session_status_completed", comment: "")
        case "rejected":
            return NSLocalizedString("session_status_rejected", comment: "")
        case "cancelled", "canceled":
            return NSLocalizedString("session_status_cancelled", comment: "")
        default:
            return raw
        }
    }

    private func formatSchedule(_ iso: String?) -> String {
        guard let iso = iso, let date = parseIsoDate(iso) else { return iso ?? NSLocalizedString("common_no_schedule", comment: "") }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd - hh:mm a"
        return formatter.string(from: date)
    }

    private func parseIsoDate(_ iso: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) { return date }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: iso)
    }

    private func completeSession() async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await service.complete(
                id: sessionId,
                diagnosisNotes: diagnosisNotes,
                patientFeedback: patientFeedback,
                token: token
            )
            showCompleteSheet = false
            diagnosisNotes = ""
            await load()
        } catch {
            alertMessage = NSLocalizedString("session_detail_end_failed", comment: "")
        }
    }

    private func localizedTransferReason(_ raw: String) -> String {
        switch raw.lowercased() {
        case "no_response":
            return NSLocalizedString("session_transfer_reason_no_response", comment: "")
        case "long_case", "physician_referral":
            return NSLocalizedString("session_transfer_reason_long_case", comment: "")
        default:
            return raw
        }
    }
}

#Preview { SessionDetailView(sessionId: 1).environmentObject(AuthViewModel()) }
