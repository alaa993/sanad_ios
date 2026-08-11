import SwiftUI

struct OrgSpecialistsView: View {
    @State private var specialists: [OrgSpecialist] = []
    @State private var error: String?
    @State private var loading = false

    private let service = OrgService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "org_specialists_title")

                VStack(alignment: .leading, spacing: 14) {
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
                            ForEach(specialists) { item in
                                NavigationLink(destination: OrgSpecialistDetailView(specialistId: item.id, specialistName: item.name)) {
                                    specialistCard(item)
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
    }

    private func specialistCard(_ item: OrgSpecialist) -> some View {
        SanadListCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name ?? NSLocalizedString("common_specialist", comment: ""))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(SanadTheme.onBg)
                    if let sessions = item.sessions_count {
                        Text(String(format: NSLocalizedString("org_specialists_sessions_count", comment: ""), sessions))
                            .font(.system(size: 12))
                            .foregroundColor(SanadTheme.placeholder)
                    }
                    if let rating = item.avg_rating {
                        Text(String(format: NSLocalizedString("org_specialists_rating", comment: ""), String(format: "%.1f", rating)))
                            .font(.system(size: 12))
                            .foregroundColor(SanadTheme.placeholder)
                    }
                    if let next = item.next_session_at {
                        Text(next)
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
            await MainActor.run { self.error = NSLocalizedString("org_specialists_load_failed", comment: "") }
        }
        loading = false
    }
}

#Preview { NavigationView { OrgSpecialistsView() } }
