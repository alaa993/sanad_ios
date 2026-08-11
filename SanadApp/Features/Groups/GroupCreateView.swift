import SwiftUI

struct GroupCreateView: View {
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var topic = ""
    @State private var type = "video"
    @State private var startAt = Date().addingTimeInterval(3600)
    @State private var durationMinutes = 60
    @State private var selectedPatientIds: Set<Int> = []
    @State private var showPatients = false
    @State private var error: String?
    @State private var loading = false

    private let service = GroupSessionsService()

    var body: some View {
        NavigationView {
            Form {
                if let err = error {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }

                Section(header: Text("group_create_basic")) {
                    TextField("group_create_title", text: $title)
                    TextField("group_create_topic", text: $topic)
                    Picker("group_create_type", selection: $type) {
                        Text("session_type_video").tag("video")
                        Text("session_type_voice").tag("voice")
                        Text("session_type_chat").tag("chat")
                    }
                }

                Section(header: Text("group_create_schedule")) {
                    DatePicker("book_session_date_time", selection: $startAt, displayedComponents: [.date, .hourAndMinute])
                    Stepper(value: $durationMinutes, in: 30...180, step: 15) {
                        Text(String(format: NSLocalizedString("group_create_duration", comment: ""), durationMinutes))
                    }
                }

                Section(header: Text("group_create_participants")) {
                    Button(String(format: NSLocalizedString("group_create_choose_participants", comment: ""), selectedPatientIds.count)) {
                        showPatients = true
                    }
                }
            }
            .navigationTitle("group_create_title_nav")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loading ? "group_create_saving" : "common_save") {
                        Task { await submit() }
                    }
                    .disabled(loading || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .sheet(isPresented: $showPatients) {
            GroupPatientPickerView(selectedIds: $selectedPatientIds)
        }
    }

    private func submit() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        let endAt = startAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
        do {
            _ = try await service.create(title: title,
                                         topic: topic.isEmpty ? nil : topic,
                                         type: type,
                                         startAt: startAt,
                                         endAt: endAt,
                                         participantIds: Array(selectedPatientIds),
                                         token: token)
            await MainActor.run {
                loading = false
                dismiss()
                onCreated()
            }
        } catch {
            await MainActor.run {
                loading = false
                self.error = NSLocalizedString("group_create_failed", comment: "")
            }
        }
    }
}

#Preview { GroupCreateView(onCreated: {}) }
