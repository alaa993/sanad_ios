import SwiftUI

public struct RegisterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.defaultLanguage.rawValue
    @AppStorage("onboarding_done") private var onboardingDone = false

    @State private var role: RegisterRole = .patient
    @State private var name: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var securityAnswer: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var showPassword = false
    @State private var error: String?
    @State private var showAlert = false
    @State private var alertMessage = ""

    public var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    content
                }
                .navigationBarHidden(true)
            } else {
                NavigationView {
                    content
                        .navigationBarHidden(true)
                }
            }
        }
    }

    private var content: some View {
        return ZStack(alignment: .top) {
            SanadAtmosphereBackground()

            ScrollView {
                VStack(spacing: 16) {
                    Image(SanadTheme.logoName(background: false))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .padding(.top, 8)
                    titleSection
                    ZStack {
                        formCard
                        if authVM.isRegistering {
                            Color.black.opacity(0.08)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            ProgressView("register_progress_message")
                                .padding(24)
                                .background(RoundedRectangle(cornerRadius: 16).fill(SanadTheme.surface))
                                .foregroundColor(SanadTheme.onBg)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .dismissKeyboardOnTap()
        // Prevent double mirroring since this view manually flips layout for RTL.
        .environment(\.layoutDirection, .leftToRight)
        .alert(alertMessage, isPresented: $showAlert) {
            Button("common_ok", role: .cancel) {}
        }
    }

    private var titleSection: some View {
        let isRTL = isRTLLanguage
        return VStack(spacing: 6) {
            Text("register_title")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(SanadTheme.onBg)
            Text("register_subtitle")
                .font(.system(size: 14))
                .foregroundColor(SanadTheme.onBg)
        }
        .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
    }

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguage) ?? AppLanguage.defaultLanguage
    }

    private var formCard: some View {
        let isRTL = isRTLLanguage
        return VStack(alignment: isRTL ? .trailing : .leading, spacing: 12) {
            Text("register_role_label")
                .font(.system(size: 14))
                .foregroundColor(SanadTheme.onBg)
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
            Picker("register_role_label", selection: $role) {
                ForEach(RegisterRole.allCases, id: \.self) { role in
                    Text(role.title).tag(role)
                }
            }
            .pickerStyle(.menu)
            .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(SanadTheme.fieldBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(SanadTheme.fieldStroke, lineWidth: 1)
                    )
            )

            if role == .patient {
                Text("register_patient_privacy_note")
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.primary)
                    .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
            }

            TextField("nickname", text: $name)
                .textInputAutocapitalization(.never)
                .multilineTextAlignment(isRTL ? .trailing : .leading)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(fieldBackground)

            passwordField(label: "password", text: $password)
            passwordField(label: "register_confirm_password", text: $confirmPassword)

            Text("security_question_text")
                .font(.system(size: 14))
                .foregroundColor(SanadTheme.onBg)
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)

            TextField("security_answer_hint", text: $securityAnswer)
                .textInputAutocapitalization(.never)
                .multilineTextAlignment(isRTL ? .trailing : .leading)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(fieldBackground)

            if showContactFields {
                Text("register_contact_fields_label")
                    .font(.system(size: 13))
                    .foregroundColor(SanadTheme.placeholder)
                    .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)

                TextField("register_email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .multilineTextAlignment(isRTL ? .trailing : .leading)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(fieldBackground)

                TextField("register_phone", text: $phone)
                    .keyboardType(.phonePad)
                    .textInputAutocapitalization(.never)
                    .multilineTextAlignment(isRTL ? .trailing : .leading)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(fieldBackground)
            }

            Button(action: { Task { await registerAccount() } }) {
                Text("register")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SanadTheme.onPrimary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 28)
                    .background(
                        Capsule().fill(SanadTheme.primary)
                    )
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .disabled(authVM.isRegistering)

            Button("action_login_here") { dismiss() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SanadTheme.primary)
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
        }
        .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(SanadTheme.surface)
        )
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(SanadTheme.fieldBg)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(SanadTheme.fieldStroke, lineWidth: 1)
            )
    }

    private func passwordField(label: LocalizedStringKey, text: Binding<String>) -> some View {
        let isRTL = isRTLLanguage
        return HStack {
            if isRTL {
                Button(action: { showPassword.toggle() }) {
                    (showPassword ? SanadIcon.eyeOff.image : SanadIcon.eye.image)
                        .foregroundColor(SanadTheme.placeholder)
                }
            }

            Group {
                if showPassword {
                    TextField(label, text: text)
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(isRTL ? .trailing : .leading)
                        .padding(.horizontal, 14)
                } else {
                    SecureField(label, text: text)
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(isRTL ? .trailing : .leading)
                        .padding(.horizontal, 14)
                }
            }

            if !isRTL {
                Button(action: { showPassword.toggle() }) {
                    (showPassword ? SanadIcon.eyeOff.image : SanadIcon.eye.image)
                        .foregroundColor(SanadTheme.placeholder)
                }
            }
        }
        .frame(height: 48)
        .background(fieldBackground)
    }

    private var showContactFields: Bool {
        role != .patient
    }

    @MainActor
    private func registerAccount() async {
        error = nil
        alertMessage = ""
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !password.isEmpty else {
            alertMessage = NSLocalizedString("error_required_fields", comment: "")
            showAlert = true
            return
        }
        guard !securityAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = NSLocalizedString("security_answer_required", comment: "")
            showAlert = true
            return
        }
        guard password.count >= 6 else {
            alertMessage = NSLocalizedString("register_error_password_short", comment: "")
            showAlert = true
            return
        }
        guard password == confirmPassword else {
            alertMessage = NSLocalizedString("register_error_password_mismatch", comment: "")
            showAlert = true
            return
        }
        if showContactFields {
            guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                alertMessage = NSLocalizedString("error_required_fields", comment: "")
                showAlert = true
                return
            }
        }

        let locale = AppLanguage.currentCode
        let timezone = TimeZone.current.identifier
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.count >= 2 else {
            alertMessage = NSLocalizedString("register_error_name_short", comment: "")
            showAlert = true
            return
        }
        let request = RegisterRequest(
            name: trimmedName,
            email: showContactFields ? trimmedEmail : nil,
            password: password,
            phone: showContactFields && !trimmedPhone.isEmpty ? trimmedPhone : nil,
            locale: locale,
            timezone: timezone,
            role: role.rawValue
        )

        do {
            try await authVM.register(request)
            try await authVM.saveSecurityAnswer(username: trimmedName, answer: securityAnswer.trimmingCharacters(in: .whitespacesAndNewlines))
            onboardingDone = false
        } catch {
            self.error = error.localizedDescription
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private enum RegisterRole: String, CaseIterable {
        case patient
        case specialist
        case organization

        var title: String {
            switch self {
            case .patient: return NSLocalizedString("role_patient", comment: "")
            case .specialist: return NSLocalizedString("role_specialist", comment: "")
            case .organization: return NSLocalizedString("role_organization", comment: "")
            }
        }
    }

    private var isRTLLanguage: Bool {
        currentLanguage == .ar
    }
}
