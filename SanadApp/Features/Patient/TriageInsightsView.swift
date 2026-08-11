import SwiftUI

struct TriageInsightsView: View {
    let initialIntake: DashboardIntake?

    @State private var insight: TriageInsight?
    @State private var loading = false
    @State private var error: String?

    private let service = DashboardService()

    init(initialIntake: DashboardIntake? = nil) {
        self.initialIntake = initialIntake
        _insight = State(initialValue: TriageEvaluator.evaluate(intake: initialIntake))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("triage_title")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                if loading {
                    HStack {
                        ProgressView()
                        Text("triage_loading")
                            .foregroundColor(SanadTheme.placeholder)
                    }
                } else if let insight = insight {
                    insightCard(insight)
                } else {
                    Text(error ?? NSLocalizedString("triage_no_data", comment: ""))
                        .foregroundColor(SanadTheme.placeholder)
                        .font(.system(size: 14))
                }
                NavigationLink(destination: PatientIntakeView()) {
                    Label { Text("triage_update_intake") } icon: { SanadIcon.tasks.image }
                        .font(.system(size: 14, weight: .semibold))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 16).fill(SanadTheme.primary))
                        .foregroundColor(SanadTheme.onPrimary)
                }
                Button(action: { Task { await load() } }) {
                    Text("triage_refresh")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(SanadTheme.primary)
                }
            }
            .padding(20)
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationTitle("triage_nav_title")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func insightCard(_ insight: TriageInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(insight.category)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(SanadTheme.onBg)
            HStack {
                Text("triage_recommended_specialist")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SanadTheme.placeholder)
                Text(insight.recommendedSpecialist)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
            }
            Text(insight.reasoning)
                .font(.system(size: 13))
                .foregroundColor(SanadTheme.placeholder)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(SanadTheme.card))
        .shadow(color: SanadTheme.subtleShadow, radius: 4, y: 2)
    }

    @MainActor
    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_login_first", comment: "")
            insight = nil
            return
        }
        loading = true
        defer { loading = false }
        do {
            let dashboard = try await service.load(token: token)
            insight = TriageEvaluator.evaluate(intake: dashboard.intake)
            if insight == nil {
                error = NSLocalizedString("triage_no_signals", comment: "")
            } else {
                error = nil
            }
        } catch {
            self.error = NSLocalizedString("triage_load_failed", comment: "")
            insight = nil
        }
    }
}

extension TriageInsightsView {
    #if DEBUG
    struct TriageInsightsView_Previews: PreviewProvider {
        static var previews: some View {
            NavigationView {
                TriageInsightsView(initialIntake: nil)
            }
        }
    }
    #endif
}
