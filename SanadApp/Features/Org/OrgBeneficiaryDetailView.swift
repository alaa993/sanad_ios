import SwiftUI

struct OrgBeneficiaryDetailView: View {
    let beneficiaryId: Int
    let beneficiaryName: String?

    @State private var detail: OrgBeneficiaryDetail?
    @State private var specialists: [OrgSpecialist] = []
    @State private var error: String?
    @State private var showAssign = false
    @State private var selectedSpecialistId = 0

    private let service = OrgService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(
                    title: LocalizedStringKey(beneficiaryName ?? NSLocalizedString("org_beneficiary_detail_title", comment: "")),
                    subtitle: "org_beneficiary_detail_title"
                )

                VStack(alignment: .leading, spacing: 14) {
                    if let err = error {
                        Text(err).foregroundColor(SanadTheme.error)
                    }

                    if let status = detail?.data?.beneficiary?.status {
                        SanadListCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(format: NSLocalizedString("org_beneficiaries_status", comment: ""), status))
                                    .font(.system(size: 12))
                                    .foregroundColor(SanadTheme.placeholder)
                                if let risk = detail?.data?.beneficiary?.risk_level {
                                    Text(String(format: NSLocalizedString("org_beneficiaries_risk", comment: ""), risk))
                                        .font(.system(size: 12))
                                        .foregroundColor(SanadTheme.placeholder)
                                }
                                if let issue = detail?.data?.beneficiary?.primary_issue {
                                    Text(String(format: NSLocalizedString("org_beneficiary_primary_issue", comment: ""), issue))
                                        .font(.system(size: 12))
                                        .foregroundColor(SanadTheme.placeholder)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Button("org_beneficiary_assign_specialist") {
                        showAssign = true
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().stroke(SanadTheme.primary, lineWidth: 1))
                    .foregroundColor(SanadTheme.primary)

                    patientCard()
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
        .sheet(isPresented: $showAssign) { assignSheet }
    }

    private var assignSheet: some View {
        NavigationView {
            Form {
                Picker("org_beneficiary_pick_specialist", selection: $selectedSpecialistId) {
                    Text("—").tag(0)
                    ForEach(specialists) { spec in
                        Text(spec.name ?? "—").tag(spec.id)
                    }
                }
            }
            .navigationTitle("org_beneficiary_assign_specialist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_cancel") { showAssign = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common_save") { Task { await assign() } }
                }
            }
            .task {
                guard let token = KeychainHelper.getToken() else { return }
                specialists = (try? await service.specialists(token: token)) ?? []
                if selectedSpecialistId == 0, let first = specialists.first {
                    selectedSpecialistId = first.id
                }
            }
        }
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        do {
            let res = try await service.beneficiaryDetail(id: beneficiaryId, token: token)
            await MainActor.run {
                self.detail = res
                self.error = nil
                if let sid = res.data?.assigned_specialist?.id {
                    selectedSpecialistId = sid
                }
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("org_beneficiary_detail_load_failed", comment: "") }
        }
    }

    private func assign() async {
        guard let token = KeychainHelper.getToken(), selectedSpecialistId > 0 else { return }
        do {
            try await service.assignSpecialist(beneficiaryId: beneficiaryId, specialistId: selectedSpecialistId, token: token)
            showAssign = false
            await load()
        } catch {
            await MainActor.run { self.error = NSLocalizedString("org_beneficiary_detail_load_failed", comment: "") }
        }
    }

    @ViewBuilder
    private func patientCard() -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("org_beneficiary_detail_info")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SanadTheme.placeholder)
                Text(detail?.data?.patient?.name ?? NSLocalizedString("profile_not_available", comment: ""))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                if let email = detail?.data?.patient?.email {
                    Text(email)
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
                if let specialist = detail?.data?.assigned_specialist?.name {
                    Text(String(format: NSLocalizedString("org_beneficiaries_specialist", comment: ""), specialist))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                } else {
                    Text("org_beneficiary_no_specialist")
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func sessionsCard() -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("org_beneficiary_detail_sessions")
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
