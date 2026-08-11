import SwiftUI

struct AdminSpecialistsView: View {
    @State private var specialists: [AdminSpecialist] = []
    @State private var error: String?
    @State private var loading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showCreate = false
    @State private var createName = ""
    @State private var createEmail = ""
    @State private var createPassword = ""
    @State private var createPhone = ""
    @State private var createSpecialty = ""
    @State private var rejectTarget: AdminSpecialist?
    @State private var rejectReason = ""

    private let service = AdminService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "admin_specialists_title")

                VStack(alignment: .leading, spacing: 14) {
                    Button("admin_create_specialist") { showCreate = true }
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                        .foregroundColor(SanadTheme.primary)

                    if loading && specialists.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                    } else if let err = error {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.error)
                    } else if specialists.isEmpty {
                        SanadEmptyState(message: "common_no_items")
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(specialists) { spec in
                                NavigationLink(destination: AdminSpecialistDocumentsView(specialistId: spec.id, specialistName: spec.name)) {
                                    specialistCard(spec)
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
        .sheet(isPresented: $showCreate) {
            NavigationView {
                Form {
                    TextField("admin_profile_name", text: $createName)
                    TextField("username", text: $createEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("password", text: $createPassword)
                    TextField("phone", text: $createPhone)
                        .keyboardType(.phonePad)
                    TextField("specialist_info_specialty", text: $createSpecialty)
                }
                .navigationTitle("admin_create_specialist")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common_cancel") { showCreate = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("save") { Task { await create() } }
                    }
                }
            }
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("common_ok", role: .cancel) {}
        }
        .sheet(item: $rejectTarget) { spec in
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
                        Button("admin_specialist_reject") {
                            let reason = rejectReason.trimmingCharacters(in: .whitespacesAndNewlines)
                            Task {
                                await action {
                                    try await service.rejectSpecialist(
                                        id: spec.id,
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

    private func specialistCard(_ spec: AdminSpecialist) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(spec.name ?? NSLocalizedString("common_specialist", comment: ""))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(SanadTheme.onBg)
                        Text(spec.specialty ?? NSLocalizedString("admin_specialist_no_specialty", comment: ""))
                            .font(.system(size: 12))
                            .foregroundColor(SanadTheme.placeholder)
                        if let status = spec.status {
                            Text(String(format: NSLocalizedString("admin_specialist_status", comment: ""), status))
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
                    Button("admin_specialist_approve") {
                        Task { await action { try await service.approveSpecialist(id: spec.id, token: token()) } }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SanadTheme.primary)
                    .buttonStyle(.borderless)
                    Button("admin_specialist_reject") {
                        rejectReason = ""
                        rejectTarget = spec
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
            let res = try await service.specialists(token: token)
            await MainActor.run {
                self.specialists = res
                self.error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("admin_specialists_load_failed", comment: "") }
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
            alertMessage = NSLocalizedString("admin_specialist_action_failed", comment: "")
            showAlert = true
        }
    }

    private func create() async {
        let name = createName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = createEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !email.isEmpty, createPassword.count >= 6 else {
            alertMessage = NSLocalizedString("error_required_fields", comment: "")
            showAlert = true
            return
        }
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await service.createSpecialist(
                name: name,
                email: email,
                password: createPassword,
                phone: createPhone.trimmingCharacters(in: .whitespacesAndNewlines),
                specialty: createSpecialty.trimmingCharacters(in: .whitespacesAndNewlines),
                token: token
            )
            showCreate = false
            createName = ""
            createEmail = ""
            createPassword = ""
            createPhone = ""
            createSpecialty = ""
            await load()
        } catch {
            alertMessage = NSLocalizedString("admin_specialist_action_failed", comment: "")
            showAlert = true
        }
    }
}

#Preview { NavigationView { AdminSpecialistsView() } }
