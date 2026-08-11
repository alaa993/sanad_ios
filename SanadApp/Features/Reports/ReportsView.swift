import SwiftUI
import UIKit

struct ReportsView: View {
    @State private var overview: ReportsOverview?
    @State private var period: ReportsPeriod?
    @State private var topSpecialists: [ReportsTopEntry] = []
    @State private var topOrganizations: [ReportsTopEntry] = []
    @State private var conversion: [ReportsFunnelStage] = []
    @State private var retention: [ReportsRetentionRow] = []
    @State private var sessionsSeries: [ReportsSeriesPoint] = []
    @State private var surveySummary: ReportsSurveySummary?
    @State private var loading = false
    @State private var error: String?
    @State private var exportMessage: String?

    private let service = ReportsService()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    SanadHeroHeader(title: "reports_title")

                    VStack(alignment: .leading, spacing: 14) {
                        if let period {
                            Text(String(format: NSLocalizedString("org_reports_period", comment: ""), period.from ?? "—", period.to ?? "—"))
                                .font(.system(size: 12))
                                .foregroundColor(SanadTheme.placeholder)
                        }

                        if let err = error {
                            Text(err)
                                .foregroundColor(SanadTheme.error)
                                .font(.system(size: 13))
                        }

                        if loading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }

                        statsCard
                        surveyCard
                        conversionCard
                        topListCard(title: "reports_specialists", items: topSpecialists)
                        topListCard(title: "reports_organizations", items: topOrganizations)
                        retentionCard
                        seriesCard(title: "reports_sessions", points: sessionsSeries)

                        Button {
                            Task { await exportCSV() }
                        } label: {
                            Text("reports_export_csv")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Capsule().stroke(SanadTheme.primary, lineWidth: 1))
                                .foregroundColor(SanadTheme.primary)
                        }

                        if let exportMessage {
                            Text(exportMessage)
                                .font(.system(size: 12))
                                .foregroundColor(SanadTheme.primary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
            }
            .background(SanadTheme.surface.ignoresSafeArea())
            .navigationBarHidden(true)
            .task { await loadReports() }
            .refreshable { await loadReports() }
        }
    }

    private var statsCard: some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    statBlock(title: "reports_users", value: "\(overview?.users ?? 0)")
                    statBlock(title: "reports_sessions", value: "\(overview?.sessions ?? 0)")
                }
                HStack {
                    statBlock(title: "reports_revenue", value: "\(overview?.revenue ?? 0)")
                    statBlock(title: "reports_avg_rating", value: overview?.avgRating.map { String(format: "%.1f", $0) } ?? "—")
                }
                if let rate = overview?.surveyResponseRate {
                    statBlock(title: "reports_survey_rate", value: String(format: "%.0f%%", rate))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var surveyCard: some View {
        if let survey = surveySummary {
            SanadListCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("reports_survey_section")
                        .font(.system(size: 15, weight: .semibold))
                    statBlock(title: "reports_survey_completed", value: "\(survey.completed_sessions ?? 0)")
                    statBlock(title: "reports_survey_responses", value: "\(survey.survey_responses ?? 0)")
                    if let avg = survey.avg_score {
                        statBlock(title: "reports_avg_rating", value: String(format: "%.1f", avg))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var conversionCard: some View {
        if !conversion.isEmpty {
            SanadListCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("reports_conversion_title")
                        .font(.system(size: 15, weight: .semibold))
                    ForEach(conversion) { stage in
                        HStack {
                            Text(localizedStage(stage.stage))
                                .font(.system(size: 13))
                            Spacer()
                            Text("\(stage.value ?? 0)")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func topListCard(title: LocalizedStringKey, items: [ReportsTopEntry]) -> some View {
        if !items.isEmpty {
            SanadListCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                    ForEach(items.prefix(5)) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? "—")
                                    .font(.system(size: 14, weight: .medium))
                                if let specialty = item.specialty, !specialty.isEmpty {
                                    Text(specialty)
                                        .font(.system(size: 11))
                                        .foregroundColor(SanadTheme.placeholder)
                                }
                            }
                            Spacer()
                            Text("\(Int(item.sessions ?? 0))")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var retentionCard: some View {
        if !retention.isEmpty {
            SanadListCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("reports_retention_title")
                        .font(.system(size: 15, weight: .semibold))
                    ForEach(retention.prefix(5)) { row in
                        HStack {
                            Text(row.week ?? "—")
                                .font(.system(size: 12))
                            Spacer()
                            Text("\(row.retained ?? 0)/\(row.users ?? 0)")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func seriesCard(title: LocalizedStringKey, points: [ReportsSeriesPoint]) -> some View {
        if !points.isEmpty {
            SanadListCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                    ForEach(points.suffix(7)) { point in
                        HStack {
                            Text(point.d ?? "—")
                                .font(.system(size: 12))
                            Spacer()
                            Text("\(Int(point.v ?? 0))")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                }
            }
        }
    }

    private func statBlock(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(SanadTheme.placeholder)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func localizedStage(_ raw: String?) -> String {
        switch raw {
        case "signup": return NSLocalizedString("reports_stage_signup", comment: "")
        case "first_session": return NSLocalizedString("reports_stage_first_session", comment: "")
        case "paid_user": return NSLocalizedString("reports_stage_paid", comment: "")
        default: return raw ?? "—"
        }
    }

    private func exportCSV() async {
        guard let token = KeychainHelper.getToken(),
              let url = service.exportCSVURL(from: period?.from, to: period?.to, token: token) else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                await MainActor.run { exportMessage = NSLocalizedString("reports_export_failed", comment: "") }
                return
            }
            let path = FileManager.default.temporaryDirectory.appendingPathComponent("sanad_reports.csv")
            try data.write(to: path)
            await MainActor.run {
                exportMessage = NSLocalizedString("reports_export_ready", comment: "")
            }
            await MainActor.run {
                let av = UIActivityViewController(activityItems: [path], applicationActivities: nil)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let root = scene.windows.first?.rootViewController {
                    root.present(av, animated: true)
                }
            }
        } catch {
            await MainActor.run { exportMessage = NSLocalizedString("reports_export_failed", comment: "") }
        }
    }

    private func loadReports() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        defer { loading = false }
        do {
            async let overviewTask = service.overview(token: token)
            async let specialistsTask = service.topSpecialists(token: token)
            async let orgsTask = service.topOrganizations(token: token)
            async let conversionTask = service.conversion(token: token)
            async let retentionTask = service.retention(token: token)
            async let sessionsTask = service.sessionsSeries(token: token)
            async let surveyTask = service.surveySummary(token: token)

            let (ov, p) = try await overviewTask
            let specialists = (try? await specialistsTask) ?? []
            let orgs = (try? await orgsTask) ?? []
            let funnel = (try? await conversionTask) ?? []
            let retain = (try? await retentionTask) ?? []
            let series = (try? await sessionsTask) ?? []
            let survey = try? await surveyTask

            await MainActor.run {
                overview = ov
                period = p
                topSpecialists = specialists
                topOrganizations = orgs
                conversion = funnel
                retention = retain
                sessionsSeries = series
                surveySummary = survey
                error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("reports_load_failed", comment: "") }
        }
    }
}
