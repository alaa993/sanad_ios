import SwiftUI

struct CoachView: View {
    @State private var programs: [CoachProgramSummary] = []
    @State private var loading = false
    @State private var errorMessage: String?

    private let service = CoachService()
    private let categories: [(key: String, label: String)] = [
        ("vitamins", "coach_cat_vitamins"),
        ("weight", "coach_cat_weight"),
        ("general", "coach_cat_general")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "coach_title", subtitle: "coach_subtitle")

                VStack(alignment: .leading, spacing: 14) {
                    if loading {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 8)
                    }

                    if let err = errorMessage {
                        Text(err).font(.system(size: 13)).foregroundColor(SanadTheme.error)
                    }

                    if programs.isEmpty && !loading {
                        SanadEmptyState(message: "coach_empty")
                    }

                    ForEach(programs) { program in
                        NavigationLink(destination: CoachDetailView(programId: program.id)) {
                            programRow(program)
                        }
                        .buttonStyle(.plain)
                    }

                    Menu {
                        ForEach(categories, id: \.key) { cat in
                            Button(LocalizedStringKey(cat.label)) {
                                Task { await create(category: cat.key, title: NSLocalizedString(cat.label, comment: "")) }
                            }
                        }
                    } label: {
                        Text("coach_create")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(SanadTheme.primary))
                            .foregroundColor(SanadTheme.onPrimary)
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

    private func programRow(_ program: CoachProgramSummary) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(program.title ?? NSLocalizedString("coach_title", comment: ""))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                Text(String(format: NSLocalizedString("coach_meta_fmt", comment: ""), program.items_count ?? 0, program.checkins_count ?? 0))
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.placeholder)
            }
        }
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            errorMessage = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        defer { loading = false }
        do {
            let list = try await service.list(token: token)
            await MainActor.run {
                programs = list
                errorMessage = nil
            }
        } catch {
            await MainActor.run { errorMessage = NSLocalizedString("coach_error", comment: "") }
        }
    }

    private func create(category: String, title: String) async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await service.create(category: category, title: title, token: token)
            await load()
        } catch {
            await MainActor.run { errorMessage = NSLocalizedString("coach_error", comment: "") }
        }
    }
}

struct CoachDetailView: View {
    let programId: Int
    @State private var detail: CoachProgramDetail?
    @State private var mood = ""
    @State private var weight = ""
    @State private var loading = false
    @State private var errorMessage: String?

    private let service = CoachService()

    private var isWeightProgram: Bool {
        detail?.category == "weight"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(
                    title: LocalizedStringKey(stringLiteral: detail?.title ?? NSLocalizedString("coach_title", comment: "")),
                    subtitle: "coach_subtitle"
                )

                VStack(alignment: .leading, spacing: 14) {
                    if loading && detail == nil {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                    if let err = errorMessage {
                        Text(err).font(.system(size: 13)).foregroundColor(SanadTheme.error)
                    }
                    if let detail {
                        checkinCard()
                        tasksCard(detail)
                        checkinsHistoryCard(detail)
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

    private func checkinCard() -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("coach_checkin_title")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                if isWeightProgram {
                    TextField("coach_checkin_weight_hint", text: $weight)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    TextField("coach_checkin_mood_hint", text: $mood)
                        .textFieldStyle(.roundedBorder)
                    Button("coach_checkin_submit") { Task { await submitCheckin() } }
                        .buttonStyle(SanadPrimaryButtonStyle())
                }
            }
        }
    }

    private func tasksCard(_ detail: CoachProgramDetail) -> some View {
        SanadListCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("coach_tasks_title")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SanadTheme.onBg)
                let items = detail.items ?? []
                if items.isEmpty {
                    SanadEmptyState(message: "common_no_items")
                } else {
                    ForEach(items) { item in
                        Button {
                            Task { await toggle(item) }
                        } label: {
                            HStack {
                                (item.is_done == true ? SanadIcon.success.image : SanadIcon.placeholder.image)
                                    .foregroundColor(SanadTheme.primary)
                                Text(item.title ?? "")
                                    .foregroundColor(SanadTheme.onBg)
                                Spacer()
                            }
                        }
                        if item.id != items.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func checkinsHistoryCard(_ detail: CoachProgramDetail) -> some View {
        if let checkins = detail.checkins, !checkins.isEmpty {
            SanadListCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("coach_checkins_history")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SanadTheme.onBg)
                    ForEach(checkins) { checkin in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Self.formatLoggedAt(checkin.logged_at))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(SanadTheme.onBg)
                            Text(checkinLine(checkin))
                                .font(.system(size: 13))
                                .foregroundColor(SanadTheme.placeholder)
                        }
                    }
                }
            }
        }
    }

    private func checkinLine(_ checkin: CoachCheckin) -> String {
        var parts: [String] = []
        parts.append(checkin.mood ?? "—")
        if let weight = checkin.weight_kg {
            parts.append(String(format: NSLocalizedString("coach_checkin_weight_fmt", comment: ""), String(weight)))
        }
        if let note = checkin.note, !note.isEmpty {
            parts.append(note)
        }
        return parts.joined(separator: " · ")
    }

    private static func formatLoggedAt(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "—" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        let date = iso.date(from: raw) ?? fallback.date(from: raw)
        guard let date else { return raw }
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else { return }
        loading = true
        defer { loading = false }
        do {
            let program = try await service.show(id: programId, token: token)
            await MainActor.run {
                detail = program
                errorMessage = nil
            }
        } catch {
            await MainActor.run { errorMessage = NSLocalizedString("coach_error", comment: "") }
        }
    }

    private func submitCheckin() async {
        guard let token = KeychainHelper.getToken() else { return }
        let trimmed = mood.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let weightValue = Double(weight.trimmingCharacters(in: .whitespacesAndNewlines))
        do {
            try await service.checkin(
                programId: programId,
                mood: trimmed,
                note: nil,
                weightKg: isWeightProgram ? weightValue : nil,
                token: token
            )
            await MainActor.run {
                mood = ""
                weight = ""
            }
            await load()
        } catch {
            await MainActor.run { errorMessage = NSLocalizedString("coach_error", comment: "") }
        }
    }

    private func toggle(_ item: CoachPlanItem) async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await service.toggleItem(itemId: item.id, token: token)
            await load()
        } catch {
            await MainActor.run { errorMessage = NSLocalizedString("coach_error", comment: "") }
        }
    }
}
