import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var appointments: [CalendarAppointment] = []
    @State private var availability: CalendarAvailabilityResponse?
    @State private var loading = false
    @State private var availabilityLoading = false
    @State private var error: String?
    @State private var scope: String = "patient"
    @State private var showSlotSheet = false
    @State private var showBlockSheet = false
    @State private var cancellationInProgress: Int?
    @State private var actionInProgress: Int?
    @State private var rescheduleTarget: CalendarAppointment?

    private let service = CalendarService()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .trailing, spacing: 20) {
                    header
                    if let msg = error {
                        Text(msg)
                            .foregroundColor(.red)
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    appointmentSection
                    if isSpecialist {
                        availabilitySection
                    }
                }
                .padding(20)
            }
            .background(SanadTheme.surface.ignoresSafeArea())
            .navigationTitle("calendar_title")
            .navigationBarTitleDisplayMode(.inline)
            .task { await refresh() }
            .refreshable { await refresh() }
            .sheet(isPresented: $showSlotSheet) { addSlotSheet }
            .sheet(isPresented: $showBlockSheet) { addBlockSheet }
            .sheet(item: $rescheduleTarget) { appointment in
                RescheduleAppointmentSheet(appointment: appointment) { startsAt, endsAt in
                    Task {
                        await reschedule(appointment.id, startsAt: startsAt, endsAt: endsAt)
                        await MainActor.run { rescheduleTarget = nil }
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("calendar_schedule_title")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)
            Picker("calendar_scope", selection: $scope) {
                Text("calendar_scope_patient").tag("patient")
                Text("calendar_scope_specialist").tag("specialist")
            }
            .pickerStyle(.segmented)
            .onChange(of: scope) {
                Task { await loadAppointments() }
            }
        }
    }

    private var appointmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("calendar_appointments_title")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                Spacer()
                if loading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            if appointments.isEmpty {
                Text("calendar_no_appointments")
                    .font(.system(size: 14))
                    .foregroundColor(SanadTheme.placeholder)
            } else {
                ForEach(appointments) { appointment in
                    appointmentRow(appointment)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(SanadTheme.card))
        .shadow(color: SanadTheme.subtleShadow, radius: 4, y: 3)
    }

    private func appointmentRow(_ appointment: CalendarAppointment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(appointment.type ?? NSLocalizedString("session_fallback_title", comment: ""))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)
            Text("\(formatDate(appointment.starts_at)) → \(formatDate(appointment.ends_at))")
                .font(.system(size: 13))
                .foregroundColor(SanadTheme.placeholder)
            Text(String(format: NSLocalizedString("calendar_status", comment: ""), appointment.status ?? NSLocalizedString("calendar_status_unknown", comment: "")))
                .font(.system(size: 12))
                .foregroundColor(SanadTheme.primary)
            if let notes = appointment.notes, !notes.isEmpty {
                Text(String(format: NSLocalizedString("calendar_notes", comment: ""), notes))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
            }
            HStack {
                Text(scope == "patient"
                     ? String(format: NSLocalizedString("calendar_specialist_label", comment: ""), appointment.specialist?.name ?? "—")
                     : String(format: NSLocalizedString("calendar_patient_label", comment: ""), appointment.patient?.name ?? "—"))
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.placeholder)
                Spacer()
                if scope == "specialist" && appointment.status == "pending" {
                    Button("calendar_accept") {
                        Task { await accept(appointment.id) }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SanadTheme.primary)
                    .disabled(actionInProgress == appointment.id)

                    Button("calendar_reject") {
                        Task { await reject(appointment.id) }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.red)
                    .disabled(actionInProgress == appointment.id)
                }
                if appointment.status != "completed" && appointment.status != "canceled" {
                    if scope == "specialist" || scope == "patient" {
                        Button("calendar_reschedule") {
                            rescheduleTarget = appointment
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(SanadTheme.primary)
                    }
                    Button {
                        Task { await cancel(appointment.id) }
                    } label: {
                        Text("common_cancel")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                    }
                    .disabled(cancellationInProgress == appointment.id)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(SanadTheme.surface))
    }

    private var availabilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("calendar_availability_title")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                Spacer()
                Button("calendar_add_slot") { showSlotSheet = true }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SanadTheme.primary)
                Button("calendar_block_time") { showBlockSheet = true }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SanadTheme.primary)
            }
            if availabilityLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let availability = availability {
                VStack(alignment: .leading, spacing: 10) {
                    if availability.slots.isEmpty {
                        Text("calendar_no_slots")
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.placeholder)
                    } else {
                        ForEach(availability.slots) { slot in
                            slotRow(slot)
                        }
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("calendar_blocked_time")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SanadTheme.onBg)
                    if availability.blocks.isEmpty {
                        Text("calendar_no_blocks")
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.placeholder)
                    } else {
                        ForEach(availability.blocks) { block in
                            blockRow(block)
                        }
                    }
                }
            } else {
                Text("calendar_unavailable")
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.placeholder)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(SanadTheme.card))
        .shadow(color: SanadTheme.subtleShadow, radius: 4, y: 3)
    }

    private func slotRow(_ slot: CalendarSlot) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(weekdayLabel(slot.weekday))
                    .font(.system(size: 14, weight: .semibold))
                Text("\(slot.start_time) - \(slot.end_time)")
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
            }
            Spacer()
            Button("common_delete") {
                Task { await removeSlot(slot.id) }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.red)
        }
    }

    private func blockRow(_ block: CalendarBlock) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(formatDate(block.start_at)) → \(formatDate(block.end_at))")
                    .font(.system(size: 13, weight: .semibold))
                if let reason = block.reason {
                    Text(reason)
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
            }
            Spacer()
            Button("common_cancel") {
                Task { await removeBlock(block.id) }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.red)
        }
    }

    private var addSlotSheet: some View {
        SlotFormView { weekday, start, end, repeatRule in
            Task {
                await addSlot(weekday: weekday, start: start, end: end, repeatRule: repeatRule)
                showSlotSheet = false
            }
        }
    }

    private var addBlockSheet: some View {
        BlockFormView { start, end, reason in
            Task {
                await addBlock(start: start, end: end, reason: reason)
                showBlockSheet = false
            }
        }
    }

    private var isSpecialist: Bool {
        let role = authVM.userRole?.lowercased() ?? ""
        return role == "specialist" || role == "organization"
    }

    private func refresh() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadAppointments() }
            if isSpecialist {
                group.addTask { await loadAvailability() }
            }
        }
    }

    private func loadAppointments() async {
        guard let token = KeychainHelper.getToken() else { return }
        loading = true
        defer { loading = false }
        do {
            let data = try await service.appointments(scope: scope, token: token)
            await MainActor.run {
                self.appointments = data
                self.error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("calendar_load_appointments_failed", comment: "") }
        }
    }

    private func loadAvailability() async {
        guard let token = KeychainHelper.getToken() else { return }
        availabilityLoading = true
        defer { availabilityLoading = false }
        do {
            let data = try await service.availability(token: token)
            await MainActor.run {
                self.availability = data
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("calendar_load_availability_failed", comment: "") }
        }
    }

    private func cancel(_ id: Int) async {
        guard let token = KeychainHelper.getToken() else { return }
        cancellationInProgress = id
        defer { cancellationInProgress = nil }
        do {
            try await service.cancel(id: id, reason: nil, token: token)
            await loadAppointments()
        } catch {
            await MainActor.run { self.error = NSLocalizedString("calendar_cancel_failed", comment: "") }
        }
    }

    private func accept(_ id: Int) async {
        guard let token = KeychainHelper.getToken() else { return }
        actionInProgress = id
        defer { actionInProgress = nil }
        do {
            try await service.acceptAppointment(id: id, token: token)
            await loadAppointments()
        } catch {
            await MainActor.run { self.error = NSLocalizedString("calendar_accept_failed", comment: "") }
        }
    }

    private func reject(_ id: Int) async {
        guard let token = KeychainHelper.getToken() else { return }
        actionInProgress = id
        defer { actionInProgress = nil }
        do {
            try await service.rejectAppointment(id: id, reason: nil, token: token)
            await loadAppointments()
        } catch {
            await MainActor.run { self.error = NSLocalizedString("calendar_reject_failed", comment: "") }
        }
    }

    private func reschedule(_ id: Int, startsAt: Date, endsAt: Date) async {
        guard let token = KeychainHelper.getToken() else { return }
        actionInProgress = id
        defer { actionInProgress = nil }
        do {
            try await service.rescheduleAppointment(id: id, startsAt: startsAt, endsAt: endsAt, token: token)
            await loadAppointments()
        } catch {
            await MainActor.run { self.error = NSLocalizedString("calendar_reschedule_failed", comment: "") }
        }
    }

    private func removeSlot(_ id: Int) async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await service.deleteSlot(id: id, token: token)
            await loadAvailability()
        } catch {
            await MainActor.run { self.error = NSLocalizedString("calendar_delete_slot_failed", comment: "") }
        }
    }

    private func addSlot(weekday: Int, start: String, end: String, repeatRule: String?) async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await service.createSlot(weekday: weekday, start: start, end: end, repeatRule: repeatRule, token: token)
            await loadAvailability()
        } catch {
            await MainActor.run { self.error = NSLocalizedString("calendar_create_slot_failed", comment: "") }
        }
    }

    private func addBlock(start: Date, end: Date, reason: String?) async {
        guard let token = KeychainHelper.getToken() else { return }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        do {
            try await service.block(start: iso.string(from: start), end: iso.string(from: end), reason: reason, token: token)
            await loadAvailability()
        } catch {
            await MainActor.run { self.error = NSLocalizedString("calendar_block_time_failed", comment: "") }
        }
    }

    private func removeBlock(_ id: Int) async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await service.unblock(id: id, token: token)
            await loadAvailability()
        } catch {
            await MainActor.run { self.error = NSLocalizedString("calendar_unblock_failed", comment: "") }
        }
    }

    private func formatDate(_ iso: String?) -> String {
        guard let iso = iso, let date = parseIso(iso) else {
            return NSLocalizedString("calendar_unknown", comment: "")
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func parseIso(_ iso: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    }
}

private func weekdayLabel(_ weekday: Int) -> String {
    switch weekday {
    case 0: return NSLocalizedString("weekday_sunday", comment: "")
    case 1: return NSLocalizedString("weekday_monday", comment: "")
    case 2: return NSLocalizedString("weekday_tuesday", comment: "")
    case 3: return NSLocalizedString("weekday_wednesday", comment: "")
    case 4: return NSLocalizedString("weekday_thursday", comment: "")
    case 5: return NSLocalizedString("weekday_friday", comment: "")
    case 6: return NSLocalizedString("weekday_saturday", comment: "")
    default: return NSLocalizedString("weekday_day", comment: "")
    }
}

private struct SlotFormView: View {
    @Environment(\.dismiss) var dismiss
    @State private var weekday = 1
    @State private var start = Date()
    @State private var end = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var repeatRule = ""
    var onSave: (Int, String, String, String?) -> Void

    var body: some View {
        NavigationView {
            Form {
                Picker("calendar_weekday", selection: $weekday) {
                    ForEach(0..<7) { day in
                        Text(weekdayLabel(day)).tag(day)
                    }
                }
                DatePicker("calendar_from", selection: $start, displayedComponents: .hourAndMinute)
                DatePicker("calendar_to", selection: $end, displayedComponents: .hourAndMinute)
                Section(header: Text("calendar_repeat_optional")) {
                    TextField("calendar_repeat_example", text: $repeatRule)
                }
            }
            .navigationTitle("calendar_add_slot")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common_save") {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        let startText = formatter.string(from: start)
                        let endText = formatter.string(from: end)
                        onSave(weekday, startText, endText, repeatRule.isEmpty ? nil : repeatRule)
                    }
                }
            }
        }
    }
}

private struct BlockFormView: View {
    @Environment(\.dismiss) var dismiss
    @State private var start = Date()
    @State private var end = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var reason = ""
    var onSave: (Date, Date, String?) -> Void

    var body: some View {
        NavigationView {
            Form {
                DatePicker("calendar_from", selection: $start, displayedComponents: [.date, .hourAndMinute])
                DatePicker("calendar_to", selection: $end, displayedComponents: [.date, .hourAndMinute])
                Section(header: Text("calendar_reason_optional")) {
                    TextField("calendar_notes_placeholder", text: $reason)
                }
            }
            .navigationTitle("calendar_block_time")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common_save") {
                        onSave(start, end, reason.isEmpty ? nil : reason)
                    }
                }
            }
        }
    }
}

private struct RescheduleAppointmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let appointment: CalendarAppointment
    var onSave: (Date, Date) -> Void

    @State private var start: Date
    @State private var end: Date

    init(appointment: CalendarAppointment, onSave: @escaping (Date, Date) -> Void) {
        self.appointment = appointment
        self.onSave = onSave
        let parsedStart = RescheduleAppointmentSheet.parse(appointment.starts_at) ?? Date()
        let parsedEnd = RescheduleAppointmentSheet.parse(appointment.ends_at) ?? parsedStart.addingTimeInterval(3600)
        _start = State(initialValue: parsedStart)
        _end = State(initialValue: parsedEnd)
    }

    var body: some View {
        NavigationView {
            Form {
                DatePicker("calendar_from", selection: $start, displayedComponents: [.date, .hourAndMinute])
                DatePicker("calendar_to", selection: $end, displayedComponents: [.date, .hourAndMinute])
            }
            .navigationTitle("calendar_reschedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common_save") {
                        onSave(start, end)
                        dismiss()
                    }
                }
            }
        }
    }

    private static func parse(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    }
}
