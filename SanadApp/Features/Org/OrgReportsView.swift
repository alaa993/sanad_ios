import SwiftUI

struct OrgReportsView: View {
    @State private var summary: OrgReportSummary?
    @State private var error: String?
    @State private var loading = false

    private let service = OrgService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "org_reports_title")

                VStack(alignment: .leading, spacing: 14) {
                    if loading && summary == nil {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                    } else if let err = error {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.error)
                    } else {
                        if let period = summary?.period {
                            Text(String(format: NSLocalizedString("org_reports_period", comment: ""), period.from ?? "--", period.to ?? "--"))
                                .font(.system(size: 12))
                                .foregroundColor(SanadTheme.placeholder)
                        }

                        metricsGrid()
                        topBeneficiaries()
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
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        do {
            let res = try await service.reportsSummary(token: token)
            await MainActor.run {
                self.summary = res
                self.error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("org_reports_load_failed", comment: "") }
        }
        loading = false
    }

    @ViewBuilder
    private func metricsGrid() -> some View {
        let metrics = summary?.metrics
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                metricCard("org_reports_beneficiaries", metrics?.beneficiaries_total ?? 0)
                metricCard("org_reports_active", metrics?.beneficiaries_active ?? 0)
            }
            HStack(spacing: 12) {
                metricCard("org_reports_high_risk", metrics?.high_risk_cases ?? 0)
                metricCard("org_reports_sessions_completed", metrics?.sessions_completed ?? 0)
            }
            HStack(spacing: 12) {
                metricCard("org_reports_sessions_cancelled", metrics?.sessions_cancelled ?? 0)
                metricCard("org_reports_upcoming_week", metrics?.sessions_upcoming_week ?? 0)
            }
        }
    }

    private func metricCard(_ title: LocalizedStringKey, _ value: Int) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SanadTheme.placeholder)
                Text("\(value)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func topBeneficiaries() -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("org_reports_top_need")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SanadTheme.onBg)
                let list = summary?.top_beneficiaries ?? []
                if list.isEmpty {
                    SanadEmptyState(message: "org_reports_no_data")
                } else {
                    ForEach(list) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name ?? NSLocalizedString("role_patient", comment: ""))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(SanadTheme.onBg)
                            if let risk = item.risk_level {
                                Text(String(format: NSLocalizedString("org_beneficiaries_risk", comment: ""), risk))
                                    .font(.system(size: 12))
                                    .foregroundColor(SanadTheme.placeholder)
                            }
                        }
                        if item.id != list.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

#Preview { NavigationView { OrgReportsView() } }
