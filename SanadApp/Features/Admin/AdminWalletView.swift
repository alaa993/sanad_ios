import SwiftUI

struct AdminWalletView: View {
    @State private var couponCode = ""
    @State private var couponPoints = ""
    @State private var couponExpiry = ""
    @State private var creditUserId = ""
    @State private var creditPoints = ""
    @State private var loading = false
    @State private var toast: String?

    private let service = AdminWalletService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "admin_wallet_title")

                VStack(alignment: .leading, spacing: 16) {
                    SanadListCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("admin_wallet_coupon_section")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(SanadTheme.onBg)
                            field("admin_wallet_coupon_code", text: $couponCode)
                            field("admin_wallet_coupon_points", text: $couponPoints)
                            field("admin_wallet_coupon_expiry", text: $couponExpiry)
                            Button("admin_wallet_create_coupon") { Task { await createCoupon() } }
                                .buttonStyle(AdminWalletButtonStyle(filled: true))
                                .disabled(loading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SanadListCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("admin_wallet_credit_section")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(SanadTheme.onBg)
                            field("admin_wallet_credit_user_id", text: $creditUserId)
                            field("admin_wallet_credit_points", text: $creditPoints)
                            Button("admin_wallet_credit_user") { Task { await creditUser() } }
                                .buttonStyle(AdminWalletButtonStyle(filled: false))
                                .disabled(loading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let toast {
                        Text(toast)
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.placeholder)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private func field(_ label: LocalizedStringKey, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12)).foregroundColor(SanadTheme.placeholder)
            TextField("", text: text)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(SanadTheme.surfaceAlt)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(SanadTheme.fieldStroke, lineWidth: 1)
                )
        }
    }

    private func createCoupon() async {
        guard let token = KeychainHelper.getToken() else { return }
        guard let points = Int(couponPoints.trimmingCharacters(in: .whitespaces)), points > 0 else {
            toast = NSLocalizedString("error_required_fields", comment: "")
            return
        }
        let code = couponCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else {
            toast = NSLocalizedString("error_required_fields", comment: "")
            return
        }
        loading = true
        defer { loading = false }
        do {
            try await service.createCoupon(token: token, code: code, points: points, expiry: couponExpiry.isEmpty ? nil : couponExpiry)
            await MainActor.run {
                toast = NSLocalizedString("admin_wallet_saved", comment: "")
                couponCode = ""
                couponPoints = ""
                couponExpiry = ""
            }
        } catch {
            await MainActor.run { toast = NSLocalizedString("admin_wallet_failed", comment: "") }
        }
    }

    private func creditUser() async {
        guard let token = KeychainHelper.getToken() else { return }
        guard let uid = Int(creditUserId.trimmingCharacters(in: .whitespaces)), uid > 0,
              let pts = Int(creditPoints.trimmingCharacters(in: .whitespaces)), pts > 0 else {
            toast = NSLocalizedString("error_required_fields", comment: "")
            return
        }
        loading = true
        defer { loading = false }
        do {
            try await service.creditUser(token: token, userId: uid, points: pts)
            await MainActor.run {
                toast = NSLocalizedString("admin_wallet_saved", comment: "")
                creditUserId = ""
                creditPoints = ""
            }
        } catch {
            await MainActor.run { toast = NSLocalizedString("admin_wallet_failed", comment: "") }
        }
    }
}

private struct AdminWalletButtonStyle: ButtonStyle {
    let filled: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Capsule().fill(filled ? SanadTheme.primary.opacity(configuration.isPressed ? 0.85 : 1) : Color.clear))
            .overlay(Capsule().stroke(SanadTheme.primary, lineWidth: filled ? 0 : 1))
            .foregroundColor(filled ? SanadTheme.onPrimary : SanadTheme.primary)
    }
}
