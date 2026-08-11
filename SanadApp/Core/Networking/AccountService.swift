import Foundation

public final class AccountService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func resubmitSpecialist(token: String) async throws {
        try await hit(path: "v1/specialist/resubmit", token: token)
    }

    public func resubmitOrg(token: String) async throws {
        try await hit(path: "v1/org/resubmit", token: token)
    }

    private func hit(path: String, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
