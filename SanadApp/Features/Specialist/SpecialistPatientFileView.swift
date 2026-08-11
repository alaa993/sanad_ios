import SwiftUI

struct SpecialistPatientFileView: View {
    let sessionId: Int
    let patientId: Int

    @State private var patients: [SpecialistPatientMini] = []
    @State private var intake: SpecialistPatientIntake?
    @State private var tasks: [SpecialistPatientTask] = []
    @State private var sessions: [SpecialistPatientSession] = []
    @State private var loading = true
    @State private var error: String?

    private let service = SpecialistService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(
                    title: LocalizedStringKey(displayName),
                    subtitle: "specialist_patient_file",
                    showsBackButton: true
                )

                VStack(alignment: .leading, spacing: 16) {
                    if loading { ProgressView().frame(maxWidth: .infinity) }
                    if let err = error { SanadInlineBanner(err, style: .error) }

                    if let intake {
                        intakeCard(intake)
                    }

                    if !tasks.isEmpty {
                        Text("tasks_title")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(SanadTheme.onBg)
                        ForEach(tasks) { task in
                            taskCard(task)
                        }
                    }

                    if !sessions.isEmpty {
                        Text("patient_session_history_title")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(SanadTheme.onBg)
                            .padding(.top, 4)

                        ForEach(sessions) { s in
                            SanadListCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("#\(s.id) — \(localizedStatus(s.status))")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(SanadTheme.onBg)
                                    if let date = s.starts_at {
                                        Text(formatDisplayDate(date))
                                            .font(.system(size: 12))
                                            .foregroundColor(SanadTheme.placeholder)
                                    }
                                    if let notes = s.specialist_notes, !notes.isEmpty {
                                        Text(notes).font(.system(size: 12)).foregroundColor(SanadTheme.onBg)
                                    }
                                    if let rating = s.rating {
                                        Text("★ \(rating)").font(.system(size: 12)).foregroundColor(SanadTheme.placeholder)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    } else if !loading && intake == nil {
                        SanadListCard {
                            SanadEmptyState(message: "specialist_patient_file_empty")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await load() }
        .refreshable { await load() }
    }

    private var displayName: String {
        if let name = intake?.full_name, !name.isEmpty { return name }
        return patients.first(where: { $0.id == patientId })?.name
            ?? patients.first?.name
            ?? NSLocalizedString("specialist_patient_file", comment: "")
    }

    private func intakeCard(_ intake: SpecialistPatientIntake) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: NSLocalizedString("specialist_patient_file_id", comment: ""), patientId))
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.placeholder)

                if let age = intake.age {
                    labeledRow("intake_age", value: "\(age)")
                }
                if let occupation = intake.occupation, !occupation.isEmpty {
                    labeledRow("intake_occupation", value: occupation)
                }
                if let issue = intake.primary_issue, !issue.isEmpty {
                    labeledRow("intake_primary_issue", value: issue)
                }
                if let duration = intake.issue_duration, !duration.isEmpty {
                    labeledRow("intake_issue_duration", value: localizedDuration(duration))
                }
                if let severity = intake.severity_level, !severity.isEmpty {
                    labeledRow("intake_severity", value: localizedSeverity(severity))
                }
                if let impact = intake.impact_level, !impact.isEmpty {
                    labeledRow("intake_impact", value: localizedImpact(impact))
                }
                if let symptoms = intake.symptoms, !symptoms.isEmpty {
                    labeledRow("intake_indicators", value: symptoms.map(localizedCatalogToken).joined(separator: " · "))
                }
                if let risks = intake.risk_flags, !risks.isEmpty {
                    labeledRow("home_intake_risk_label", value: risks.map(localizedCatalogToken).joined(separator: " · "))
                }
                if let category = intake.triage_category, !category.isEmpty {
                    labeledRow("patient_intake_triage", value: localizedCatalogToken(category))
                }
                if let benefit = intake.benefit_score {
                    labeledRow("intake_expected_benefit", value: "\(benefit)%")
                }
                if let notes = intake.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.onBg)
                }
                if intake.referral_physician_recommended == true {
                    Text("physician_referral_banner")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(SanadTheme.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func taskCard(_ task: SpecialistPatientTask) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
                if let due = task.due_at {
                    Text(String(format: NSLocalizedString("tasks_due", comment: ""), formatDisplayDate(due)))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
                Text(localizedStatus(task.status ?? "pending"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SanadTheme.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func labeledRow(_ titleKey: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(titleKey))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(SanadTheme.placeholder)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(SanadTheme.onBg)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    private func localizedDuration(_ raw: String) -> String {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let key: String
        switch normalized {
        case "less_3", "less_3m", "lt_month", "< شهر", "less than a month":
            key = "intake_duration_lt_month"
        case "1_3", "1-3", "1_3_months", "1-3 months", "1-3 أشهر":
            key = "intake_duration_1_3_months"
        case "3_6", "3-6", "3_6_months", "3-6 months", "3-6 أشهر":
            key = "intake_duration_3_6_months"
        case "more_3m", "more_year", "gt_6", "gt_6_months", ">6", "أكثر من 6 أشهر":
            key = "intake_duration_gt_6_months"
        default:
            return localizedCatalogToken(raw)
        }
        return NSLocalizedString(key, comment: "")
    }

    private func localizedSeverity(_ raw: String) -> String {
        let key = "intake_severity_\(raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
        let localized = NSLocalizedString(key, comment: "")
        return localized == key ? raw : localized
    }

    private func localizedImpact(_ raw: String) -> String {
        let key = "intake_impact_\(raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
        let localized = NSLocalizedString(key, comment: "")
        return localized == key ? raw : localized
    }

    private func localizedCatalogToken(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        let slug = trimmed
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .lowercased()

        let candidates = [
            "intake_symptom_\(slug)",
            "intake_case_\(slug)",
            "intake_risk_\(slug)",
            "intake_duration_\(slug)"
        ]
        for key in candidates {
            let value = NSLocalizedString(key, comment: "")
            if value != key { return value }
        }

        // Arabic labels already stored from older intake forms.
        let arabicKnown = ["قلق", "اكتئاب", "توتر", "أرق", "خوف", "ضعف تركيز"]
        if arabicKnown.contains(trimmed) { return trimmed }

        return trimmed
    }

    private func localizedStatus(_ raw: String?) -> String {
        let status = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let key = "session_status_\(status)"
        let localized = NSLocalizedString(key, comment: "")
        if localized != key { return localized }
        if status == "pending" {
            return NSLocalizedString("specialist_verification_pending", comment: "")
        }
        return raw?.isEmpty == false ? raw! : NSLocalizedString("specialist_verification_pending", comment: "")
    }

    private func formatDisplayDate(_ raw: String) -> String {
        guard let date = parseIsoDate(raw) else { return raw }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
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

    private func load() async {
        guard let token = KeychainHelper.getToken() else { return }
        loading = true
        defer { loading = false }
        do {
            async let list = service.patients(token: token)
            async let history = service.patientSessions(patientId: patientId, token: token)
            async let intakeData = service.patientIntake(patientId: patientId, token: token)
            async let taskData = service.patientTasks(patientId: patientId, token: token)
            let (p, h, i, t) = try await (list, history, intakeData, taskData)
            await MainActor.run {
                patients = p
                sessions = h
                intake = i
                tasks = t
                error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("specialist_dashboard_load_failed", comment: "") }
        }
    }
}
