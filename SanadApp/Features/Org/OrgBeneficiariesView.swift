import SwiftUI

struct OrgBeneficiariesView: View {
    var openCreateOnAppear: Bool = false
    @State private var beneficiaries: [OrgBeneficiary] = []
    @State private var error: String?
    @State private var loading = false
    @State private var showCreate = false
    @State private var newName = ""
    @State private var newEmail = ""
    @State private var newIssue = ""

    private let service = OrgService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "org_beneficiaries_title")

                VStack(alignment: .leading, spacing: 14) {
                    Button("org_beneficiary_add") { showCreate = true }
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                        .foregroundColor(SanadTheme.primary)

                    if loading && beneficiaries.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                    } else if let err = error {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.error)
                    } else if beneficiaries.isEmpty {
                        SanadEmptyState(message: "common_no_items")
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(beneficiaries) { item in
                                NavigationLink(destination: OrgBeneficiaryDetailView(beneficiaryId: item.id, beneficiaryName: item.name)) {
                                    beneficiaryCard(item)
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
        .onAppear {
            if openCreateOnAppear {
                showCreate = true
            }
        }
        .sheet(isPresented: $showCreate) { createSheet }
    }

    private func beneficiaryCard(_ item: OrgBeneficiary) -> some View {
        SanadListCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name ?? NSLocalizedString("role_patient", comment: ""))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(SanadTheme.onBg)
                    if let status = item.status {
                        Text(String(format: NSLocalizedString("org_beneficiaries_status", comment: ""), status))
                            .font(.system(size: 12))
                            .foregroundColor(SanadTheme.placeholder)
                    }
                    if let risk = item.risk_level {
                        Text(String(format: NSLocalizedString("org_beneficiaries_risk", comment: ""), risk))
                            .font(.system(size: 12))
                            .foregroundColor(SanadTheme.placeholder)
                    }
                    if let specialist = item.specialist_name {
                        Text(String(format: NSLocalizedString("org_beneficiaries_specialist", comment: ""), specialist))
                            .font(.system(size: 12))
                            .foregroundColor(SanadTheme.placeholder)
                    }
                }
                Spacer(minLength: 0)
                SanadIcon.chevronLeft.image
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SanadTheme.placeholder)
            }
        }
    }

    private var createSheet: some View {
        NavigationView {
            Form {
                TextField("org_beneficiary_name", text: $newName)
                TextField("profile_email", text: $newEmail)
                TextField("org_beneficiary_primary_issue", text: $newIssue)
            }
            .navigationTitle("org_beneficiary_add")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_cancel") { showCreate = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common_save") { Task { await create() } }
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
            let res = try await service.beneficiaries(token: token)
            await MainActor.run {
                self.beneficiaries = res
                self.error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("org_beneficiaries_load_failed", comment: "") }
        }
        loading = false
    }

    private func create() async {
        guard let token = KeychainHelper.getToken() else { return }
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            try await service.createBeneficiary(
                token: token,
                name: name,
                email: newEmail.isEmpty ? nil : newEmail,
                primaryIssue: newIssue.isEmpty ? nil : newIssue
            )
            await MainActor.run {
                showCreate = false
                newName = ""
                newEmail = ""
                newIssue = ""
            }
            await load()
        } catch {
            await MainActor.run { self.error = NSLocalizedString("org_beneficiaries_load_failed", comment: "") }
        }
    }
}
