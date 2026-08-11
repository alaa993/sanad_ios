import SwiftUI

struct OrgBillingView: View {
    @State private var overview: OrgBillingOverview?
    @State private var error: String?
    @State private var loading = false

    private let service = OrgService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "org_billing_title")

                VStack(alignment: .leading, spacing: 14) {
                    if loading && overview == nil {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                    } else if let err = error {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.error)
                    } else {
                        planCard()
                        usageCard()
                        invoicesCard()
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

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        do {
            let res = try await service.billingOverview(token: token)
            await MainActor.run {
                self.overview = res
                self.error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("org_billing_load_failed", comment: "") }
        }
        loading = false
    }

    @ViewBuilder
    private func planCard() -> some View {
        let plan = overview?.plan
        SanadListCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("org_billing_plan")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SanadTheme.placeholder)
                Text(plan?.name ?? NSLocalizedString("org_billing_plan_unset", comment: ""))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                Text(String(format: NSLocalizedString("org_billing_status", comment: ""), plan?.status ?? NSLocalizedString("common_unknown", comment: "")))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
                if let renew = plan?.renews_at {
                    Text(String(format: NSLocalizedString("org_billing_renewal", comment: ""), renew))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func usageCard() -> some View {
        let seats = overview?.seats
        let sessions = overview?.sessions
        let wallet = overview?.wallet
        SanadListCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("org_billing_usage")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SanadTheme.onBg)
                Text(String(format: NSLocalizedString("org_billing_seats", comment: ""), seats?.used ?? 0, seats?.limit ?? 0))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
                Text(String(format: NSLocalizedString("org_billing_sessions", comment: ""), sessions?.used ?? 0, sessions?.limit ?? 0))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
                Text(String(format: NSLocalizedString("org_billing_balance", comment: ""), wallet?.points ?? wallet?.balance ?? 0, wallet?.currency ?? "PTS"))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func invoicesCard() -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("org_billing_invoices")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SanadTheme.onBg)
                let invoices = overview?.invoices ?? []
                if invoices.isEmpty {
                    SanadEmptyState(message: "org_billing_no_invoices")
                } else {
                    ForEach(invoices) { inv in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: NSLocalizedString("org_billing_invoice_id", comment: ""), inv.id))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(SanadTheme.onBg)
                            Text("\(inv.total ?? 0) \(inv.currency ?? "")")
                                .font(.system(size: 12))
                                .foregroundColor(SanadTheme.placeholder)
                            Text(String(format: NSLocalizedString("org_billing_status", comment: ""), inv.status ?? ""))
                                .font(.system(size: 12))
                                .foregroundColor(SanadTheme.placeholder)
                        }
                        if inv.id != invoices.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview { NavigationView { OrgBillingView() } }
