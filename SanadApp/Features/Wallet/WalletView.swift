import SwiftUI

struct WalletView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var points: Int = 0
    @State private var coupon: String = ""
    @State private var loadError: String?
    @State private var couponError: String?
    @State private var loading = false
    @State private var transactions: [BillingTransaction] = []
    @State private var invoices: [BillingInvoice] = []
    @State private var billingError: String?
    @State private var topupAmount = "100"
    @State private var topupPresets: [Int] = [50, 100, 300]
    @State private var topupMethod: TopupMethod = .syriatel
    @State private var phone = ""
    @State private var mobileTxId = ""
    @State private var mobileReference: String?
    @State private var mobileInstructions: String?
    @State private var mobileError: String?
    @State private var mobileMessage: String?
    private let service = WalletService()
    private let billingService = BillingService()

    private enum TopupMethod: String, CaseIterable, Identifiable {
        case syriatel, mtn
        var id: String { rawValue }
        var titleKey: LocalizedStringKey {
            switch self {
            case .syriatel: return "wallet_syriatel_title"
            case .mtn: return "wallet_mtn_title"
            }
        }
    }

    private var showsPatientTopup: Bool {
        let role = (authVM.userRole ?? "patient").lowercased()
        return !role.contains("specialist") && !role.contains("admin") && !role.contains("organization")
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    SanadHeroHeader(title: "wallet_balance", showsBackButton: true)

                    VStack(alignment: .leading, spacing: 16) {
                        balanceCard
                        if showsPatientTopup {
                            unifiedTopupCard
                        }
                        redeemCard
                        invoicesCard
                        historyCard
                        if let billingErr = billingError {
                            SanadInlineBanner(billingErr, style: .error)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            if loading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: SanadTheme.primary))
                    .scaleEffect(1.1)
            }
            if let err = loadError, !loading {
                errorOverlay(message: err)
            }
        }
        .background(SanadAtmosphereBackground())
        .navigationBarHidden(true)
        .task {
            await load()
            await loadTransactions()
            await loadInvoices()
            await loadPaymentMethods()
        }
        .refreshable {
            await load()
            await loadTransactions()
            await loadInvoices()
            await loadPaymentMethods()
        }
        .coachMarks(key: "tour_wallet", steps: [
            CoachMarkStep(id: "wl_balance", title: "tour_wallet_balance_title", desc: "tour_wallet_balance_desc", targetId: "wl_balance"),
            CoachMarkStep(id: "wl_code", title: "tour_wallet_code_title", desc: "tour_wallet_code_desc", targetId: "wl_code"),
            CoachMarkStep(id: "wl_redeem", title: "tour_wallet_redeem_title", desc: "tour_wallet_redeem_desc", targetId: "wl_redeem"),
            CoachMarkStep(id: "wl_history", title: "tour_wallet_history_title", desc: "tour_wallet_history_desc", targetId: "wl_history")
        ])
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("wallet_balance")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SanadTheme.onPrimary.opacity(0.9))
            Text(String(format: NSLocalizedString("wallet_points_value", comment: ""), points))
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(SanadTheme.onPrimary)
            Text("wallet_trust_note")
                .font(.system(size: 12))
                .foregroundColor(SanadTheme.onPrimary.opacity(0.85))
                .lineLimit(2)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [SanadTheme.primary, SanadTheme.primary.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .coachMarkTarget("wl_balance")
    }

    private var unifiedTopupCard: some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("wallet_topup_title")
                    .font(SanadFont.bodyMedium(15))
                    .foregroundColor(SanadTheme.onBg)
                Text(mobileInstructions
                     ?? NSLocalizedString(topupMethod == .syriatel ? "wallet_syriatel_desc" : "wallet_mtn_desc", comment: ""))
                    .font(SanadFont.caption(13))
                    .foregroundColor(SanadTheme.placeholder)

                Text("wallet_topup_presets")
                    .font(SanadFont.caption(12))
                    .foregroundColor(SanadTheme.placeholder)
                HStack(spacing: 8) {
                    ForEach(topupPresets, id: \.self) { preset in
                        Button("+\(preset)") {
                            topupAmount = String(preset)
                        }
                        .font(SanadFont.bodyMedium(13))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(topupAmount == String(preset)
                                           ? SanadTheme.primary
                                           : SanadTheme.primary.opacity(0.10))
                        )
                        .foregroundColor(topupAmount == String(preset) ? SanadTheme.onPrimary : SanadTheme.primary)
                    }
                }

                SanadSearchField(text: $topupAmount, prompt: "wallet_topup_hint")
                    .keyboardType(.numberPad)

                HStack(spacing: 8) {
                    ForEach(TopupMethod.allCases) { method in
                        Button(method.titleKey) {
                            topupMethod = method
                            mobileReference = nil
                            mobileTxId = ""
                            mobileInstructions = nil
                            mobileError = nil
                            mobileMessage = nil
                        }
                        .font(SanadFont.bodyMedium(13))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().stroke(topupMethod == method ? SanadTheme.primary : SanadTheme.fieldStroke, lineWidth: 1)
                        )
                        .foregroundColor(SanadTheme.primary)
                    }
                }

                SanadSearchField(text: $phone, prompt: "wallet_phone_hint")
                    .keyboardType(.phonePad)

                if mobileReference != nil {
                    Text(String(format: NSLocalizedString("wallet_payment_reference", comment: ""), mobileReference ?? ""))
                        .font(SanadFont.caption(12))
                        .foregroundColor(SanadTheme.primary)
                    SanadSearchField(text: $mobileTxId, prompt: "wallet_mtn_transaction_hint")
                }

                HStack(spacing: 10) {
                    Button("wallet_mtn_request") { Task { await startMobileTopup() } }
                        .font(SanadFont.bodyMedium(14))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                        .foregroundColor(SanadTheme.primary)
                    if mobileReference != nil {
                        Button("wallet_mtn_confirm") { Task { await confirmMobileTopup() } }
                            .font(SanadFont.bodyMedium(14))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(SanadTheme.primary))
                            .foregroundColor(SanadTheme.onPrimary)
                    }
                }
                if let mobileError {
                    Text(mobileError).font(SanadFont.caption(12)).foregroundColor(SanadTheme.error)
                }
                if let mobileMessage {
                    Text(mobileMessage).font(SanadFont.caption(12)).foregroundColor(SanadTheme.primary)
                }
            }
        }
    }

    private var redeemCard: some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("wallet_redeem_title")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(SanadTheme.onBg)
                Text("wallet_redeem_desc")
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.placeholder)
                SanadSearchField(text: $coupon, prompt: "wallet_redeem_hint")
                    .coachMarkTarget("wl_code")
                    .textInputAutocapitalization(.never)
                Button("wallet_redeem_btn") { Task { await applyCoupon() } }
                    .coachMarkTarget("wl_redeem")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Capsule().fill(SanadTheme.primary))
                    .foregroundColor(SanadTheme.onPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                if let couponErr = couponError {
                    Text(couponErr)
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.error)
                }
            }
        }
    }

    private var historyCard: some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("wallet_history")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(SanadTheme.onBg)
                if transactions.isEmpty {
                    SanadEmptyState(message: "wallet_empty_history")
                } else {
                    ForEach(transactions) { tx in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tx.type ?? NSLocalizedString("wallet_transaction_fallback", comment: ""))
                                    .font(.system(size: 14, weight: .semibold))
                                Text(String(format: NSLocalizedString("wallet_status", comment: ""), tx.status ?? NSLocalizedString("wallet_status_unknown", comment: "")))
                                    .font(.system(size: 12))
                                    .foregroundColor(SanadTheme.placeholder)
                            }
                            Spacer()
                            Text(txDisplayAmount(tx))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(txSignedValue(tx) >= 0 ? SanadTheme.primary : SanadTheme.error)
                        }
                        .padding(.vertical, 6)
                        if tx.id != transactions.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .coachMarkTarget("wl_history")
    }

    private var invoicesCard: some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("wallet_invoices")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(SanadTheme.onBg)
                if invoices.isEmpty {
                    SanadEmptyState(message: "wallet_empty_invoices")
                } else {
                    ForEach(invoices) { invoice in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(format: NSLocalizedString("wallet_invoice_id", comment: ""), invoice.id))
                                    .font(.system(size: 14, weight: .semibold))
                                Text(invoice.status ?? "—")
                                    .font(.system(size: 12))
                                    .foregroundColor(SanadTheme.placeholder)
                            }
                            Spacer()
                            Text("\(invoice.total ?? 0) \(invoice.currency ?? "")")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(SanadTheme.onBg)
                        }
                        .padding(.vertical, 6)
                        if invoice.id != invoices.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func errorOverlay(message: String) -> some View {
        VStack(spacing: 12) {
            Text(message.isEmpty ? NSLocalizedString("wallet_error", comment: "") : message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SanadTheme.placeholder)
            Button("btn_retry") {
                loadError = nil
                Task {
                    await load()
                    await loadTransactions()
                    await loadInvoices()
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .padding(.vertical, 10)
            .padding(.horizontal, 24)
            .background(Capsule().fill(SanadTheme.primary))
            .foregroundColor(SanadTheme.onPrimary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(SanadTheme.surface.opacity(0.9))
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            loadError = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        do {
            let res = try await service.balance(token: token)
            await MainActor.run {
                points = res.points ?? 0
                if let txs = res.transactions, !txs.isEmpty {
                    transactions = txs
                }
                loadError = nil
            }
        } catch {
            await MainActor.run { self.loadError = NSLocalizedString("wallet_load_balance_failed", comment: "") }
        }
        loading = false
    }

    private func applyCoupon() async {
        guard let token = KeychainHelper.getToken(), !coupon.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            let res = try await service.applyCoupon(code: coupon, token: token)
            await MainActor.run {
                points = res.points ?? points
                coupon = ""
                couponError = nil
            }
            await load()
            await loadTransactions()
        } catch {
            await MainActor.run { self.couponError = NSLocalizedString("wallet_invalid_coupon", comment: "") }
        }
    }

    private func loadTransactions() async {
        guard let token = KeychainHelper.getToken() else {
            billingError = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        do {
            let txList = try await billingService.transactions(token: token)
            await MainActor.run {
                if !txList.isEmpty {
                    self.transactions = txList
                }
                billingError = nil
            }
        } catch {
            // Keep /wallet/me transactions if billing endpoint fails.
            if transactions.isEmpty {
                await MainActor.run { billingError = NSLocalizedString("wallet_load_billing_failed", comment: "") }
            }
        }
    }

    private func loadInvoices() async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            let list = try await billingService.invoices(token: token)
            await MainActor.run { self.invoices = list }
        } catch {
            await MainActor.run { self.invoices = [] }
        }
    }

    private func txSignedValue(_ tx: BillingTransaction) -> Int {
        let type = (tx.type ?? "").lowercased()
        let pointTx = (tx.points ?? 0) != 0
            || type.contains("point")
            || type == "balance_to_points"
        var signed = pointTx ? (tx.points ?? 0) : (tx.amount ?? 0)
        if !pointTx && signed > 0 && (type.contains("debit") || type.contains("charge") || type.contains("hold")) {
            signed = -signed
        }
        return signed
    }

    private func txDisplayAmount(_ tx: BillingTransaction) -> String {
        let signed = txSignedValue(tx)
        let type = (tx.type ?? "").lowercased()
        let pointTx = (tx.points ?? 0) != 0
            || type.contains("point")
            || type == "balance_to_points"
        let unit = pointTx ? "PTS" : (tx.currency ?? "")
        let sign = signed > 0 ? "+" : ""
        return "\(sign)\(signed) \(unit)".trimmingCharacters(in: .whitespaces)
    }

    private func loadPaymentMethods() async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            let res = try await service.paymentMethods(token: token)
            await MainActor.run {
                if let presets = res.topup_presets, !presets.isEmpty {
                    topupPresets = presets
                    if Int(topupAmount) == nil { topupAmount = String(presets[0]) }
                }
            }
        } catch {
            // Keep defaults 50/100/300
        }
    }

    private func startMobileTopup() async {
        guard let token = KeychainHelper.getToken() else { return }
        guard let amount = Int(topupAmount.trimmingCharacters(in: .whitespaces)), amount > 0 else {
            await MainActor.run { mobileError = NSLocalizedString("wallet_topup_invalid", comment: "") }
            return
        }
        do {
            let res: MtnInitResponse
            switch topupMethod {
            case .syriatel:
                res = try await service.syriatelInit(amount: amount, phone: phone, token: token)
            case .mtn:
                res = try await service.mtnInit(amount: amount, phone: phone, token: token)
            }
            await MainActor.run {
                mobileReference = res.reference
                mobileInstructions = res.instructions
                mobileError = nil
                mobileMessage = NSLocalizedString("wallet_mtn_reference_ready", comment: "")
            }
        } catch {
            await MainActor.run { mobileError = NSLocalizedString("wallet_mtn_failed", comment: "") }
        }
    }

    private func confirmMobileTopup() async {
        guard let token = KeychainHelper.getToken(), let reference = mobileReference else { return }
        let tx = mobileTxId.trimmingCharacters(in: .whitespaces)
        guard !tx.isEmpty else {
            await MainActor.run { mobileError = NSLocalizedString("wallet_mtn_transaction_hint", comment: "") }
            return
        }
        do {
            switch topupMethod {
            case .syriatel:
                _ = try await service.syriatelConfirm(reference: reference, transactionId: tx, token: token)
            case .mtn:
                _ = try await service.mtnConfirm(reference: reference, transactionId: tx, token: token)
            }
            await MainActor.run {
                mobileReference = nil
                mobileTxId = ""
                mobileMessage = NSLocalizedString("wallet_mtn_success", comment: "")
                mobileError = nil
            }
            await load()
            await loadTransactions()
        } catch {
            await MainActor.run { mobileError = NSLocalizedString("wallet_mtn_failed", comment: "") }
        }
    }

}

#Preview { WalletView().environmentObject(AuthViewModel()) }
