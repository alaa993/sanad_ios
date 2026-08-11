import SwiftUI

struct GroupPatientPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIds: Set<Int>
    @State private var patients: [SpecialistPatientMini] = []
    @State private var searchText = ""
    @State private var loading = false
    @State private var error: String?

    private let service = SpecialistService()

    var body: some View {
        NavigationView {
            List {
                if let err = error {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                ForEach(filteredPatients) { patient in
                    Button {
                        toggle(patient.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(patient.name ?? NSLocalizedString("role_patient", comment: ""))
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            Spacer()
                            (selectedIds.contains(patient.id) ? SanadIcon.success.image : SanadIcon.placeholder.image)
                                .foregroundColor(SanadTheme.primary)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText)
            .navigationTitle("group_create_pick_beneficiaries")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_close") { dismiss() }
                }
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private var filteredPatients: [SpecialistPatientMini] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return patients }
        let query = searchText.lowercased()
        return patients.filter { ($0.name ?? "").lowercased().contains(query) }
    }

    private func toggle(_ id: Int) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else {
            error = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        loading = true
        do {
            let res = try await service.patients(token: token)
            await MainActor.run {
                patients = res
                error = nil
            }
        } catch {
            await MainActor.run { self.error = NSLocalizedString("group_create_load_beneficiaries_failed", comment: "") }
        }
        loading = false
    }
}

#Preview { GroupPatientPickerView(selectedIds: .constant([])) }
