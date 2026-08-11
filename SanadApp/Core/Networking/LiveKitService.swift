import Foundation

/// Fetches LiveKit JWT + URL from Laravel for a session room (POST v1/sessions/{id}/livekit-token).
public struct LiveKitTokenResponse: Decodable {
    public let token: String?
    public let url: String?
    public let room: String?
}

public final class LiveKitService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func token(sessionId: Int, token: String) async throws -> LiveKitTokenResponse {
        var req = URLRequest(url: base.appendingPathComponent("v1/sessions/\(sessionId)/livekit-token"))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(LiveKitTokenResponse.self, from: data)
    }
}
