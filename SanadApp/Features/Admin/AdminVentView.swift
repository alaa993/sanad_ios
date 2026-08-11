import SwiftUI

struct AdminVentView: View {
    @State private var reports: [AdminVentReport] = []
    @State private var loading = false
    @State private var error: String?

    private let service = AdminService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "admin_vent_title")

                VStack(alignment: .leading, spacing: 14) {
                    if loading && reports.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                    } else if let error {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.error)
                    } else if reports.isEmpty {
                        SanadEmptyState(message: "admin_vent_empty")
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(reports) { report in
                                reportCard(report)
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

    private func reportCard(_ report: AdminVentReport) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(report.post?.alias ?? "#\(report.post?.id ?? report.id)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                Text(report.post?.body ?? "")
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.placeholder)
                if let reason = report.reason {
                    Text(reason)
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.error)
                }
                Button("admin_vent_hide") {
                    Task { await hide(report) }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SanadTheme.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else { return }
        loading = true
        defer { loading = false }
        do {
            reports = try await service.ventReports(token: token)
            error = nil
        } catch {
            self.error = NSLocalizedString("static_page_load_failed", comment: "")
        }
    }

    private func hide(_ report: AdminVentReport) async {
        guard let token = KeychainHelper.getToken(), let postId = report.post?.id else { return }
        do {
            try await service.hideVentPost(id: postId, token: token)
            await load()
        } catch {
            self.error = NSLocalizedString("paywall_error", comment: "")
        }
    }
}
