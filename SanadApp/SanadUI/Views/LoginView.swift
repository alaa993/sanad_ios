import SwiftUI

public struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.defaultLanguage.rawValue
    @State private var user = ""
    @State private var pass = ""
    @State private var showPassword = false
    @State private var showForgotSheet = false
    @State private var forgotUsername = ""
    @State private var forgotAnswer = ""
    @State private var forgotNewPassword = ""
    @State private var forgotConfirmPassword = ""
    @State private var forgotError: String?
    @State private var forgotInfo: String?
    @State private var forgotQuestion: String = ""
    @State private var forgotHasSecurity = false
    @State private var forgotAccountFound = false
    @State private var forgotLookupBusy = false
    @State private var forgotLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    public init() {}

	public var body: some View {
		navigationContainer
	}

	@ViewBuilder
	private var navigationContainer: some View {
		if #available(iOS 16, *) {
			NavigationStack {
				loginContent
			}
			.navigationBarHidden(true)
		} else {
			NavigationView {
				loginContent
			}
			.navigationViewStyle(.stack)
			.navigationBarHidden(true)
		}
	}

    private var loginContent: some View {
		return ZStack(alignment: .top) {
			SanadAtmosphereBackground()

			VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Image(currentLogoName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                    Text("app_name")
                        .font(SanadFont.display(30))
                        .foregroundColor(SanadTheme.primary)
                    Text("login_brand_tagline")
                        .font(SanadFont.body(14))
                        .foregroundColor(SanadTheme.placeholder)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 36)
                .padding(.horizontal, 24)

                ZStack {
                    loginCard
            if authVM.isAuthenticating {
                Color.black.opacity(0.08)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                ProgressView("login_loading")
                            .padding(24)
                            .background(RoundedRectangle(cornerRadius: 16).fill(SanadTheme.surface))
                            .foregroundColor(SanadTheme.onBg)
                    }
                }
				.padding(.horizontal, 20)
				.padding(.top, 28)
				.shadow(color: SanadTheme.subtleShadow.opacity(0.25), radius: 10, y: 6)

				Spacer()
			}
			.padding(.top, 6)
		}
        .sheet(isPresented: $showForgotSheet, onDismiss: resetForgotState) {
            forgotPasswordSheet
		}
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .dismissKeyboardOnTap()
        // Prevent double mirroring since this view manually flips layout for RTL.
        .environment(\.layoutDirection, .leftToRight)
        .alert(alertMessage, isPresented: $showAlert) {
            Button("common_ok", role: .cancel) {}
        }
	}

    private var loginCard: some View {
        let isRTL = isRTLLanguage
        return VStack(alignment: isRTL ? .trailing : .leading, spacing: 12) {
            Text("login_title")
                .font(SanadFont.title(22))
                .foregroundColor(SanadTheme.onBg)
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
            Text("login_subtitle")
                .font(SanadFont.body(14))
                .foregroundColor(SanadTheme.placeholder)
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)

            emailLoginFields(isRTL: isRTL)

            Text("login_privacy_hint")
                .font(.system(size: 12))
                .foregroundColor(SanadTheme.placeholder)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)

            HStack {
                if isRTL {
                    NavigationLink(destination: RegisterView()) {
                        Text("login_create_account")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(SanadTheme.primary)
                    }
                    Text("login_no_account")
                        .font(.system(size: 13))
                        .foregroundColor(SanadTheme.placeholder)
                } else {
                    Text("login_no_account")
                        .font(.system(size: 13))
                        .foregroundColor(SanadTheme.placeholder)
                    NavigationLink(destination: RegisterView()) {
                        Text("login_create_account")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(SanadTheme.primary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
        }
        .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(SanadTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(SanadTheme.fieldStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func emailLoginFields(isRTL: Bool) -> some View {
        field(text: $user, placeholder: "username", icon: "envelope")
        passwordField
        authErrorView(isRTL: isRTL)
        HStack {
            if isRTL { Spacer() }
            Button("forgot_password") {
                let trimmedUser = user.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedUser.isEmpty else {
                    alertMessage = NSLocalizedString("enter_username", comment: "")
                    showAlert = true
                    return
                }
                forgotUsername = trimmedUser
                showForgotSheet = true
                Task { await lookupForgotAccount() }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(SanadTheme.primary)
            if !isRTL { Spacer() }
        }
        primaryLoginButton(title: "login") {
            let trimmedUser = user.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPass = pass.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedUser.isEmpty, !trimmedPass.isEmpty else {
                alertMessage = NSLocalizedString("error_required_fields", comment: "")
                showAlert = true
                return
            }
            authVM.errorMessage = nil
            Task {
                await authVM.login(identifier: trimmedUser, password: trimmedPass)
                if let err = authVM.errorMessage, !err.isEmpty {
                    alertMessage = err
                    showAlert = true
                }
            }
        }
    }

    @ViewBuilder
    private func authErrorView(isRTL: Bool) -> some View {
        if let error = authVM.errorMessage {
            Text(error)
                .font(.system(size: 13))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
        }
    }

    private func primaryLoginButton(title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if authVM.isAuthenticating {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SanadTheme.onPrimary)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 32)
                    .background(Capsule().fill(SanadTheme.primary))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .disabled(authVM.isAuthenticating)
    }

    private var passwordField: some View {
        let isRTL = isRTLLanguage
        return HStack(spacing: 8) {
            if isRTL {
                Button(action: { showPassword.toggle() }) {
                    (showPassword ? SanadIcon.eyeOff.image : SanadIcon.eye.image)
                        .foregroundColor(SanadTheme.placeholder)
                }
            }

            Group {
                if showPassword {
                    TextField("password", text: $pass)
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(isRTL ? .trailing : .leading)
                        .padding(.horizontal, 8)
                } else {
                    SecureField("password", text: $pass)
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(isRTL ? .trailing : .leading)
                        .padding(.horizontal, 8)
                }
            }

            SanadIcon.lock.image
                .foregroundColor(SanadTheme.placeholder)
                .frame(width: 24)

            if !isRTL {
                Button(action: { showPassword.toggle() }) {
                    (showPassword ? SanadIcon.eyeOff.image : SanadIcon.eye.image)
                        .foregroundColor(SanadTheme.placeholder)
                }
            }
        }
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SanadTheme.fieldBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(SanadTheme.fieldStroke, lineWidth: 1)
                )
        )
    }

    private func field(text: Binding<String>, placeholder: LocalizedStringKey, icon: String) -> some View {
        let isRTL = isRTLLanguage
        return HStack(spacing: 8) {
            if !isRTL {
                SanadIcon.forShortcut(id: icon).view(size: 18)
                    .foregroundColor(SanadTheme.placeholder)
                    .frame(width: 24)
            }
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .multilineTextAlignment(isRTL ? .trailing : .leading)
                .padding(.horizontal, 8)
            if isRTL {
                SanadIcon.forShortcut(id: icon).view(size: 18)
                    .foregroundColor(SanadTheme.placeholder)
                    .frame(width: 24)
            }
        }
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SanadTheme.fieldBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(SanadTheme.fieldStroke, lineWidth: 1)
                )
        )
    }

    private var forgotPasswordSheet: some View {
        let isRTL = isRTLLanguage
        return NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("username", text: $forgotUsername)
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(isRTL ? .trailing : .leading)
                        .padding(.horizontal, 12)
                        .frame(height: 48)
                        .background(fieldBackground)
                        .onSubmit { Task { await lookupForgotAccount() } }

                    Button("forgot_password_lookup") {
                        Task { await lookupForgotAccount() }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SanadTheme.primary)
                    .disabled(forgotLookupBusy)

                    if forgotLookupBusy {
                        ProgressView()
                    }

                    if let info = forgotInfo {
                        Text(info)
                            .font(.system(size: 13))
                            .foregroundColor(forgotAccountFound ? SanadTheme.onBg : .red)
                            .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                    }

                    if forgotAccountFound {
                        Text(forgotQuestion.isEmpty ? NSLocalizedString("security_question_text", comment: "") : forgotQuestion)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SanadTheme.onBg)
                            .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)

                        if forgotHasSecurity {
                            TextField("security_answer_hint", text: $forgotAnswer)
                                .textInputAutocapitalization(.never)
                                .multilineTextAlignment(isRTL ? .trailing : .leading)
                                .padding(.horizontal, 12)
                                .frame(height: 48)
                                .background(fieldBackground)

                            SecureField("password", text: $forgotNewPassword)
                                .textInputAutocapitalization(.never)
                                .multilineTextAlignment(isRTL ? .trailing : .leading)
                                .padding(.horizontal, 12)
                                .frame(height: 48)
                                .background(fieldBackground)

                            SecureField("register_confirm_password", text: $forgotConfirmPassword)
                                .textInputAutocapitalization(.never)
                                .multilineTextAlignment(isRTL ? .trailing : .leading)
                                .padding(.horizontal, 12)
                                .frame(height: 48)
                                .background(fieldBackground)
                        }
                    }

                    if let err = forgotError {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                    }
                }
                .padding(16)
            }
            .navigationTitle("forgot_password_title")
            .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_cancel") {
                        showForgotSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if forgotLoading {
                        ProgressView()
                    } else {
                        Button("forgot_password_submit") {
                            Task { await submitForgotPassword() }
                        }
                        .disabled(!forgotAccountFound || !forgotHasSecurity)
                    }
                }
            }
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(SanadTheme.fieldBg)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(SanadTheme.fieldStroke, lineWidth: 1)
            )
    }

    private func resetForgotState() {
        forgotAnswer = ""
        forgotNewPassword = ""
        forgotConfirmPassword = ""
        forgotError = nil
        forgotInfo = nil
        forgotQuestion = ""
        forgotHasSecurity = false
        forgotAccountFound = false
        forgotLookupBusy = false
        forgotLoading = false
    }

    private func lookupForgotAccount() async {
        forgotError = nil
        forgotInfo = nil
        forgotAccountFound = false
        forgotHasSecurity = false
        forgotQuestion = ""
        let username = forgotUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else {
            forgotError = NSLocalizedString("enter_username", comment: "")
            return
        }
        forgotLookupBusy = true
        defer { forgotLookupBusy = false }
        do {
            let info = try await authVM.forgotLookup(username: username)
            if info.exists == true {
                forgotAccountFound = true
                let name = info.name ?? username
                let hint = info.account_hint ?? ""
                forgotInfo = String(format: NSLocalizedString("forgot_password_account_found", comment: ""), name, hint)
                forgotHasSecurity = info.has_security_answer == true
                if forgotHasSecurity {
                    forgotQuestion = info.security_question ?? NSLocalizedString("security_question_text", comment: "")
                } else {
                    forgotQuestion = NSLocalizedString("forgot_password_no_security", comment: "")
                }
            } else {
                forgotInfo = NSLocalizedString("forgot_password_account_not_found", comment: "")
            }
        } catch {
            forgotInfo = NSLocalizedString("forgot_password_lookup_failed", comment: "")
        }
    }

    private func submitForgotPassword() async {
        forgotError = nil
        let username = forgotUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let answer = forgotAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        if username.isEmpty {
            forgotError = NSLocalizedString("enter_username", comment: "")
            return
        }
        if !forgotHasSecurity {
            forgotError = NSLocalizedString("forgot_password_no_security", comment: "")
            return
        }
        if answer.isEmpty {
            forgotError = NSLocalizedString("security_answer_required", comment: "")
            return
        }
        if forgotNewPassword.trimmingCharacters(in: .whitespacesAndNewlines).count < 6 {
            forgotError = NSLocalizedString("admin_profile_password_required", comment: "")
            return
        }
        if forgotNewPassword != forgotConfirmPassword {
            forgotError = NSLocalizedString("error_password_mismatch", comment: "")
            return
        }
        forgotLoading = true
        defer { forgotLoading = false }
        do {
            try await authVM.resetPasswordWithAnswer(username: username, answer: answer, newPassword: forgotNewPassword, confirmPassword: forgotConfirmPassword)
            alertMessage = NSLocalizedString("password_updated", comment: "")
            showAlert = true
            showForgotSheet = false
        } catch {
            forgotError = NSLocalizedString("forgot_password_failed", comment: "")
        }
    }

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguage) ?? AppLanguage.defaultLanguage
    }

    private var isRTLLanguage: Bool {
        currentLanguage == .ar
    }

    private var currentLogoName: String {
        switch AppTheme.current {
        case .sanad:
            return "logo_blue_nobg"
        case .rose:
            return "logo_rose_nobg"
        case .graphite:
            return "logo_gray_nobg"
        }
    }
}
