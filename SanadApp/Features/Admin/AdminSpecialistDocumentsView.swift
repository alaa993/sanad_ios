import SwiftUI

struct AdminSpecialistDocumentsView: View {
    let specialistId: Int
    let specialistName: String?

    @State private var documents: AdminSpecialistDocuments?
    @State private var error: String?
    @State private var reviewNotes = ""
    @State private var verifiedDocIds: Set<Int> = []
    @State private var showReviewAlert = false
    @State private var reviewMessage = ""

    private let service = AdminService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let err = error {
                    Text(err).foregroundColor(.red)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(specialistName ?? NSLocalizedString("admin_specialist_docs_title", comment: ""))
                        .font(.system(size: 20, weight: .semibold))
                    if let status = documents?.status {
                        Text(String(format: NSLocalizedString("admin_specialist_docs_status", comment: ""), status))
                            .font(.system(size: 12))
                            .foregroundColor(SanadTheme.placeholder)
                    }
                    if let notes = documents?.verification_notes, !notes.isEmpty {
                        Text(String(format: NSLocalizedString("admin_specialist_docs_notes", comment: ""), notes))
                            .font(.system(size: 12))
                            .foregroundColor(SanadTheme.placeholder)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("admin_specialist_docs_section")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(SanadTheme.placeholder)

                    let list = documents?.documents ?? []
                    if list.isEmpty {
                        Text("admin_specialist_docs_empty")
                            .font(.system(size: 12))
                            .foregroundColor(SanadTheme.placeholder)
                    } else {
                        ForEach(list) { doc in
                            documentRow(doc)
                        }
                    }
                }

                reviewSection
            }
            .padding(20)
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationTitle("admin_specialist_docs_title")
        .task { await load() }
        .refreshable { await load() }
        .alert(reviewMessage, isPresented: $showReviewAlert) {
            Button("common_ok", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func documentRow(_ doc: AdminSpecialistDocument) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: bindingForDoc(doc.id)) {
                Text(doc.title ?? NSLocalizedString("admin_specialist_docs_document_default", comment: ""))
                    .font(.system(size: 14, weight: .semibold))
            }
            if let type = doc.type {
                Text(String(format: NSLocalizedString("admin_specialist_docs_type", comment: ""), type))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
            }
            if let verified = doc.verified_at {
                Text(String(format: NSLocalizedString("admin_specialist_docs_verified", comment: ""), verified))
                    .font(.system(size: 12))
                    .foregroundColor(SanadTheme.placeholder)
            }
            if let url = documentURL(doc.file_path) {
                Link("admin_specialist_docs_open_file", destination: url)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SanadTheme.primary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(SanadTheme.surface))
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("admin_review_verify_hint")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)
            TextField("admin_review_notes_hint", text: $reviewNotes, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 12) {
                Button("admin_review_approve") {
                    Task { await submitReview(status: "approved") }
                }
                .buttonStyle(.borderedProminent)
                Button("admin_review_reject") {
                    Task { await submitReview(status: "rejected") }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.top, 8)
    }

    private func bindingForDoc(_ id: Int) -> Binding<Bool> {
        Binding(
            get: { verifiedDocIds.contains(id) },
            set: { checked in
                if checked { verifiedDocIds.insert(id) } else { verifiedDocIds.remove(id) }
            }
        )
    }

    private func documentURL(_ path: String?) -> URL? {
        AppConfig.storageURL(for: path)
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        do {
            let res = try await service.specialistDocuments(id: specialistId, token: token)
            await MainActor.run {
                self.documents = res
                self.error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("admin_specialist_docs_load_failed", comment: "") }
        }
    }

    private func submitReview(status: String) async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await service.reviewSpecialist(
                id: specialistId,
                status: status,
                notes: reviewNotes,
                verifiedDocuments: Array(verifiedDocIds),
                token: token
            )
            await MainActor.run {
                reviewMessage = NSLocalizedString("admin_review_complete", comment: "")
                showReviewAlert = true
            }
            await load()
        } catch {
            await MainActor.run {
                reviewMessage = NSLocalizedString("admin_review_fetch_error", comment: "")
                showReviewAlert = true
            }
        }
    }
}

#Preview { NavigationView { AdminSpecialistDocumentsView(specialistId: 1, specialistName: "Specialist") } }
