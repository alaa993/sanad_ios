import Foundation

public struct AdminDashboard: Decodable {
    public struct Counters: Decodable {
        public let users: Int?
        public let specialists: Int?
        public let organizations: Int?
        public let appointments: Int?
        public let appointments_today: Int?
        public let posts: Int?
        public let sessions_week: Int?
        public let organizations_pending: Int?
        public let specialists_pending: Int?
    }

    public struct QuickAction: Decodable, Identifiable {
        public let id: String
        public let label: String?
    }

    public struct Alert: Decodable, Identifiable {
        public let raw_id: String?
        public let title: String?
        public let message: String?
        public let level: String?

        public var id: String { raw_id ?? UUID().uuidString }

        private enum CodingKeys: String, CodingKey {
            case raw_id = "id"
            case title, message, level
        }
    }

    public struct Metric: Decodable, Identifiable {
        public let title: String?
        public let value: String?
        public let trend: String?

        public var id: String { (title ?? "") + (value ?? "") }
    }

    public let counters: Counters?
    public let quick_actions: [QuickAction]?
    public let alerts: [Alert]?
    public let metrics: [Metric]?
}

public final class AdminDashboardService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func load(token: String) async throws -> AdminDashboard {
        var req = URLRequest(url: base.appendingPathComponent("v1/admin/dashboard"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(AdminDashboard.self, from: data)
    }
}
