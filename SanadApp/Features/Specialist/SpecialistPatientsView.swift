import SwiftUI

/// قائمة مرضى الأخصائي — اختصار من لوحة التحكم.
struct SpecialistPatientsView: View {
    @State private var patients: [SpecialistPatientMini] = []
    @State private var search = ""
    @State private var loading = false
    @State private var error: String?

    private let service = SpecialistService()

    private var filteredPatients: [SpecialistPatientMini] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return patients }
        return patients.filter { patient in
            let name = (patient.name ?? "").lowercased()
            return name.contains(q) || String(patient.id).contains(q)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SanadHeroHeader(title: "nav_patients")

                VStack(alignment: .leading, spacing: 14) {
                    SanadSearchField(text: $search, prompt: "community_search_hint")

                    if loading && patients.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                    } else if let error {
                        Text(error).foregroundColor(SanadTheme.error).font(.system(size: 13))
                    } else if filteredPatients.isEmpty {
                        SanadEmptyState(message: "specialist_patient_file_empty")
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredPatients) { patient in
                                NavigationLink(
                                    destination: SpecialistPatientFileView(sessionId: 0, patientId: patient.id)
                                ) {
                                    patientCard(patient)
                                }
                                .buttonStyle(.plain)
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

    private func patientCard(_ patient: SpecialistPatientMini) -> some View {
        SanadListCard {
            HStack(spacing: 12) {
                Circle()
                    .fill(SanadTheme.primary.opacity(0.12))
                    .frame(width: 44, height: 44)
                    .overlay(
                        SanadIcon.profile.image
                            .foregroundColor(SanadTheme.primary)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(patient.name ?? "—")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(SanadTheme.onBg)
                    Text(String(format: NSLocalizedString("specialist_patient_file_id", comment: ""), patient.id))
                        .font(.system(size: 12))
                        .foregroundColor(SanadTheme.placeholder)
                }
                Spacer(minLength: 0)
                SanadIcon.chevronLeft.image
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SanadTheme.placeholder)
            }
        }
    }

    private func load() async {
        guard let token = KeychainHelper.getToken() else { return }
        loading = true
        defer { loading = false }
        do {
            patients = try await service.patients(token: token)
            error = nil
        } catch {
            self.error = NSLocalizedString("specialist_dashboard_load_failed", comment: "")
        }
    }
}
