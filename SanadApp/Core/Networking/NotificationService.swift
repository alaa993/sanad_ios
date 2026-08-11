import Foundation

public struct AppNotification: Identifiable, Decodable {
    public let id: Int
    public let title: String?
    public let body: String?
    public let type: String?
    public let created_at: String?
    public let read: Bool?
}

private struct NotificationListResponse: Decodable {
    let data: [AppNotification]
}

public final class NotificationService {
    let base: URL

    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func list(token: String) async throws -> [AppNotification] {
        var req = URLRequest(url: base.appendingPathComponent("v1/notifications"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(NotificationListResponse.self, from: data).data
    }
}
