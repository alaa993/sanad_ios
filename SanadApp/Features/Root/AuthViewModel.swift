import Foundation

/// Root auth state for AuthGate: bootstrap token validation, login/register, role, push deep links, logout.
@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    /// True until first bootstrap finishes (token validate / clear).
    @Published var isBootstrapping = true
    @Published var userRole: String?
    @Published var errorMessage: String?
    @Published var currentUser: User?
    @Published var isAuthenticating = false
    @Published var isRegistering = false
    /// طلب التنقل لتبويب معيّن (مثل `navigateHome` بعد تغيير كلمة المرور على Android).
    @Published var preferredTab: TabKind?
    @Published var pendingPushRoute: PushDeepLink?

    private let service = AuthService()
    private let accountService = AccountService()
    private var pushObserver: NSObjectProtocol?

    init() {
        pushObserver = NotificationCenter.default.addObserver(
            forName: .sanadPushDeepLink,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let route = notification.object as? PushDeepLink else { return }
            Task { @MainActor in
                self?.pendingPushRoute = route
            }
        }
    }

    deinit {
        if let pushObserver {
            NotificationCenter.default.removeObserver(pushObserver)
        }
    }

    func login(identifier: String, password: String) async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            let res = try await service.login(identifier: identifier, password: password)
            guard let token = res.token else {
                errorMessage = res.message ?? "فشل تسجيل الدخول"
                return
            }
            KeychainHelper.saveToken(token)
            isAuthenticated = true

            if (let user = res.user) {
                userRole = user.role
                currentUser = user
                Self.cacheRole(user.role)
                startRealtime(for: user, token: token)
            } else if let me = try? await service.me(token: token) {
                userRole = me.role
                currentUser = me
                Self.cacheRole(me.role)
                startRealtime(for: me, token: token)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Validate Keychain token via /auth/me, wire RealtimeSocket, or clear session on 401.
    func bootstrap() async {
        defer { isBootstrapping = false }
        guard let token = KeychainHelper.getToken(), !token.isEmpty else {
            clearLocalSession(keepBootstrappingFlag: true)
            return
        }
        do {
            let me = try await service.me(token: token)
            userRole = me.role
            currentUser = me
            isAuthenticated = true
            Self.cacheRole(me.role)
            startRealtime(for: me, token: token)
        } catch {
            if Self.isSessionInvalid(error) {
                clearLocalSession(keepBootstrappingFlag: true)
            } else {
                // Transient network error: keep token + last known role for a safe offline shell.
                userRole = Self.cachedRole()
                isAuthenticated = true
            }
        }
    }

    func refreshUser() async {
        guard let token = KeychainHelper.getToken(), !token.isEmpty else {
            clearLocalSession()
            return
        }
        do {
            let me = try await service.me(token: token)
            currentUser = me
            userRole = me.role
            isAuthenticated = true
            Self.cacheRole(me.role)
            startRealtime(for: me, token: token)
        } catch {
            if Self.isSessionInvalid(error) {
                clearLocalSession()
            }
        }
    }

    /// Clears local auth without waiting on remote logout (used for deleted/expired sessions).
    private func clearLocalSession(keepBootstrappingFlag: Bool = false) {
        isAuthenticated = false
        userRole = nil
        currentUser = nil
        RealtimeSocket.shared.disconnect()
        KeychainHelper.clearToken()
        Self.cacheRole(nil)
        MemoryTTLCache.shared.removePrefix("dashboard:")
        MemoryTTLCache.shared.removePrefix("sessions:")
        if !keepBootstrappingFlag {
            isBootstrapping = false
        }
    }

    private static let roleCacheKey = "sanad_cached_user_role"

    private static func cacheRole(_ role: String?) {
        if let role, !role.isEmpty {
            UserDefaults.standard.set(role, forKey: roleCacheKey)
        } else {
            UserDefaults.standard.removeObject(forKey: roleCacheKey)
        }
    }

    private static func cachedRole() -> String? {
        UserDefaults.standard.string(forKey: roleCacheKey)
    }

    private static func isSessionInvalid(_ error: Error) -> Bool {
        if let auth = error as? AuthServiceError {
            return auth.isSessionInvalid
        }
        return false
    }

    func resubmit() async {
        guard let role = currentUser?.role, let token = KeychainHelper.getToken() else { return }
        do {
            if role == "specialist" {
                try await accountService.resubmitSpecialist(token: token)
            } else if role == "organization" {
                try await accountService.resubmitOrg(token: token)
            } else { return }
            await refreshUser()
        } catch {
            await MainActor.run { self.errorMessage = "تعذر إعادة الإرسال" }
        }
    }

    func requestTab(_ tab: TabKind) {
        preferredTab = tab
    }

    func logout() {
        let token = KeychainHelper.getToken()
        isAuthenticated = false
        userRole = nil
        currentUser = nil
        RealtimeSocket.shared.disconnect()
        KeychainHelper.clearToken()
        MemoryTTLCache.shared.removePrefix("dashboard:")
        MemoryTTLCache.shared.removePrefix("sessions:")
        if let token {
            Task.detached(priority: .utility) {
                await PushNotificationManager.shared.unregisterBeforeLogout(authToken: token)
                await AuthService().logout(token: token)
            }
        }
    }

    func register(_ request: RegisterRequest) async throws {
        guard !isRegistering else { return }
        isRegistering = true
        defer { isRegistering = false }
        let res = try await service.register(request)
        guard let token = res.token else {
            throw AuthServiceError.server(res.message ?? "فشل إنشاء الحساب")
        }
        KeychainHelper.saveToken(token)
        isAuthenticated = true
        if let user = res.user {
            userRole = user.role
            currentUser = user
            startRealtime(for: user, token: token)
        } else if let me = try? await service.me(token: token) {
            userRole = me.role
            currentUser = me
            startRealtime(for: me, token: token)
        }
    }

    func saveSecurityAnswer(username: String, answer: String) async throws {
        try await service.saveSecurityAnswer(username: username, answer: answer)
    }

    func forgotLookup(username: String) async throws -> AuthService.ForgotLookup {
        try await service.forgotLookup(username: username)
    }

    func resetPasswordWithAnswer(username: String, answer: String, newPassword: String, confirmPassword: String) async throws {
        try await service.resetPasswordWithAnswer(username: username, answer: answer, newPassword: newPassword, confirmPassword: confirmPassword)
    }

    func reconnectRealtime() {
        guard let user = currentUser, let token = KeychainHelper.getToken() else { return }
        RealtimeSocket.shared.reconnectIfNeeded(
            userId: String(user.id),
            role: user.role,
            token: token
        )
    }

    private func startRealtime(for user: User, token: String) {
        RealtimeSocket.shared.connect(userId: String(user.id), role: user.role, token: token)
    }
}
