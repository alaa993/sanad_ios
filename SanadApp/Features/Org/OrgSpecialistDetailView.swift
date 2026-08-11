import SwiftUI

struct OrgSpecialistDetailView: View {
    let specialistId: Int
    let specialistName: String?

    @State private var detail: OrgSpecialistDetail?
    @State private var error: String?

    private let service = OrgService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(
                    title: LocalizedStringKey(specialistName ?? NSLocalizedString("org_specialist_detail_title", comment: "")),
                    subtitle: "org_specialist_detail_title"
                )

                VStack(alignment: .leading, spacing: 14) {
                    if let err = error {
                        Text(err).foregroundColor(SanadTheme.error)
                    }

                    if let email = detail?.data?.specialist?.email {
                        Text(email)
                            .font(.system(size: 12))
                            .foregroundColor(SanadTheme.placeholder)
                    }

                    statsCard()
                    beneficiariesCard()
                    sessionsCard()
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
        do {
            let res = try await service.specialistDetail(id: specialistId, token: token)
            await MainActor.run {
                self.detail = res
                self.error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("org_specialist_detail_load_failed", comment: "") }
        }
    }

    @ViewBuilder
    private func statsCard() -> some View {
        let stats = detail?.data?.stats
        SanadListCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("org_specialist_detail_stats")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SanadTheme.placeholder)
                Text(String(format: NSLocalizedString("org_specialist_detail_sessions_count", comment: ""), stats?.sessions_count ?? 0))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
                if let rate = stats?.commitment_rate {
                    Text(String(format: NSLocalizedString("org_specialist_detail_commitment", comment: ""), String(format: "%.1f", rate)))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
                if let next = stats?.next_session_at {
                    Text(String(format: NSLocalizedString("org_specialist_detail_next_session", comment: ""), next))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func beneficiariesCard() -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("org_specialist_detail_beneficiaries")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SanadTheme.placeholder)
                let list = detail?.data?.beneficiaries ?? []
                if list.isEmpty {
                    SanadEmptyState(message: "org_specialist_detail_no_data")
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
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(SanadTheme.surfaceAlt))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func sessionsCard() -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("org_specialist_detail_sessions")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SanadTheme.placeholder)
                let list = detail?.data?.sessions ?? []
                if list.isEmpty {
                    SanadEmptyState(message: "org_beneficiary_detail_no_sessions")
                } else {
                    ForEach(list) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: NSLocalizedString("org_beneficiary_detail_session_id", comment: ""), session.id))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(SanadTheme.onBg)
                            if let status = session.status {
                                Text(String(format: NSLocalizedString("org_beneficiaries_status", comment: ""), status))
                                    .font(.system(size: 12))
                                    .foregroundColor(SanadTheme.placeholder)
                            }
                            if let start = session.starts_at {
                                Text(start)
                                    .font(.system(size: 12))
                                    .foregroundColor(SanadTheme.placeholder)
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(SanadTheme.surfaceAlt))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview { NavigationView { OrgSpecialistDetailView(specialistId: 1, specialistName: "Specialist") } }
