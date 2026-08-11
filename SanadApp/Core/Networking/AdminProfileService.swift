import Foundation

public struct AdminProfileData: Decodable {
    public struct Stats: Decodable {
        public let pending_specialists: Int?
        public let pending_organizations: Int?
        public let total_users: Int?
        public let total_sessions: Int?
    }

    public let id: Int?
    public let name: String?
    public let email: String?
    public let avatar: String?
    public let locale: String?
    public let phone: String?
    public let stats: Stats?
    public let privacy_policy: String?
    public let contact_info: String?
    public let platform_fee_percent: Int?
}

public struct AdminSettingsData: Decodable {
    public let privacy_policy: String?
    public let contact_info: String?
    public let platform_fee_percent: Int?
}

public final class AdminProfileService {
    let base: URL

    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func loadProfile(token: String) async throws -> AdminProfileData {
        var req = URLRequest(url: base.appendingPathComponent("v1/admin/profile"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(AdminProfileData.self, from: data)
    }

    public func loadSettings(token: String) async throws -> AdminSettingsData {
        var req = URLRequest(url: base.appendingPathComponent("v1/admin/settings"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(AdminSettingsData.self, from: data)
    }

    public func updateProfile(token: String, body: [String: Any]) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/admin/profile"))
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func saveSettings(token: String, privacy: String, contact: String, platformFee: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/admin/settings"))
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var body: [String: String] = [
            "privacy_policy": privacy,
            "contact_info": contact
        ]
        if !platformFee.isEmpty { body["platform_fee_percent"] = platformFee }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func uploadAvatar(token: String, data: Data, filename: String = "avatar.jpg", mime: String = "image/jpeg") async throws -> String {
        let boundary = UUID().uuidString
        var req = URLRequest(url: base.appendingPathComponent("v1/admin/profile/avatar"))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"avatar\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        let (responseData, resp) = try await URLSession.shared.upload(for: req, from: body)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
        return json?["url"] as? String ?? ""
    }

    public func changePassword(token: String, current: String, password: String, confirm: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/admin/profile/password"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let body: [String: String] = [
            "current_password": current,
            "new_password": password,
            "new_password_confirmation": confirm
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
