import SwiftUI

struct TasksView: View {
    @State private var upcoming: [TaskItem] = []
    @State private var completed: [TaskItem] = []
    @State private var error: String?
    @State private var loading = false
    @State private var note: String = ""
    @State private var selectedTask: TaskItem?
    @State private var showNote = false
    @State private var showCreate = false
    @State private var newTitle = ""
    @State private var newDescription = ""
    @State private var newAppointmentId = ""
    @State private var newDueDate = Date()

    private let service = TasksService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "tasks_title")

                VStack(alignment: .leading, spacing: 14) {
                    if loading && upcoming.isEmpty && completed.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }

                    if let err = error {
                        Text(err)
                            .foregroundColor(SanadTheme.error)
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button("tasks_add") {
                        showCreate = true
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(SanadTheme.primary))
                    .foregroundColor(SanadTheme.onPrimary)

                    section(title: "tasks_upcoming", items: upcoming, actionable: true)
                    section(title: "tasks_completed", items: completed, actionable: false)
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
        .sheet(isPresented: $showNote) {
            noteSheet
        }
        .sheet(isPresented: $showCreate) {
            createSheet
        }
    }

    private func section(title: LocalizedStringKey, items: [TaskItem], actionable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(SanadTheme.placeholder)
            if items.isEmpty {
                SanadEmptyState(message: "common_no_items")
            } else {
                ForEach(items) { t in
                    SanadListCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(t.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(SanadTheme.onBg)
                            if let d = t.description {
                                Text(d)
                                    .font(.system(size: 13))
                                    .foregroundColor(SanadTheme.placeholder)
                            }
                            if let due = t.due_at {
                                Text(String(format: NSLocalizedString("tasks_due", comment: ""), due))
                                    .font(.system(size: 12))
                                    .foregroundColor(SanadTheme.placeholder)
                            }
                            if actionable {
                                Button("tasks_mark_complete") {
                                    selectedTask = t
                                    showNote = true
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                                .foregroundColor(SanadTheme.primary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        TaskReminderManager.shared.requestAuthorizationIfNeeded()
        await MainActor.run { loading = true }
        defer { Task { @MainActor in loading = false } }
        do {
            let res = try await service.list(token: token)
            await MainActor.run {
                upcoming = res.upcoming
                completed = res.completed
                error = nil
            }
            TaskReminderManager.shared.sync(upcoming: res.upcoming)
        } catch {
            await MainActor.run { self.error = NSLocalizedString("tasks_load_failed", comment: "") }
        }
    }

    private func completeTask(note: String?) async {
        guard let token = KeychainHelper.getToken(), let task = selectedTask else { return }
        do {
            try await service.complete(id: task.id, note: note, token: token)
            await MainActor.run {
                showNote = false
                selectedTask = nil
                self.note = ""
            }
            await load()
        } catch {
            await MainActor.run { self.error = NSLocalizedString("tasks_update_failed", comment: "") }
        }
    }

    private var noteSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("tasks_note_optional")) {
                    TextEditor(text: $note)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("tasks_complete_title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_cancel") { showNote = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common_save") {
                        Task { await completeTask(note: note.isEmpty ? nil : note) }
                    }
                }
            }
        }
    }

    private var createSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("tasks_new_title")) {
                    TextField("tasks_new_title_placeholder", text: $newTitle)
                }
                Section(header: Text("tasks_new_description")) {
                    TextEditor(text: $newDescription)
                        .frame(minHeight: 100)
                }
                Section(header: Text("tasks_new_session_id_optional")) {
                    TextField("tasks_new_session_id_placeholder", text: $newAppointmentId)
                        .keyboardType(.numberPad)
                }
                Section(header: Text("tasks_new_due_date")) {
                    DatePicker("tasks_new_due_picker", selection: $newDueDate, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("tasks_new_title_nav")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_cancel") { showCreate = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common_save") {
                        Task { await createTask() }
                    }.disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func createTask() async {
        guard let token = KeychainHelper.getToken() else { return }
        let appId = Int(newAppointmentId.trimmingCharacters(in: .whitespaces))
        do {
            try await service.create(title: newTitle,
                                     description: newDescription.isEmpty ? nil : newDescription,
                                     dueAt: newDueDate,
                                     appointmentId: appId,
                                     token: token)
            await MainActor.run {
                newTitle = ""; newDescription = ""; newAppointmentId = ""
                showCreate = false
            }
            await load()
        } catch {
            await MainActor.run { self.error = NSLocalizedString("tasks_create_failed", comment: "") }
        }
    }
}

#Preview { TasksView() }
