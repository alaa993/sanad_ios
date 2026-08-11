import Foundation

public struct OrgDashboard: Decodable {
    public struct Counters: Decodable {
        public let beneficiaries: Int?
        public let sessions_total: Int?
        public let upcoming_48h: Int?
        public let specialists_active: Int?
        public let high_risk_cases: Int?
        public let upcoming: Int?
        public let pending: Int?
    }

    public struct QuickAction: Decodable, Identifiable {
        public let id: String
        public let label: String?
    }

    public struct Alert: Decodable, Identifiable {
        public let id: String
        public let title: String?
        public let level: String?
        public let message: String?
    }

    public let org_id: Int?
    public let counters: Counters?
    public let quick_actions: [QuickAction]?
    public let alerts: [Alert]?
}

public final class OrgDashboardService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func load(token: String) async throws -> OrgDashboard {
        var req = URLRequest(url: base.appendingPathComponent("v1/org/dashboard"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(OrgDashboard.self, from: data)
    }
}
