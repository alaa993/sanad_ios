import SwiftUI

struct AdminOrganizationDetailView: View {
    let orgId: Int
    let orgName: String?

    @State private var detail: AdminOrganizationDetail?
    @State private var error: String?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showRejectSheet = false
    @State private var rejectReason = ""

    private let service = AdminService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let err = error {
                    Text(err).foregroundColor(.red)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(orgName ?? NSLocalizedString("admin_org_detail_title", comment: ""))
                        .font(.system(size: 20, weight: .semibold))
                    if let name = detail?.data?.organization?.name {
                        Text(name)
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.placeholder)
                    }
                    if let status = detail?.data?.organization?.status {
                        Text(String(format: NSLocalizedString("admin_org_status", comment: ""), status))
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.placeholder)
                    }
                }

                statsGrid()

                HStack(spacing: 10) {
                    Button("admin_org_approve") {
                        Task { await approve() }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                    .foregroundColor(SanadTheme.primary)

                    Button("admin_org_reject") {
                        rejectReason = ""
                        showRejectSheet = true
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(SanadTheme.error.opacity(0.12)))
                    .foregroundColor(SanadTheme.error)
                }
            }
            .padding(20)
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationTitle("admin_org_detail_title")
        .task { await load() }
        .refreshable { await load() }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("common_ok", role: .cancel) {}
        }
        .sheet(isPresented: $showRejectSheet) {
            NavigationView {
                Form {
                    TextField("admin_reject_reason_hint", text: $rejectReason, axis: .vertical)
                }
                .navigationTitle("admin_reject_title")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common_cancel") { showRejectSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("admin_org_reject") {
                            Task { await reject() }
                        }
                    }
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
            let res = try await service.organizationDetail(id: orgId, token: token)
            await MainActor.run {
                self.detail = res
                self.error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("admin_org_detail_load_failed", comment: "") }
        }
    }

    private func approve() async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await service.approveOrganization(id: orgId, token: token)
            await load()
        } catch {
            alertMessage = NSLocalizedString("admin_org_action_failed", comment: "")
            showAlert = true
        }
    }

    private func reject() async {
        guard let token = KeychainHelper.getToken() else { return }
        let reason = rejectReason.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await service.rejectOrganization(id: orgId, reason: reason.isEmpty ? nil : reason, token: token)
            showRejectSheet = false
            rejectReason = ""
            await load()
        } catch {
            alertMessage = NSLocalizedString("admin_org_action_failed", comment: "")
            showAlert = true
        }
    }

    @ViewBuilder
    private func statsGrid() -> some View {
        let stats = detail?.data?.stats
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                statCard(title: "admin_org_detail_members", value: stats?.members ?? 0)
                statCard(title: "admin_org_detail_specialists", value: stats?.specialists ?? 0)
            }
            HStack(spacing: 12) {
                statCard(title: "admin_org_detail_beneficiaries", value: stats?.beneficiaries ?? 0)
                statCard(title: "admin_org_detail_sessions", value: stats?.sessions_total ?? 0)
            }
            statCard(title: "admin_org_detail_upcoming", value: stats?.upcoming ?? 0)
        }
    }

    private func statCard(title: LocalizedStringKey, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(SanadTheme.placeholder)
            Text("\(value)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(SanadTheme.card))
        .shadow(color: SanadTheme.subtleShadow, radius: 4, y: 3)
    }
}

#Preview { NavigationView { AdminOrganizationDetailView(orgId: 1, orgName: "Organization") } }
