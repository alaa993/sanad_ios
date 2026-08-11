import SwiftUI

struct PatientIntakeView: View {
    @Environment(\.dismiss) private var dismiss
    var onCompleted: (() -> Void)? = nil
    @State private var fullName = ""
    @State private var age = ""
    @State private var occupation = ""
    @State private var primaryIssue = ""
    @State private var issueDuration = ""
    @State private var severity = "mild"
    @State private var impact = "low"
    @State private var sessionMode = "video"
    @State private var symptoms: Set<String> = []
    @State private var triageTags: Set<String> = []
    @State private var benefitScore: Double = 50
    @State private var hasConsult = false
    @State private var consultNotes = ""
    @State private var notes = ""
    @State private var loading = false
    @State private var saving = false
    @State private var feedback: Feedback?

    private let service = PatientIntakeService()
    private let durationOptions: [(key: String, value: String)] = [
        ("intake_duration_lt_month", "lt_month"),
        ("intake_duration_1_3_months", "1_3_months"),
        ("intake_duration_3_6_months", "3_6_months"),
        ("intake_duration_gt_6_months", "gt_6_months")
    ]
    private let severityOptions: [(key: String, value: String)] = [
        ("intake_severity_mild", "mild"),
        ("intake_severity_moderate", "moderate"),
        ("intake_severity_severe", "severe")
    ]
    private let impactOptions: [(key: String, value: String)] = [
        ("intake_impact_low", "low"),
        ("intake_impact_medium", "medium"),
        ("intake_impact_high", "high")
    ]
    private let modeOptions: [(key: String, value: String)] = [
        ("intake_mode_video", "video"),
        ("intake_mode_voice", "voice"),
        ("intake_mode_chat", "chat"),
        ("intake_mode_text", "text")
    ]
    private let symptomOptions: [(key: String, value: String)] = [
        ("intake_symptom_anxiety", "anxiety"),
        ("intake_symptom_depression", "depression"),
        ("intake_symptom_stress", "stress"),
        ("intake_symptom_insomnia", "insomnia"),
        ("intake_symptom_fear", "fear"),
        ("intake_symptom_low_focus", "low_focus")
    ]
    private let triageOptions: [(key: String, value: String)] = [
        ("intake_case_bipolar", "bipolar"),
        ("intake_case_anx_dep", "anx_dep"),
        ("intake_case_schizophrenia", "schizophrenia"),
        ("intake_case_children", "children"),
        ("intake_case_mild", "mild"),
        ("intake_case_identity", "identity")
    ]
    private static let caseTypeValues: Set<String> = ["bipolar", "anx_dep", "schizophrenia", "children", "mild", "identity"]

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack { intakeContent }
            } else {
                NavigationView { intakeContent }
            }
        }
    }

    private var intakeContent: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    SanadHeroHeader(title: "intake_title")

                    VStack(spacing: 16) {
                    section(title: "intake_section_general") {
                        textField("intake_full_name", text: $fullName)
                        textField("intake_age", text: $age, keyboard: .numberPad)
                        textField("intake_occupation", text: $occupation)
                    }
                    section(title: "intake_section_current") {
                        Text("intake_primary_issue")
                            .font(.system(size: 13, weight: .medium))
                        TextEditor(text: $primaryIssue)
                            .frame(minHeight: 100)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(SanadTheme.fieldStroke))
                        Picker("intake_issue_duration", selection: $issueDuration) {
                            ForEach(durationOptions, id: \.value) { option in
                                Text(LocalizedStringKey(option.key)).tag(option.value)
                            }
                        }
                        .pickerStyle(.menu)
                        optionPicker(title: "intake_severity", options: severityOptions, selection: $severity)
                        optionPicker(title: "intake_impact", options: impactOptions, selection: $impact)
                        optionPicker(title: "intake_preferred_session", options: modeOptions, selection: $sessionMode)
                    }
                    section(title: "intake_section_risks") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("intake_indicators")
                                .font(.system(size: 13))
                                .foregroundColor(SanadTheme.placeholder)
                            FlowLayout(items: symptomOptions, selection: $symptoms)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("intake_case_types")
                                .font(.system(size: 13))
                                .foregroundColor(SanadTheme.placeholder)
                            FlowLayout(items: triageOptions, selection: $triageTags)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("intake_expected_benefit")
                                .font(.system(size: 13))
                                .foregroundColor(SanadTheme.placeholder)
                            Slider(value: $benefitScore, in: 0...100, step: 1) {
                                Text("intake_benefit")
                            }
                            Text("\(Int(benefitScore))%")
                                .font(.system(size: 12))
                                .foregroundColor(SanadTheme.placeholder)
                        }
                    }
                    section(title: "intake_section_previous_consult") {
                        Toggle("intake_previous_consult_question", isOn: $hasConsult)
                        if hasConsult {
                            TextEditor(text: $consultNotes)
                                .frame(minHeight: 80)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(SanadTheme.fieldStroke))
                        }
                    }
                    section(title: "intake_section_additional_notes") {
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(SanadTheme.fieldStroke))
                    }
                    Button(savedLabel) {
                        Task { await save() }
                    }
                    .disabled(saving)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(SanadTheme.primary))
                    .foregroundColor(SanadTheme.onPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
                }
            }
            if loading || saving {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.1, anchor: .center)
                        .tint(.white)
                    Text(progressMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 16).fill(SanadTheme.toastBackground))
                .padding(.horizontal, 48)
                .transition(.opacity)
            }
        }
        .alert(feedback?.title ?? "", isPresented: feedbackBinding) {
            Button("common_ok", role: .cancel) {
                feedback = nil
            }
        } message: {
            Text(feedback?.message ?? "")
        }
        .navigationBarHidden(true)
        .overlay(alignment: .topTrailing) {
            Button("common_close") { dismiss() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SanadTheme.onPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 52)
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .task { await load() }
    }

    private var savedLabel: String {
        saving ? NSLocalizedString("intake_saving", comment: "") : NSLocalizedString("intake_save", comment: "")
    }

    private func section<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        SanadListCard {
            VStack(alignment: .trailing, spacing: 12) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                content()
            }
        }
    }

    private func textField(_ title: LocalizedStringKey, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(SanadTheme.placeholder)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .keyboardType(keyboard)
        }
    }

    private func optionPicker(title: LocalizedStringKey, options: [(key: String, value: String)], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(SanadTheme.placeholder)
            Picker("", selection: selection) {
                ForEach(options, id: \.value) { option in
                    Text(LocalizedStringKey(option.key)).tag(option.value)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @MainActor
    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            showFeedback(.warning, message: NSLocalizedString("error_not_logged_in", comment: ""))
            return
        }
        loading = true
        defer { loading = false }
        do {
            let form = try await service.load(token: token)
            populate(from: form)
        } catch {
            showFeedback(.error, message: NSLocalizedString("intake_load_failed", comment: ""))
        }
    }

    private func populate(from form: PatientIntakeForm) {
        fullName = form.full_name ?? ""
        age = form.age.map(String.init) ?? ""
        occupation = form.occupation ?? ""
        primaryIssue = form.primary_issue ?? ""
        issueDuration = normalizeDuration(form.issue_duration)
        severity = form.severity_level ?? "mild"
        impact = form.impact_level ?? "low"
        sessionMode = form.preferred_session_mode ?? "video"
        let flags = form.risk_flags ?? []
        symptoms = Set(flags.compactMap(normalizeSymptom).filter { !Self.caseTypeValues.contains($0) })
        triageTags = Set(flags.filter { Self.caseTypeValues.contains($0) })
        benefitScore = Double(form.benefit_score ?? 50)
        hasConsult = form.previous_consult ?? false
        consultNotes = form.consult_notes ?? ""
        notes = form.notes ?? ""
    }

    private func normalizeDuration(_ raw: String?) -> String {
        let value = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        switch value.lowercased() {
        case "lt_month", "less_3", "less_3m", "< شهر", "less than a month":
            return "lt_month"
        case "1_3_months", "1_3", "1-3", "1-3 أشهر", "1-3 months":
            return "1_3_months"
        case "3_6_months", "3_6", "3-6", "3-6 أشهر", "3-6 months":
            return "3_6_months"
        case "gt_6_months", "more_3m", "more_year", "gt_6", "أكثر من 6 أشهر":
            return "gt_6_months"
        default:
            return value
        }
    }

    private func normalizeSymptom(_ raw: String) -> String? {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "anxiety", "قلق": return "anxiety"
        case "depression", "اكتئاب": return "depression"
        case "stress", "توتر": return "stress"
        case "insomnia", "أرق": return "insomnia"
        case "fear", "خوف": return "fear"
        case "low_focus", "ضعف تركيز": return "low_focus"
        case "behavior", "سلوكي": return "behavior"
        default:
            return Self.caseTypeValues.contains(raw) ? nil : raw
        }
    }

    @MainActor
    private func save() async {
        guard !saving else { return }
        guard let token = KeychainHelper.getToken() else {
            showFeedback(.error, message: NSLocalizedString("error_not_logged_in", comment: ""))
            return
        }
        guard validateForm() else { return }
        saving = true
        feedback = nil
        defer { saving = false }
        var form = PatientIntakeForm()
        form.full_name = fullName.trimmingCharacters(in: .whitespaces)
        form.age = Int(age)
        form.occupation = occupation.trimmingCharacters(in: .whitespaces)
        form.primary_issue = primaryIssue.trimmingCharacters(in: .whitespacesAndNewlines)
        form.issue_duration = issueDuration
        form.severity_level = severity
        form.impact_level = impact
        form.preferred_session_mode = sessionMode
        form.risk_flags = Array(symptoms.union(triageTags))
        form.benefit_score = Int(benefitScore)
        form.previous_consult = hasConsult
        form.consult_notes = consultNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        form.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await service.save(form, token: token)
            showFeedback(.success, message: NSLocalizedString("intake_save_success", comment: ""))
            onCompleted?()
            dismiss()
        } catch {
            showFeedback(.error, message: NSLocalizedString("intake_save_failed", comment: ""))
        }
    }

    private func validateForm() -> Bool {
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showFeedback(.warning, message: NSLocalizedString("intake_full_name_required", comment: ""))
            return false
        }
        let trimmedIssue = primaryIssue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIssue.isEmpty else {
            showFeedback(.warning, message: NSLocalizedString("intake_primary_issue_required", comment: ""))
            return false
        }
        return true
    }

    private var progressMessage: String {
        if loading {
            return NSLocalizedString("intake_loading", comment: "")
        }
        if saving {
            return NSLocalizedString("intake_saving", comment: "")
        }
        return ""
    }

    private var feedbackBinding: Binding<Bool> {
        Binding(
            get: { feedback != nil },
            set: { if !$0 { feedback = nil } }
        )
    }

    private func showFeedback(_ kind: Feedback.Kind, message: String) {
        feedback = Feedback(kind: kind, message: message)
    }

    private struct Feedback {
        enum Kind {
            case success
            case warning
            case error

            var title: String {
                switch self {
                case .success: return NSLocalizedString("common_success", comment: "")
                case .warning: return NSLocalizedString("common_warning", comment: "")
                case .error: return NSLocalizedString("common_error", comment: "")
            }
        }
        }

        let kind: Kind
        let message: String

        var title: String { kind.title }
    }
}

private struct FlowLayout: View {
    let items: [(key: String, value: String)]
    @Binding var selection: Set<String>

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(items, id: \.value) { item in
                Button(action: {
                    if selection.contains(item.value) {
                        selection.remove(item.value)
                    } else {
                        selection.insert(item.value)
                    }
                }) {
                    Text(LocalizedStringKey(item.key))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(selection.contains(item.value) ? SanadTheme.onPrimary : SanadTheme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selection.contains(item.value) ? SanadTheme.primary : Color.clear)
                        )
                        .overlay(
                            Capsule()
                                .stroke(selection.contains(item.value) ? Color.clear : SanadTheme.primary, lineWidth: 1)
                        )
                }
            }
        }
    }
}

#Preview { PatientIntakeView() }
