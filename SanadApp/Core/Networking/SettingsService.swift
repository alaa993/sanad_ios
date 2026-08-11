import Foundation

public struct SettingsResponse: Decodable {
    public let contact_info: String?
    public let privacy_policy: String?
    public let about_us: String?
    public let privacy_policy_url: String?
    public let delete_account_url: String?
    public let terms_url: String?
    public let contact_url: String?
    public let support_email: String?

    public func resolvedPrivacyURL() -> URL {
        if let raw = privacy_policy_url, let url = URL(string: raw), !raw.isEmpty { return url }
        return AppConfig.privacyPolicyURL
    }

    public func resolvedDeleteAccountURL() -> URL {
        if let raw = delete_account_url, let url = URL(string: raw), !raw.isEmpty { return url }
        return AppConfig.deleteAccountURL
    }
}

public final class SettingsService {
    let base: URL

    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func fetch(token: String) async throws -> SettingsResponse {
        var req = URLRequest(url: base.appendingPathComponent("v1/settings"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SettingsResponse.self, from: data)
    }
}
