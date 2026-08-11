import SwiftUI

enum ChangePasswordScope {
    case user
    case admin
}

struct ChangePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var saving = false

    var scope: ChangePasswordScope = .user
    let onSuccess: () -> Void

    private let profileService = ProfileService()
    private let adminService = AdminProfileService()

    var body: some View {
        NavigationView {
            Form {
                SecureField("admin_profile_current_password", text: $currentPassword)
                SecureField("admin_profile_new_password", text: $newPassword)
                SecureField("admin_profile_confirm_password", text: $confirmPassword)
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.system(size: 13))
                }
            }
            .navigationTitle("admin_profile_change_password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("admin_profile_save_password") {
                        Task { await save() }
                    }
                    .disabled(saving)
                }
            }
        }
    }

    private func save() async {
        let pass = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let confirm = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pass.isEmpty else {
            errorMessage = NSLocalizedString("admin_profile_password_required", comment: "")
            return
        }
        guard pass == confirm else {
            errorMessage = NSLocalizedString("error_password_mismatch", comment: "")
            return
        }
        guard let token = KeychainHelper.getToken() else {
            errorMessage = NSLocalizedString("error_not_logged_in", comment: "")
            return
        }
        saving = true
        defer { saving = false }
        do {
            switch scope {
            case .user:
                try await profileService.changePassword(
                    token: token,
                    current: currentPassword,
                    password: pass,
                    confirm: confirm
                )
            case .admin:
                try await adminService.changePassword(
                    token: token,
                    current: currentPassword,
                    password: pass,
                    confirm: confirm
                )
            }
            await MainActor.run {
                onSuccess()
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = NSLocalizedString("profile_password_update_failed", comment: "")
            }
        }
    }
}
