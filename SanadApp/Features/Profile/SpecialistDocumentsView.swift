import SwiftUI

struct SpecialistDocumentsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var documents: [SpecialistDocument] = []
    @State private var loading = false
    @State private var error: String?
    @State private var uploading = false
    @State private var showPicker = false

    private let service = SpecialistProfileService()

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack { documentsContent }
            } else {
                NavigationView { documentsContent }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showPicker) {
            DocumentPicker { url in
                showPicker = false
                Task { await upload(url: url) }
            }
        }
    }

    private var documentsContent: some View {
        VStack {
            if loading {
                ProgressView()
            }
            if let err = error {
                Text(err)
                    .foregroundColor(.red)
                    .font(.system(size: 13))
            }
            List {
                ForEach(documents) { doc in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(doc.title ?? doc.type ?? NSLocalizedString("specialist_docs_document_default", comment: ""))
                            .font(.system(size: 15, weight: .semibold))
                        if let original = doc.meta?.original_name {
                            Text(original)
                                .font(.system(size: 12))
                                .foregroundColor(SanadTheme.placeholder)
                        }
                        HStack {
                            Spacer()
                            Button("specialist_docs_delete") {
                                Task { await delete(doc: doc) }
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            Spacer()
            Button(uploading ? "specialist_docs_uploading" : "specialist_docs_upload_new") {
                showPicker = true
            }
            .disabled(uploading)
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Capsule().fill(SanadTheme.primary))
            .foregroundColor(SanadTheme.onPrimary)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .navigationTitle("specialist_docs_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common_close") { dismiss() }
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
            let profile = try await service.fetchProfile(token: token)
            await MainActor.run {
                documents = profile.documents ?? []
                error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("specialist_docs_load_failed", comment: "") }
        }
        loading = false
    }

    private func upload(url: URL) async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        uploading = true
        do {
            let doc = try await service.uploadDocument(token: token, url: url, type: "document", title: url.deletingPathExtension().lastPathComponent)
            await MainActor.run {
                documents.insert(doc, at: 0)
                error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("specialist_docs_upload_failed", comment: "") }
        }
        uploading = false
    }

    private func delete(doc: SpecialistDocument) async {
        guard let token = KeychainHelper.getToken() else { return }
        do {
            try await service.deleteDocument(token: token, id: doc.id)
            await MainActor.run {
                documents.removeAll { $0.id == doc.id }
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("specialist_docs_delete_failed", comment: "") }
        }
    }
}

#Preview { SpecialistDocumentsView() }
