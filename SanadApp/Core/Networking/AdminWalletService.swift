import Foundation

public final class AdminWalletService {
    let base: URL

    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func createCoupon(token: String, code: String, points: Int, expiry: String?) async throws {
        var body: [String: Any] = ["code": code, "points": points]
        if let expiry, !expiry.isEmpty { body["expires_at"] = expiry }
        try await post(path: "v1/admin/wallet/coupon", token: token, body: body)
    }

    public func creditUser(token: String, userId: Int, points: Int) async throws {
        try await post(path: "v1/admin/wallet/credit", token: token, body: ["user_id": userId, "points": points])
    }

    private func post(path: String, token: String, body: [String: Any]) async throws {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
