import SwiftUI

struct PatientSpecialistDetailView: View {
    let specialistId: Int
    let specialistName: String?

    @State private var specialist: DirectorySpecialist?
    @State private var loading = false
    @State private var error: String?
    @State private var showBook = false

    private let service = DirectoryService()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                if specialist != nil {
                    Button("shortcuts_action_book") { showBook = true }
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(SanadTheme.primary))
                        .foregroundColor(SanadTheme.onPrimary)
                }
                if let detail = specialist {
                    statusCard(detail: detail)
                    infoCard(detail: detail)
                    bioCard(detail: detail)
                } else if let message = error {
                    Text(message)
                        .foregroundColor(.red)
                        .font(.system(size: 13))
                        .padding()
                }
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .navigationTitle(specialist?.name ?? specialistName ?? NSLocalizedString("patient_specialist_detail_title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .background(SanadTheme.surface.ignoresSafeArea())
        .overlay(
            loading ? ProgressView().progressViewStyle(CircularProgressViewStyle(tint: SanadTheme.primary)).scaleEffect(1.1) : nil
        )
        .task {
            await loadDetail()
        }
        .sheet(isPresented: $showBook) {
            BookSessionView(selectedSpecialist: specialist, onCompleted: { showBook = false })
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            if let urlString = specialist?.avatar, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholderAvatar
                    }
                }
                .frame(width: 110, height: 110)
                .clipShape(Circle())
            } else {
                placeholderAvatar
                    .frame(width: 110, height: 110)
            }
            Text(specialist?.name ?? specialistName ?? NSLocalizedString("common_specialist", comment: ""))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)
            if let specialty = specialist?.specialty, !specialty.isEmpty {
                Text(specialty)
                    .font(.system(size: 14))
                    .foregroundColor(SanadTheme.placeholder)
            }
        }
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(SanadTheme.card)
            .overlay(
                SanadIcon.profile.image
                    .resizable()
                    .scaledToFit()
                    .padding(20)
                    .foregroundColor(SanadTheme.placeholder)
            )
    }

    private func statusCard(detail: DirectorySpecialist) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let accepting = detail.acceptingNew {
                Text(accepting.description)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accepting.isAccepting ? .green : SanadTheme.placeholder)
            }
            Text(detail.category ?? NSLocalizedString("patient_specialist_detail_no_extra", comment: ""))
                .font(.system(size: 12))
                .foregroundColor(SanadTheme.placeholder)
            if let sessionTypes = detail.sessionTypes, !sessionTypes.isEmpty {
                InfoTag(title: "patient_specialist_detail_session_types", value: sessionTypes.joined(separator: " • "))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(SanadTheme.card))
        .shadow(color: SanadTheme.subtleShadow, radius: 4, y: 2)
    }

    private func infoCard(detail: DirectorySpecialist) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("patient_specialist_detail_more_info")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SanadTheme.placeholder)
            if let meta = detailMeta(detail) {
                Text(meta)
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.onBg)
            }
            if let languages = detail.languages, !languages.isEmpty {
                InfoTag(title: "patient_specialist_detail_languages", value: languages.joined(separator: " • "))
            }
            if let tags = detail.tags, !tags.isEmpty {
                InfoTag(title: "patient_specialist_detail_expertise", value: tags.joined(separator: " • "))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(SanadTheme.card))
        .shadow(color: SanadTheme.subtleShadow, radius: 4, y: 2)
    }

    private func bioCard(detail: DirectorySpecialist) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("patient_specialist_detail_bio")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SanadTheme.placeholder)
            if let bio = detail.bio, !bio.isEmpty {
                ForEach(bio.sorted(by: { $0.key < $1.key }), id: \.key) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.key.capitalized)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(SanadTheme.primary)
                        Text(entry.value)
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.onBg)
                    }
                }
            } else {
                Text("patient_specialist_detail_no_notes")
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.placeholder)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(SanadTheme.card))
        .shadow(color: SanadTheme.subtleShadow, radius: 4, y: 2)
    }

    @MainActor
    private func loadDetail() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_login_first", comment: "")
            return
        }
        loading = true
        defer { loading = false }
        do {
            specialist = try await service.specialistDetail(id: specialistId, token: token)
            error = nil
        } catch {
            self.error = NSLocalizedString("patient_specialist_detail_load_failed", comment: "")
        }
    }

    private func detailMeta(_ detail: DirectorySpecialist) -> String? {
        var parts: [String] = []
        if let years = detail.yearsExperience {
            parts.append(String(format: NSLocalizedString("specialist_years_experience", comment: ""), years))
        }
        if let rating = detail.rating {
            let ratingValue = String(format: "%.1f", rating)
            parts.append(String(format: NSLocalizedString("specialist_rating", comment: ""), ratingValue))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

private struct InfoTag: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(SanadTheme.placeholder)
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(SanadTheme.onBg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension PatientSpecialistDetailView {
    #if DEBUG
    struct PatientSpecialistDetailView_Previews: PreviewProvider {
        static var previews: some View {
            NavigationView {
                PatientSpecialistDetailView(specialistId: 1, specialistName: "Specialist")
            }
        }
    }
    #endif
}
