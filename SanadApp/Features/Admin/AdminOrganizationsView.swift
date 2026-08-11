import SwiftUI

struct AdminOrganizationsView: View {
    @State private var orgs: [AdminOrganization] = []
    @State private var error: String?
    @State private var loading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var rejectTarget: AdminOrganization?
    @State private var rejectReason = ""

    private let service = AdminService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "admin_orgs_title")

                VStack(alignment: .leading, spacing: 14) {
                    if loading && orgs.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                    } else if let err = error {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.error)
                    } else if orgs.isEmpty {
                        SanadEmptyState(message: "common_no_items")
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(orgs) { org in
                                NavigationLink(destination: AdminOrganizationDetailView(orgId: org.id, orgName: org.name)) {
                                    orgCard(org)
                                }
                                .buttonStyle(.plain)
                            }
                        }
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
        .alert(alertMessage, isPresented: $showAlert) {
            Button("common_ok", role: .cancel) {}
        }
        .sheet(item: $rejectTarget) { org in
            NavigationView {
                Form {
                    TextField("admin_reject_reason_hint", text: $rejectReason, axis: .vertical)
                }
                .navigationTitle("admin_reject_title")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common_cancel") { rejectTarget = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("admin_org_reject") {
                            let reason = rejectReason.trimmingCharacters(in: .whitespacesAndNewlines)
                            Task {
                                await action {
                                    try await service.rejectOrganization(
                                        id: org.id,
                                        reason: reason.isEmpty ? nil : reason,
                                        token: token()
                                    )
                                }
                                rejectTarget = nil
                                rejectReason = ""
                            }
                        }
                    }
                }
            }
        }
    }

    private func orgCard(_ org: AdminOrganization) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(org.name ?? NSLocalizedString("admin_org_default", comment: ""))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(SanadTheme.onBg)
                        if let status = org.status {
                            Text(String(format: NSLocalizedString("admin_org_status", comment: ""), status))
                                .font(.system(size: 12))
                                .foregroundColor(SanadTheme.placeholder)
                        }
                    }
                    Spacer(minLength: 0)
                    SanadIcon.chevronLeft.image
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(SanadTheme.placeholder)
                }
                HStack(spacing: 10) {
                    Button("admin_org_approve") {
                        Task { await action { try await service.approveOrganization(id: org.id, token: token()) } }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SanadTheme.primary)
                    .buttonStyle(.borderless)
                    Button("admin_org_reject") {
                        rejectReason = ""
                        rejectTarget = org
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SanadTheme.error)
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        do {
            let res = try await service.organizations(token: token)
            await MainActor.run {
                self.orgs = res
                self.error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("admin_orgs_load_failed", comment: "") }
        }
        loading = false
    }

    private func token() -> String {
        KeychainHelper.getToken() ?? ""
    }

    private func action(_ block: @escaping () async throws -> Void) async {
        do {
            try await block()
            await load()
        } catch {
            alertMessage = NSLocalizedString("admin_org_action_failed", comment: "")
            showAlert = true
        }
    }
}

#Preview { NavigationView { AdminOrganizationsView() } }
