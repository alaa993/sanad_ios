import SwiftUI

struct BookSessionView: View {
    @Environment(\.dismiss) private var dismiss
    var onCompleted: (() -> Void)? = nil
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.defaultLanguage.rawValue
    @State private var sessionType: String = "video"
    @State private var selectedSpecialist: DirectorySpecialist?
    @State private var selectedOrganization: DirectoryOrganization?
    @State private var scheduledAt = Date().addingTimeInterval(3600)
    @State private var notes: String = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var showSpecialistPicker = false
    @State private var showOrganizationPicker = false
    @State private var showDatePickerSheet = false
    @State private var recommendation: TriageInsight?
    @State private var recommendationError: String?
    @State private var recommendationLoading = false
    @State private var weeklyRecurring = false
    @State private var recurrenceCount = 4
    @State private var preSessionCompleted = true
    @State private var showPreSessionSurvey = false
    @State private var pendingBooking: PendingBooking?
    @State private var bookingAlert: BookingAlert?
    @State private var currentStep = 0
    @State private var showAdvancedOptions = false
    private let totalSteps = 4

    private struct BookingAlert: Identifiable {
        let id = UUID()
        let title: LocalizedStringKey
        let message: String
        let isSuccess: Bool
    }

    private struct PendingBooking {
        let type: String
        let specialistId: Int
        let organizationId: Int?
        let scheduledAt: Date
        let notes: String?
        let weeklyRecurring: Bool
        let recurrenceCount: Int?
    }

    private let service = SessionsService()
    private let dashboardService = DashboardService()
    private let preSessionService = PreSessionSurveyService()
    private let sessionTypeOptions: [SessionTypeOption] = [
        .init(id: "chat", label: "session_type_chat"),
        .init(id: "voice", label: "session_type_voice"),
        .init(id: "video", label: "session_type_video")
    ]

    init(selectedSpecialist: DirectorySpecialist? = nil, onCompleted: (() -> Void)? = nil) {
        _selectedSpecialist = State(initialValue: selectedSpecialist)
        self.onCompleted = onCompleted
    }

    var body: some View {
        NavigationView {
            ZStack {
                SanadTheme.surface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        SanadHeroHeader(title: "book_session_title", subtitle: stepSubtitle)

                        VStack(spacing: 20) {
                            stepProgressBar
                            stepContent
                            if let errorText = errorMessage {
                                SanadInlineBanner(errorText, style: .error)
                            }
                            wizardFooter
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 40)
                    }
                }
                if isSubmitting {
                    submittingOverlay
                }
            }
            .navigationBarHidden(true)
            .overlay(alignment: .topTrailing) {
                Button("common_close") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SanadTheme.onPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 52)
            }
        }
        .sheet(isPresented: $showSpecialistPicker) {
            SpecialistPickerView(selectedSpecialist: $selectedSpecialist)
        }
        .sheet(isPresented: $showOrganizationPicker) {
            OrganizationPickerView(selectedOrganization: $selectedOrganization)
        }
        .sheet(isPresented: $showDatePickerSheet) {
            NavigationView {
                Form {
                    DatePicker(
                        "book_session_date_time",
                        selection: $scheduledAt,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                        .datePickerStyle(.graphical)
                        .environment(\.locale, Locale(identifier: appLanguage))
                }
                .navigationTitle("book_session_date_title")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("common_save") { showDatePickerSheet = false }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common_cancel") { showDatePickerSheet = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showPreSessionSurvey) {
            PreSessionSurveyView {
                preSessionCompleted = true
                if let pending = pendingBooking {
                    pendingBooking = nil
                    Task { await createBooking(pending) }
                }
            }
        }
        .task { await loadRecommendation() }
        .alert(item: $bookingAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("common_ok")) {
                    if alert.isSuccess {
                        onCompleted?()
                        dismiss()
                    }
                }
            )
        }
    }

    @ViewBuilder
    private var recommendationSection: some View {
        if recommendationLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        } else if let insight = recommendation {
            SanadListCard {
                VStack(alignment: .trailing, spacing: 10) {
                    HStack {
                        VStack(alignment: .trailing, spacing: 6) {
                            Text("book_session_recommended_specialist")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(SanadTheme.placeholder)
                            Text(insight.recommendedSpecialist)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(SanadTheme.onBg)
                        }
                        Spacer()
                        Capsule()
                            .fill(SanadTheme.primary.opacity(0.15))
                            .frame(width: 80, height: 32)
                            .overlay(
                                Text(insight.category)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(SanadTheme.primary)
                            )
                    }
                    Text(insight.reasoning)
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } else if let error = recommendationError {
            Text(error)
                .font(.system(size: 13))
                .foregroundColor(SanadTheme.error)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            EmptyView()
        }
    }

    private var stepSubtitle: LocalizedStringKey {
        switch currentStep {
        case 0: return "book_step_type"
        case 1: return "book_step_specialist"
        case 2: return "book_step_time"
        default: return "book_step_review"
        }
    }

    private var stepProgressBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(format: NSLocalizedString("book_step_progress", comment: ""), currentStep + 1, totalSteps))
                .font(SanadFont.caption(12))
                .foregroundColor(SanadTheme.placeholder)
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentStep ? SanadTheme.primary : SanadTheme.fieldStroke)
                        .frame(height: 6)
                }
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0: stepTypeCard
        case 1: stepSpecialistCard
        case 2: stepTimeCard
        default: stepReviewCard
        }
    }

    private var stepTypeCard: some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("book_session_type")
                    .font(SanadFont.bodyMedium(16))
                    .foregroundColor(SanadTheme.onBg)
                ForEach(sessionTypeOptions) { option in
                    Button {
                        sessionType = option.id
                    } label: {
                        HStack(spacing: 12) {
                            typeIcon(for: option.id)
                                .foregroundColor(sessionType == option.id ? SanadTheme.primary : SanadTheme.placeholder)
                            Text(option.label)
                                .font(SanadFont.bodyMedium(15))
                                .foregroundColor(SanadTheme.onBg)
                            Spacer()
                            if sessionType == option.id {
                                SanadIcon.accept.view(size: 18)
                                    .foregroundColor(SanadTheme.primary)
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(sessionType == option.id ? SanadTheme.primary.opacity(0.08) : SanadTheme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(sessionType == option.id ? SanadTheme.primary.opacity(0.45) : SanadTheme.fieldStroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var stepSpecialistCard: some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    showSpecialistPicker = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("book_session_specialist")
                                .font(SanadFont.caption(12))
                                .foregroundColor(SanadTheme.placeholder)
                            Text(selectedSpecialist?.name ?? NSLocalizedString("book_session_specialist_placeholder", comment: ""))
                                .font(SanadFont.bodyMedium(16))
                                .foregroundColor(SanadTheme.onBg)
                        }
                        Spacer()
                        SanadIcon.chevronRight.view(size: 14)
                            .foregroundColor(SanadTheme.placeholder)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).stroke(SanadTheme.fieldStroke))
                }
                .buttonStyle(.plain)

                DisclosureGroup(isExpanded: $showAdvancedOptions) {
                    HStack(spacing: 10) {
                        Button {
                            showOrganizationPicker = true
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("book_session_org_optional")
                                    .font(SanadFont.caption(12))
                                    .foregroundColor(SanadTheme.placeholder)
                                Text(selectedOrganization?.name ?? NSLocalizedString("book_session_org_placeholder", comment: ""))
                                    .font(SanadFont.bodyMedium(15))
                                    .foregroundColor(SanadTheme.onBg)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14).stroke(SanadTheme.fieldStroke))
                        }
                        .buttonStyle(.plain)
                        if selectedOrganization != nil {
                            Button { selectedOrganization = nil } label: {
                                SanadIcon.reject.view(size: 20)
                                    .foregroundColor(SanadTheme.placeholder)
                            }
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("book_advanced_options")
                        .font(SanadFont.bodyMedium(13))
                        .foregroundColor(SanadTheme.primary)
                }
            }
        }
    }

    private var stepTimeCard: some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    showDatePickerSheet = true
                } label: {
                    HStack {
                        SanadIcon.calendar.view(size: 22)
                            .foregroundColor(SanadTheme.primary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("book_session_date_label")
                                .font(SanadFont.caption(12))
                                .foregroundColor(SanadTheme.placeholder)
                            Text(dateDisplayText())
                                .font(SanadFont.bodyMedium(15))
                                .foregroundColor(SanadTheme.onBg)
                        }
                        Spacer()
                        SanadIcon.chevronRight.view(size: 14)
                            .foregroundColor(SanadTheme.placeholder)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).stroke(SanadTheme.fieldStroke))
                }
                .buttonStyle(.plain)

                DisclosureGroup {
                    Toggle("book_session_weekly_recurring", isOn: $weeklyRecurring)
                        .font(SanadFont.bodyMedium(14))
                    if weeklyRecurring {
                        Stepper(value: $recurrenceCount, in: 2...52) {
                            Text(String(format: NSLocalizedString("book_session_recurrence_count", comment: ""), recurrenceCount))
                                .font(SanadFont.caption(13))
                                .foregroundColor(SanadTheme.placeholder)
                        }
                    }
                } label: {
                    Text("book_advanced_options")
                        .font(SanadFont.bodyMedium(13))
                        .foregroundColor(SanadTheme.primary)
                }
            }
        }
    }

    private var stepReviewCard: some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("book_review_summary")
                    .font(SanadFont.bodyMedium(16))
                    .foregroundColor(SanadTheme.onBg)
                reviewRow(title: NSLocalizedString("book_step_type", comment: ""), value: NSLocalizedString(sessionTypeLabelKey, comment: ""))
                reviewRow(title: NSLocalizedString("book_step_specialist", comment: ""), value: selectedSpecialist?.name ?? "—")
                if let org = selectedOrganization?.name {
                    reviewProp(title: NSLocalizedString("book_session_org_optional", comment: ""), value: org)
                }
                reviewProp(title: NSLocalizedString("book_step_time", comment: ""), value: dateDisplayText())
                VStack(alignment: .leading, spacing: 6) {
                    Text("book_session_notes")
                        .font(SanadFont.caption(12))
                        .foregroundColor(SanadTheme.placeholder)
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 14).stroke(SanadTheme.fieldStroke))
                }
            }
        }
    }

    private var sessionTypeLabelKey: String {
        switch sessionType {
        case "chat": return "session_type_chat"
        case "voice": return "session_type_voice"
        default: return "session_type_video"
        }
    }

    private func reviewProp(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(SanadFont.caption(12))
                .foregroundColor(SanadTheme.placeholder)
            Text(value)
                .font(SanadFont.bodyMedium(15))
                .foregroundColor(SanadTheme.onBg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func typeIcon(for id: String) -> some View {
        switch id {
        case "chat": return AnyView(SanadIcon.chat.view(size: 22))
        case "voice": return AnyView(SanadIcon.mic.view(size: 22))
        default: return AnyView(SanadIcon.cam.view(size: 22))
        }
    }

    private var wizardFooter: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button("book_step_back") {
                    withAnimation(.easeInOut(duration: 0.2)) { currentStep -= 1 }
                }
                .font(SanadFont.bodyMedium(15))
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundColor(SanadTheme.primary)
                .background(Capsule().stroke(SanadTheme.primary, lineWidth: 1))
            }
            Button {
                if currentStep < totalSteps - 1 {
                    guard validateCurrentStep() else { return }
                    withAnimation(.easeInOut(duration: 0.2)) { currentStep += 1 }
                } else {
                    Task { await submitBooking() }
                }
            } label: {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                } else {
                    Text(currentStep < totalSteps - 1 ? LocalizedStringKey("book_step_next") : LocalizedStringKey("book_step_submit"))
                        .font(SanadFont.bodyMedium(16))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundColor(SanadTheme.onPrimary)
                }
            }
            .disabled(isSubmitting)
            .background(Capsule().fill(SanadTheme.primary))
        }
    }

    private func validateCurrentStep() -> Bool {
        resetError()
        switch currentStep {
        case 1:
            guard selectedSpecialist?.id != nil else {
                errorMessage = NSLocalizedString("book_session_select_specialist_error", comment: "")
                return false
            }
        case 2:
            if scheduledAt <= Date() {
                errorMessage = NSLocalizedString("book_session_error_past_datetime", comment: "")
                return false
            }
        default:
            break
        }
        return true
    }

    private var submittingOverlay: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .overlay(
                ProgressView("book_session_submitting")
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 16).fill(SanadTheme.primary))
                    .foregroundColor(.white)
            )
    }

    @MainActor
    private func loadRecommendation() async {
        guard let token = KeychainHelper.getToken() else { return }
        recommendationLoading = true
        recommendationError = nil
        defer { recommendationLoading = false }
        do {
            async let dashboardTask = dashboardService.load(token: token)
            async let surveyTask = preSessionService.fetch(token: token)
            let response = try await dashboardTask
            let survey = try? await surveyTask
            if let insight = TriageEvaluator.evaluate(intake: response.intake) {
                recommendation = insight
                sessionType = suggestedSessionType(for: insight.category)
            }
            preSessionCompleted = survey?.completed == true || response.intake?.pre_session_completed == true
        } catch {
            recommendationError = NSLocalizedString("book_session_recommendation_failed", comment: "")
        }
    }

    private func sessionTypeChip(option: SessionTypeOption) -> some View {
        Button {
            sessionType = option.id
        } label: {
            Text(option.label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(sessionType == option.id ? SanadTheme.onPrimary : SanadTheme.onBg)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(sessionType == option.id ? SanadTheme.primary : SanadTheme.card)
                )
                .overlay(
                    Capsule()
                        .stroke(SanadTheme.fieldStroke, lineWidth: sessionType == option.id ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func dateDisplayText() -> String {
        dateFormatter.string(from: scheduledAt)
    }

    private func suggestedSessionType(for category: String?) -> String {
        guard let lower = category?.lowercased() else { return "video" }
        switch lower {
        case let value where value.contains("bipolar") || value.contains("ثنائي"):
            return "video"
        case let value where value.contains("schizophrenia") || value.contains("فصام"):
            return "video"
        case let value where value.contains("children") || value.contains("أطفال"):
            return "video"
        case let value where value.contains("anxiety") || value.contains("قلق") || value.contains("depression") || value.contains("اكتئاب"):
            return "video"
        case let value where value.contains("identity") || value.contains("هوية"):
            return "voice"
        case let value where value.contains("mild") || value.contains("دعم"):
            return "chat"
        default:
            return "video"
        }
    }

    @MainActor
    private func submitBooking() async {
        resetError()
        guard KeychainHelper.getToken() != nil else {
            errorMessage = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        guard let specialistId = selectedSpecialist?.id else {
            errorMessage = NSLocalizedString("book_session_select_specialist_error", comment: "")
            return
        }
        if scheduledAt <= Date() {
            errorMessage = NSLocalizedString("book_session_error_past_datetime", comment: "")
            bookingAlert = BookingAlert(
                title: "book_session_alert_error_title",
                message: NSLocalizedString("book_session_error_past_datetime", comment: ""),
                isSuccess: false
            )
            return
        }
        let pending = PendingBooking(
            type: sessionType,
            specialistId: specialistId,
            organizationId: selectedOrganization?.id,
            scheduledAt: scheduledAt,
            notes: notes.isEmpty ? nil : notes,
            weeklyRecurring: weeklyRecurring,
            recurrenceCount: weeklyRecurring ? recurrenceCount : nil
        )
        if !preSessionCompleted {
            pendingBooking = pending
            showPreSessionSurvey = true
            return
        }
        await createBooking(pending)
    }

    @MainActor
    private func createBooking(_ pending: PendingBooking) async {
        guard let token = KeychainHelper.getToken() else {
            errorMessage = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await service.create(
                type: pending.type,
                specialistId: pending.specialistId,
                organizationId: pending.organizationId,
                scheduledAt: pending.scheduledAt,
                pointsCost: nil,
                notes: pending.notes,
                weeklyRecurring: pending.weeklyRecurring,
                recurrenceCount: pending.recurrenceCount,
                token: token
            )
            bookingAlert = BookingAlert(
                title: "book_session_alert_success_title",
                message: NSLocalizedString("book_session_success", comment: ""),
                isSuccess: true
            )
        } catch let error as SessionsService.BookingError {
            bookingAlert = BookingAlert(
                title: "book_session_alert_error_title",
                message: error.localizedDescription,
                isSuccess: false
            )
        } catch {
            bookingAlert = BookingAlert(
                title: "book_session_alert_error_title",
                message: NSLocalizedString("book_session_failed", comment: ""),
                isSuccess: false
            )
        }
    }

    private func resetError() {
        errorMessage = nil
    }

    private struct SessionTypeOption: Identifiable {
        let id: String
        let label: LocalizedStringKey
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLanguage)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

private struct OrganizationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedOrganization: DirectoryOrganization?
    @State private var organizations: [DirectoryOrganization] = []
    @State private var query: String = ""
    @State private var loading = false
    @State private var errorMessage: String?

    private let service = DirectoryService()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SanadSearchField(text: $query, prompt: "book_session_search_organization")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let errorText = errorMessage {
                    Text(errorText)
                        .foregroundColor(.red)
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if organizations.isEmpty {
                    SanadEmptyState(message: "common_no_results")
                        .padding()
                } else {
                    List {
                        Button {
                            selectedOrganization = nil
                            dismiss()
                        } label: {
                            HStack {
                                Text("book_session_org_none")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(SanadTheme.primary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        ForEach(organizations) { org in
                            Button {
                                selectedOrganization = org
                                dismiss()
                            } label: {
                                HStack {
                                    Text(org.name ?? NSLocalizedString("common_organization", comment: ""))
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(SanadTheme.onBg)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                Spacer()
            }
            .navigationTitle("book_session_pick_organization")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("book_session_org_clear") {
                        selectedOrganization = nil
                        dismiss()
                    }
                }
            }
            .background(SanadTheme.surface.ignoresSafeArea())
            .task { await load() }
            .refreshable { await load() }
            .onChange(of: query) { _ in
                Task { await load() }
            }
        }
    }

    @MainActor
    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            errorMessage = NSLocalizedString("error_not_logged_in", comment: "")
            organizations = []
            return
        }
        loading = true
        defer { loading = false }
        do {
            let data = try await service.organizations(query: query.isEmpty ? nil : query, token: token)
            organizations = data
            errorMessage = data.isEmpty ? NSLocalizedString("common_no_matching_results", comment: "") : nil
        } catch {
            errorMessage = NSLocalizedString("book_session_load_orgs_failed", comment: "")
            organizations = []
        }
    }
}

private struct SpecialistPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.defaultLanguage.rawValue
    @Binding var selectedSpecialist: DirectorySpecialist?
    @State private var specialists: [DirectorySpecialist] = []
    @State private var query: String = ""
    @State private var specialtyFilter: String = ""
    @State private var languageFilter: String = ""
    @State private var minRating: Double = 0
    @State private var specialtyOptions: [CatalogCaseType] = []
    @State private var loading = false
    @State private var errorMessage: String?

    private let service = DirectoryService()
    private let catalogService = CatalogService()
    private let languageOptions = ["", "ar", "en", "fr", "de", "tr"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SanadSearchField(text: $query, prompt: "book_session_search_specialist")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                filterBar
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let errorText = errorMessage {
                    Text(errorText)
                        .foregroundColor(.red)
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if specialists.isEmpty {
                    SanadEmptyState(message: "common_no_results")
                        .padding()
                } else {
                    List {
                        ForEach(specialists) { specialist in
                            Button {
                                selectedSpecialist = specialist
                                dismiss()
                            } label: {
                                SpecialistRow(specialist: specialist)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                Spacer()
            }
            .navigationTitle("book_session_pick_specialist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_close") { dismiss() }
                }
            }
            .background(SanadTheme.surface.ignoresSafeArea())
            .task { await loadCatalog(); await load() }
            .refreshable { await load() }
            .onChange(of: query) { _ in
                Task { await load() }
            }
            .onChange(of: specialtyFilter) { _ in
                Task { await load() }
            }
            .onChange(of: languageFilter) { _ in
                Task { await load() }
            }
            .onChange(of: minRating) { _ in
                Task { await load() }
            }
        }
    }

    private var filterBar: some View {
        VStack(spacing: 8) {
            if !specialtyOptions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(label: NSLocalizedString("directory_filter_all_specialties", comment: ""), selected: specialtyFilter.isEmpty) {
                            specialtyFilter = ""
                        }
                        ForEach(specialtyOptions) { option in
                            filterChip(label: option.label(for: appLanguage), selected: specialtyFilter == option.id) {
                                specialtyFilter = specialtyFilter == option.id ? "" : option.id
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            HStack(spacing: 8) {
                Picker("directory_filter_language", selection: $languageFilter) {
                    Text("directory_filter_all_languages").tag("")
                    ForEach(languageOptions.filter { !$0.isEmpty }, id: \.self) { code in
                        Text(localizedLanguage(code)).tag(code)
                    }
                }
                .pickerStyle(.menu)
                Spacer()
                if minRating > 0 {
                    Text(String(format: NSLocalizedString("directory_filter_min_rating", comment: ""), minRating))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
            }
            .padding(.horizontal, 16)
            Slider(value: $minRating, in: 0...5, step: 0.5)
                .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    private func filterChip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(selected ? SanadTheme.primary : SanadTheme.card))
                .foregroundColor(selected ? SanadTheme.onPrimary : SanadTheme.onBg)
        }
        .buttonStyle(.plain)
    }

    private func localizedLanguage(_ code: String) -> String {
        switch code {
        case "ar": return NSLocalizedString("language_ar", comment: "")
        case "en": return NSLocalizedString("language_en", comment: "")
        case "fr": return NSLocalizedString("language_fr", comment: "")
        case "de": return NSLocalizedString("language_de", comment: "")
        case "tr": return NSLocalizedString("language_tr", comment: "")
        default: return code
        }
    }

    @MainActor
    private func loadCatalog() async {
        guard let token = KeychainHelper.getToken() else { return }
        if let catalog = try? await catalogService.load(token: token) {
            specialtyOptions = catalog.case_types ?? []
        }
    }

    @MainActor
    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            errorMessage = NSLocalizedString("error_not_logged_in", comment: "")
            specialists = []
            return
        }
        loading = true
        defer { loading = false }
        do {
            let data = try await service.specialists(
                query: query.isEmpty ? nil : query,
                specialty: specialtyFilter.isEmpty ? nil : specialtyFilter,
                language: languageFilter.isEmpty ? nil : languageFilter,
                minRating: minRating > 0 ? minRating : nil,
                token: token
            )
            specialists = data
            errorMessage = data.isEmpty ? NSLocalizedString("common_no_matching_results", comment: "") : nil
        } catch {
            errorMessage = NSLocalizedString("book_session_load_specialists_failed", comment: "")
            specialists = []
        }
    }
}

private struct SpecialistRow: View {
    let specialist: DirectorySpecialist

    var body: some View {
        HStack(spacing: 14) {
            avatar
            VStack(alignment: .trailing, spacing: 4) {
                Text(specialist.name ?? NSLocalizedString("common_specialist", comment: ""))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                if let specialty = specialist.specialty, !specialty.isEmpty {
                    Text(specialty)
                        .font(.system(size: 13))
                        .foregroundColor(SanadTheme.placeholder)
                }
                if let meta = metaText {
                    Text(meta)
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
            }
            Spacer()
            if let rating = specialist.rating {
                Text(String(format: "%.1f", rating))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SanadTheme.primary)
            }
        }
        .padding(.vertical, 8)
    }

    private var avatar: some View {
        Group {
            if let url = URL(string: specialist.avatar ?? "") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(Circle())
        .background(Circle().fill(SanadTheme.card))
    }

    private var placeholder: some View {
        SanadIcon.profile.image
            .resizable()
            .scaledToFit()
            .padding(12)
            .foregroundColor(SanadTheme.placeholder)
    }

    private var metaText: String? {
        var parts: [String] = []
        if let years = specialist.yearsExperience {
            parts.append(String(format: NSLocalizedString("specialist_years_experience", comment: ""), years))
        }
        if let rating = specialist.rating {
            let ratingValue = String(format: "%.1f", rating)
            parts.append(String(format: NSLocalizedString("specialist_rating", comment: ""), ratingValue))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

#Preview {
    BookSessionView()
}
