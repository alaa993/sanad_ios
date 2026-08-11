import SwiftUI

struct PatientSpecialistsView: View {
    @State private var specialists: [DirectorySpecialist] = []
    @State private var loading = false
    @State private var error: String?
    @State private var query: String = ""

    private let service = DirectoryService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "patient_specialists_title", showLogo: true)

                VStack(alignment: .leading, spacing: 14) {
                    SanadSearchField(text: $query, prompt: "patient_specialists_search")
                        .onChange(of: query) { _ in
                            Task { await load(query: query.isEmpty ? nil : query) }
                        }

                    if loading && specialists.isEmpty {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: SanadTheme.primary))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else if let error, specialists.isEmpty {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.error)
                    } else if specialists.isEmpty {
                        SanadEmptyState(message: "patient_specialists_empty")
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(specialists) { specialist in
                                NavigationLink(destination: PatientSpecialistDetailView(specialistId: specialist.id, specialistName: specialist.name)) {
                                    specialistCard(specialist)
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
        .refreshable {
            await load(query: query.isEmpty ? nil : query)
        }
        .task {
            await load(query: query.isEmpty ? nil : query)
        }
    }

    private func specialistCard(_ specialist: DirectorySpecialist) -> some View {
        SanadListCard {
            HStack(spacing: 12) {
                PatientSpecialistRow(specialist: specialist)
                Spacer(minLength: 0)
                SanadIcon.chevronLeft.image
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SanadTheme.placeholder)
            }
        }
    }

    @MainActor
    private func load(query: String?) async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_login_first", comment: "")
            specialists = []
            return
        }
        loading = true
        defer { loading = false }
        do {
            let data = try await service.specialists(query: query, token: token)
            specialists = data
            error = data.isEmpty ? NSLocalizedString("common_no_matching_results", comment: "") : nil
        } catch {
            self.error = NSLocalizedString("patient_specialists_load_failed", comment: "")
            specialists = []
        }
    }
}

private struct PatientSpecialistRow: View {
    let specialist: DirectorySpecialist

    var body: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 4) {
                Text(specialist.name ?? NSLocalizedString("common_specialist", comment: ""))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                if let specialty = specialist.specialty, !specialty.isEmpty {
                    Text(specialty)
                        .font(.system(size: 13))
                        .foregroundColor(SanadTheme.placeholder)
                }
                if let meta = metaText {
                    Text(meta)
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
                if let languages = languageText {
                    Text(languages)
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder.opacity(0.9))
                }
            }
        }
    }

    private var avatar: some View {
        Group {
            if let urlString = specialist.avatar, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .background(Circle().fill(SanadTheme.card))
    }

    private var placeholder: some View {
        SanadIcon.profile.image
            .resizable()
            .scaledToFit()
            .padding(12)
            .foregroundColor(SanadTheme.placeholder)
    }

    private var metaText: String? {
        var parts: [String] = []
        if let years = specialist.yearsExperience {
            parts.append(String(format: NSLocalizedString("specialist_years_experience", comment: ""), years))
        }
        if let rating = specialist.rating {
            let ratingValue = String(format: "%.1f", rating)
            parts.append(String(format: NSLocalizedString("specialist_rating", comment: ""), ratingValue))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private var languageText: String? {
        guard let languages = specialist.languages, !languages.isEmpty else { return nil }
        return languages.joined(separator: " • ")
    }
}

extension PatientSpecialistsView {
    #if DEBUG
    struct PatientSpecialistsView_Previews: PreviewProvider {
        static var previews: some View {
            NavigationView {
                PatientSpecialistsView()
            }
        }
    }
    #endif
}
