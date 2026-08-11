import SwiftUI

struct AdminDailyTipsView: View {
    @State private var tips: [AdminDailyTip] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showEditor = false
    @State private var editingTip: AdminDailyTip?
    @State private var tipDate = ""
    @State private var tipTitle = ""
    @State private var tipBody = ""

    private let service = AdminService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "admin_daily_tips_title")

                VStack(alignment: .leading, spacing: 14) {
                    Button("admin_daily_tip_add") { openEditor(nil) }
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(SanadTheme.primary.opacity(0.12)))
                        .foregroundColor(SanadTheme.primary)

                    if loading && tips.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                    } else if let error {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(SanadTheme.error)
                    } else if tips.isEmpty {
                        SanadEmptyState(message: "admin_daily_tips_empty")
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(tips) { tip in
                                tipCard(tip)
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
        .sheet(isPresented: $showEditor) {
            NavigationView {
                Form {
                    TextField("admin_daily_tip_date", text: $tipDate)
                    TextField("admin_daily_tip_title_ar", text: $tipTitle)
                    TextField("admin_daily_tip_body_ar", text: $tipBody)
                }
                .navigationTitle(editingTip == nil ? "admin_daily_tip_add" : "admin_daily_tip_edit")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common_cancel") { showEditor = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("save") { Task { await save() } }
                    }
                }
            }
        }
    }

    private func tipCard(_ tip: AdminDailyTip) -> some View {
        SanadListCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tip.tip_date ?? "")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SanadTheme.onBg)
                    Text(tip.title?["ar"] ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(SanadTheme.placeholder)
                }
                Spacer()
                Button("admin_delete") {
                    Task { await delete(tip) }
                }
                .foregroundColor(SanadTheme.error)
            }
            .contentShape(Rectangle())
            .onTapGesture { openEditor(tip) }
        }
    }

    private func openEditor(_ tip: AdminDailyTip?) {
        editingTip = tip
        tipDate = tip?.tip_date ?? ""
        tipTitle = tip?.title?["ar"] ?? ""
        tipBody = tip?.body?["ar"] ?? ""
        showEditor = true
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else { return }
        loading = true
        defer { loading = false }
        do {
            tips = try await service.dailyTips(token: token)
            error = nil
        } catch {
            self.error = NSLocalizedString("static_page_load_failed", comment: "")
        }
    }

    private func save() async {
        guard let token = KeychainHelper.getToken() else { return }
        let date = tipDate.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = tipTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !date.isEmpty, !title.isEmpty else { return }
        do {
            if let editingTip {
                try await service.updateDailyTip(id: editingTip.id, date: date, titleAr: title, bodyAr: tipBody, token: token)
            } else {
                try await service.createDailyTip(date: date, titleAr: title, bodyAr: tipBody, token: token)
            }
            showEditor = false
            editingTip = nil
            await load()
        } catch {
            self.error = NSLocalizedString("paywall_error", comment: "")
        }
    }

    private func delete(_ tip: AdminDailyTip) async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await service.deleteDailyTip(id: tip.id, token: token)
            await load()
        } catch {
            self.error = NSLocalizedString("paywall_error", comment: "")
        }
    }
}
