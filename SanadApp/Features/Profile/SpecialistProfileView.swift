import SwiftUI

struct SpecialistProfileView: View {
    @State private var profile: SpecialistProfileData?
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var showEdit = false
    @State private var showDocuments = false
    @State private var documents: [SpecialistDocument] = []

    private let service = SpecialistProfileService()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let profile = profile {
                header(profile)
                stats(profile)
                languages(profile)
                if let notes = profile.verification_notes, !notes.isEmpty {
                    verificationCard(notes: notes, status: profile.status)
                }
                documentSection
                ButtonsRow()
            } else if loading {
                ProgressView()
            } else if let errorMessage = errorMessage {
                Text(errorMessage).foregroundColor(.red)
            }
            Spacer()
        }
        .padding(20)
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationTitle("specialist_profile_title")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadProfile() }
        .sheet(isPresented: $showEdit) {
            SpecialistEditView(profile: profile) {
                Task { await loadProfile() }
            }
        }
        .sheet(isPresented: $showDocuments) {
            SpecialistDocumentsView()
        }
    }

    private func header(_ profile: SpecialistProfileData) -> some View {
        HStack(alignment: .center, spacing: 14) {
            profileAvatar(profile)
            VStack(alignment: .leading, spacing: 6) {
                Text(profile.user?.name ?? "—")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                Text(profile.user?.email ?? "—")
                    .font(.system(size: 14))
                    .foregroundColor(SanadTheme.placeholder)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func profileAvatar(_ profile: SpecialistProfileData) -> some View {
        let name = profile.user?.name ?? "—"
        let initial = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
        ZStack {
            Circle()
                .fill(SanadTheme.primary.opacity(0.12))
            Text(initial.isEmpty ? "—" : initial)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(SanadTheme.primary)
            if let urlString = profile.avatar, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Color.clear
                    }
                }
                .clipShape(Circle())
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
    }

    private func stats(_ profile: SpecialistProfileData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(format: NSLocalizedString("specialist_profile_specialty", comment: ""), profile.specialty ?? NSLocalizedString("specialist_profile_specialty_unset", comment: "")))
            Text(String(format: NSLocalizedString("specialist_profile_experience_years", comment: ""), profile.years_exp ?? 0))
            if let rate = profile.rate_cents, let currency = profile.currency {
                Text(String(format: NSLocalizedString("specialist_profile_price", comment: ""), currency.uppercased(), rate / 100))
            }
        }
        .font(.system(size: 13))
        .foregroundColor(SanadTheme.placeholder)
    }

    private func languages(_ profile: SpecialistProfileData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("specialist_profile_languages")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)
            Text(profile.languages?.joined(separator: " · ") ?? NSLocalizedString("specialist_profile_languages_unset", comment: ""))
                .font(.system(size: 13))
                .foregroundColor(SanadTheme.placeholder)
        }
    }

    private func verificationCard(notes: String, status: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: NSLocalizedString("specialist_profile_verification_status", comment: ""), status ?? NSLocalizedString("specialist_profile_status_unknown", comment: "")))
                .font(.system(size: 13, weight: .semibold))
            Text(notes)
                .font(.system(size: 12))
                .foregroundColor(SanadTheme.onBg)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(SanadTheme.card))
        .shadow(color: SanadTheme.subtleShadow, radius: 4, y: 3)
    }

    private var documentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("specialist_profile_documents")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                Spacer()
                Button("specialist_profile_view_all") {
                    showDocuments = true
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(SanadTheme.primary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(documents) { doc in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(doc.title ?? doc.type ?? NSLocalizedString("specialist_profile_document_default", comment: ""))
                                .font(.system(size: 13, weight: .semibold))
                            Text(doc.meta?.original_name ?? "")
                                .font(.system(size: 11))
                                .foregroundColor(SanadTheme.placeholder)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(SanadTheme.card))
                        .shadow(color: SanadTheme.subtleShadow, radius: 3, y: 2)
                        }
                    }
                }
            }
        }

    private func ButtonsRow() -> some View {
        VStack(spacing: 12) {
            Button("specialist_profile_edit") { showEdit = true }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(SanadTheme.primary))
                .foregroundColor(SanadTheme.onPrimary)
            Button("specialist_profile_upload_docs") { showDocuments = true }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                .foregroundColor(SanadTheme.primary)
        }
    }

    private func loadProfile() async {
        guard let token = KeychainHelper.getToken() else {
            errorMessage = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        do {
            let profileData = try await service.fetchProfile(token: token)
            let docs = try await service.fetchDocuments(token: token)
            await MainActor.run {
                profile = profileData
                documents = docs
                errorMessage = nil
            }
        } catch {
            await MainActor.run { errorMessage = NSLocalizedString("specialist_profile_load_failed", comment: "") }
        }
        loading = false
    }
}

#Preview {
    Group {
        if #available(iOS 16.0, *) {
            NavigationStack { SpecialistProfileView() }
        } else {
            NavigationView { SpecialistProfileView() }
        }
    }
}
