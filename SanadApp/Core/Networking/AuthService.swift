import Foundation

public struct User: Decodable {
    public let id: Int
    public let name: String
    public let email: String?
    public let phone: String?
    public let role: String
    public let approval_status: String?
    public let organization_status: String?
    public let rejection_reason: String?
    public let org_rejection_reason: String?
    public let org_profile: OrgProfile?
    public let admin_profile: AdminProfile?

    public struct OrgProfile: Decodable {
        public let id: Int?
        public let name: String?
        public let status: String?
        public let review_notes: String?
        public let members: Int?
        public let specialists: Int?
        public let beneficiaries: Int?
        public let wallet_points: Int?
    }

    public struct AdminProfile: Decodable {
        public let pending_specialists: Int?
        public let pending_organizations: Int?
        public let total_users: Int?
        public let total_sessions: Int?
    }

    /// Tolerant of missing/null fields and Int/String id — avoids crashes after API/schema upgrades.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? c.decode(Int.self, forKey: .id) {
            id = intId
        } else if let strId = try? c.decode(String.self, forKey: .id), let parsed = Int(strId) {
            id = parsed
        } else {
            id = 0
        }
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        email = try? c.decodeIfPresent(String.self, forKey: .email)
        phone = try? c.decodeIfPresent(String.self, forKey: .phone)
        role = (try? c.decodeIfPresent(String.self, forKey: .role)) ?? "patient"
        approval_status = try? c.decodeIfPresent(String.self, forKey: .approval_status)
        organization_status = try? c.decodeIfPresent(String.self, forKey: .organization_status)
        rejection_reason = try? c.decodeIfPresent(String.self, forKey: .rejection_reason)
        org_rejection_reason = try? c.decodeIfPresent(String.self, forKey: .org_rejection_reason)
        org_profile = try? c.decodeIfPresent(OrgProfile.self, forKey: .org_profile)
        admin_profile = try? c.decodeIfPresent(AdminProfile.self, forKey: .admin_profile)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, email, phone, role
        case approval_status, organization_status, rejection_reason, org_rejection_reason
        case org_profile, admin_profile
    }
}

public struct LoginResponse: Decodable {
    public let status: String?
    public let message: String?
    public let token: String?
    public let user: User?
}

public struct RegisterRequest: Encodable {
    public let name: String
    public let email: String?
    public let password: String
    public let phone: String?
    public let locale: String
    public let timezone: String
    public let role: String

    public init(name: String, email: String?, password: String, phone: String?, locale: String, timezone: String, role: String) {
        self.name = name
        self.email = email
        self.password = password
        self.phone = phone
        self.locale = locale
        self.timezone = timezone
        self.role = role
    }
}

public enum AuthServiceError: LocalizedError {
    case server(String)
    case invalidResponse
    /// Token invalid / user deleted / forbidden — client must clear local session.
    case unauthorized(Int)

    public var errorDescription: String? {
        switch self {
        case .server(let message):
            return message
        case .invalidResponse:
            return "تعذر الاتصال بالخادم"
        case .unauthorized:
            return "انتهت الجلسة، سجّل الدخول مجددًا"
        }
    }

    public var isSessionInvalid: Bool {
        if case .unauthorized = self { return true }
        return false
    }
}

/// Auth REST: login/register/me/logout and User decoding tolerant of Int/String ids after API upgrades.
public final class AuthService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    /// يدعم البريد الإلكتروني أو اسم المستخدم تلقائيًا حسب الإدخال
    public func login(identifier: String, password: String) async throws -> LoginResponse {
        var req = URLRequest(url: base.appendingPathComponent("auth/login"))
        req.httpMethod = "POST"
        req.timeoutInterval = 12
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // الـ backend يتوقع حقل username حتى لو كانت قيمة بريد
        let body: [String: Any] = ["username": identifier, "password": password]

        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if let message = parseServerMessage(from: data) {
                throw AuthServiceError.server(message)
            }
            throw AuthServiceError.invalidResponse
        }
        return try JSONDecoder().decode(LoginResponse.self, from: data)
    }

    public func register(_ request: RegisterRequest) async throws -> LoginResponse {
        var req = URLRequest(url: base.appendingPathComponent("auth/register"))
        req.httpMethod = "POST"
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(request)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if let message = parseServerMessage(from: data) {
                throw AuthServiceError.server(message)
            }
            throw AuthServiceError.invalidResponse
        }
        return try JSONDecoder().decode(LoginResponse.self, from: data)
    }

    public func socialGoogle(idToken: String) async throws -> LoginResponse {
        var req = URLRequest(url: base.appendingPathComponent("auth/google"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["id_token": idToken])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthServiceError.invalidResponse
        }
        return try JSONDecoder().decode(LoginResponse.self, from: data)
    }

    public func socialApple(idToken: String, name: String?) async throws -> LoginResponse {
        var req = URLRequest(url: base.appendingPathComponent("auth/apple"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["id_token": idToken]
        if let name = name { body["name"] = name }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthServiceError.invalidResponse
        }
        return try JSONDecoder().decode(LoginResponse.self, from: data)
    }

    public func socialFacebook(accessToken: String) async throws -> LoginResponse {
        var req = URLRequest(url: base.appendingPathComponent("auth/facebook"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["access_token": accessToken])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthServiceError.invalidResponse
        }
        return try JSONDecoder().decode(LoginResponse.self, from: data)
    }

    public func me(token: String) async throws -> User {
        var req = URLRequest(url: base.appendingPathComponent("auth/me"))
        req.httpMethod = "GET"
        req.timeoutInterval = 12
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }
        if http.statusCode == 401 || http.statusCode == 403 || http.statusCode == 404 {
            throw AuthServiceError.unauthorized(http.statusCode)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AuthServiceError.invalidResponse
        }
        do {
            let user = try JSONDecoder().decode(User.self, from: data)
            if user.id <= 0 {
                throw AuthServiceError.unauthorized(http.statusCode)
            }
            return user
        } catch let error as AuthServiceError {
            throw error
        } catch {
            // Broken/unexpected payload after an app or schema upgrade — treat as dead session.
            throw AuthServiceError.unauthorized(http.statusCode)
        }
    }

    public func saveSecurityAnswer(username: String, answer: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("auth/security-answer"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "username": username,
            "security_answer": answer
        ])
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func logout(token: String) async {
        var req = URLRequest(url: base.appendingPathComponent("auth/logout"))
        req.httpMethod = "POST"
        req.timeoutInterval = 8
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)
    }

    public struct ForgotLookup: Decodable {
        public let exists: Bool?
        public let name: String?
        public let account_hint: String?
        public let security_question: String?
        public let has_security_answer: Bool?
        public let message: String?
    }

    public func forgotLookup(username: String) async throws -> ForgotLookup {
        var req = URLRequest(url: base.appendingPathComponent("auth/forgot/lookup"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["username": username])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }
        if http.statusCode == 404 {
            return ForgotLookup(exists: false, name: nil, account_hint: nil, security_question: nil, has_security_answer: false, message: "user_not_found")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AuthServiceError.invalidResponse
        }
        return try JSONDecoder().decode(ForgotLookup.self, from: data)
    }

    public func resetPasswordWithAnswer(username: String, answer: String, newPassword: String, confirmPassword: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("auth/forgot/reset"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "username": username,
            "security_answer": answer,
            "new_password": newPassword,
            "new_password_confirmation": confirmPassword
        ])
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func parseServerMessage(from data: Data) -> String? {
        struct ApiErrorResponse: Decodable {
            let message: String?
            let error: String?
            let detail: String?
            let errors: [String: [String]]?
        }
        if let decoded = try? JSONDecoder().decode(ApiErrorResponse.self, from: data) {
            if let message = decoded.message, !message.isEmpty { return message }
            if let error = decoded.error, !error.isEmpty { return error }
            if let detail = decoded.detail, !detail.isEmpty { return detail }
            if let errors = decoded.errors {
                let joined = errors
                    .flatMap { $0.value }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                if !joined.isEmpty { return joined }
            }
        }
        if let decoded = try? JSONDecoder().decode(LoginResponse.self, from: data),
           let message = decoded.message, !message.isEmpty {
            return message
        }
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }
        return nil
    }
}
