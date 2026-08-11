import SwiftUI

struct AdminSessionsView: View {
    @State private var sessions: [AdminAppointment] = []
    @State private var error: String?
    @State private var loading = false

    private let service = AdminService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "admin_sessions_title")

                VStack(alignment: .leading, spacing: 14) {
                    if loading && sessions.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                    } else if let err = error {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.error)
                    } else if sessions.isEmpty {
                        SanadEmptyState(message: "common_no_items")
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(sessions) { session in
                                sessionCard(session)
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

    private func sessionCard(_ session: AdminAppointment) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.specialist_name ?? NSLocalizedString("common_session", comment: ""))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                if let patient = session.patient_name {
                    Text(String(format: NSLocalizedString("admin_sessions_patient", comment: ""), patient))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
                if let status = session.status {
                    Text(String(format: NSLocalizedString("admin_sessions_status", comment: ""), status))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
                if let start = session.starts_at {
                    Text(start)
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
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
            let res = try await service.appointments(token: token)
            await MainActor.run {
                self.sessions = res
                self.error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("admin_sessions_load_failed", comment: "") }
        }
        loading = false
    }
}

#Preview { NavigationView { AdminSessionsView() } }
