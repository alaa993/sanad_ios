import SwiftUI

struct SpecialistEditView: View {
    let profile: SpecialistProfileData?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var specialty = ""
    @State private var years = ""
    @State private var rate = ""
    @State private var currency = ""
    @State private var languagesText = ""
    @State private var accepting = false
    @State private var showImagePicker = false
    @State private var avatarData: Data?
    @State private var avatarUrl: String?
    @State private var saving = false
    @State private var errorMessage: String?

    private let service = SpecialistProfileService()

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack { editContent }
            } else {
                NavigationView { editContent }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(data: $avatarData)
        }
        .onChange(of: avatarData) {
            if let data = avatarData {
                Task { await uploadAvatar(data) }
            }
        }
        .onAppear {
            populate()
        }
    }

    private var editContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let url = avatarUrl, let imageUrl = URL(string: url) {
                    AsyncImage(url: imageUrl) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(SanadTheme.placeholder.opacity(0.3))
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(SanadTheme.primary.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .overlay(SanadIcon.profile.image.font(.system(size: 50)).foregroundColor(SanadTheme.primary))
                }

                Button("specialist_edit_change_photo") {
                    showImagePicker = true
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SanadTheme.primary)

                Group {
                    formField(title: "specialist_edit_specialty", text: $specialty)
                    formField(title: "specialist_edit_years", text: $years, keyboardType: .numberPad)
                    formField(title: "specialist_edit_rate", text: $rate, keyboardType: .numberPad)
                    formField(title: "specialist_edit_currency", text: $currency)
                    formField(title: "specialist_edit_languages", text: $languagesText)
                    Toggle("specialist_edit_accepting", isOn: $accepting)
                }
                .padding(.horizontal, 24)

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.system(size: 13))
                }

                Button(saving ? "specialist_edit_saving" : "common_save") {
                    Task { await save() }
                }
                .disabled(saving)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(SanadTheme.primary))
                .foregroundColor(SanadTheme.onPrimary)
                .padding(.horizontal, 24)
            }
            .padding(.top, 20)
        }
        .navigationTitle("specialist_edit_title")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common_close") { dismiss() }
            }
        }
    }

    private func populate() {
        specialty = profile?.specialty ?? ""
        years = profile?.years_exp.map { String($0) } ?? ""
        rate = profile?.rate_cents.map { String($0) } ?? ""
        currency = profile?.currency ?? ""
        languagesText = profile?.languages?.joined(separator: ", ") ?? ""
        accepting = profile?.accepting_new ?? false
        avatarUrl = profile?.avatar
    }

    private func formField(title: LocalizedStringKey, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(SanadTheme.placeholder)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .keyboardType(keyboardType)
        }
    }

    private func save() async {
        guard !saving else { return }
        guard let token = KeychainHelper.getToken() else {
            errorMessage = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        saving = true
        var payload: [String: Any] = [:]
        if !specialty.trimmingCharacters(in: .whitespaces).isEmpty {
            payload["specialty"] = specialty.trimmingCharacters(in: .whitespaces)
        }
        if let yearsInt = Int(years.trimmingCharacters(in: .whitespaces)) {
            payload["years_exp"] = yearsInt
        }
        if let rateInt = Int(rate.trimmingCharacters(in: .whitespaces)) {
            payload["rate_cents"] = rateInt
        }
        let trimmedCurrency = currency.trimmingCharacters(in: .whitespaces)
        if !trimmedCurrency.isEmpty {
            payload["currency"] = trimmedCurrency.uppercased()
        }
        let langs = languagesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if !langs.isEmpty {
            payload["languages"] = langs
        }
        payload["accepting_new"] = accepting
        do {
            try await service.updateProfile(token: token, payload: payload)
            await MainActor.run {
                errorMessage = nil
                onSave()
                dismiss()
            }
        } catch {
            await MainActor.run { errorMessage = NSLocalizedString("specialist_edit_save_failed", comment: "") }
        }
        saving = false
    }

    private func uploadAvatar(_ data: Data) async {
        guard let token = KeychainHelper.getToken() else {
            errorMessage = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        do {
            let url = try await service.uploadAvatar(token: token, data: data, filename: "avatar.jpg", mime: "image/jpeg")
            await MainActor.run {
                avatarUrl = url
                errorMessage = nil
            }
        } catch {
            await MainActor.run { errorMessage = NSLocalizedString("specialist_edit_photo_failed", comment: "") }
        }
    }
}

#Preview { SpecialistEditView(profile: nil) {} }
