import Foundation

public struct DashboardStats: Decodable {
    public let upcoming_sessions: Int?
    public let unread_messages: Int?
    public let points: Int?
}

public struct DashboardShortcut: Decodable, Identifiable {
    public let id: String
    public let title: String?
    public let route: String?
}

public struct DashboardSessionSummary: Decodable, Identifiable {
    public let id: Int
    public let specialist_name: String?
    public let specialist_avatar: String?
    public let organization_name: String?
    public let type: String?
    public let status: String?
    public let scheduled_at: String?
    public let join_url: String?
    public let can_join: Bool?
}

public struct DashboardIntakeSpecialist: Decodable {
    public let id: Int?
    public let name: String?
}

public struct DashboardIntake: Decodable {
    public let completed: Bool?
    public let full_name: String?
    public let severity_level: String?
    public let impact_level: String?
    public let preferred_session_mode: String?
    public let risk_flags: [String]?
    public let primary_issue: String?
    public let benefit_score: Int?
    public let triage_category: String?
    public let triage_reason: String?
    public let recommended_specialist: DashboardIntakeSpecialist?
    public let referral_physician_recommended: Bool?
    public let external_physician_recommended: Bool?
    public let recovery_unlocked: Bool?
    public let onboarding_step: String?
    public let pre_session_completed: Bool?
    public let updated_at: String?
}

public struct DashboardOnboarding: Decodable {
    public let step: String?
    public let needs_intake: Bool?
    public let needs_pre_session: Bool?
    public let needs_vent: Bool?
    public let journal_unlocked: Bool?
}

public struct DashboardResponse: Decodable {
    public let role: String?
    public let stats: DashboardStats?
    public let shortcuts: [DashboardShortcut]?
    public let intake: DashboardIntake?
    public let next_session: DashboardSessionSummary?
    public let onboarding: DashboardOnboarding?
}

public final class DashboardService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func load(token: String) async throws -> DashboardResponse {
        let cacheKey = "dashboard:\(token.prefix(16))"
        if let cached = MemoryTTLCache.shared.get(cacheKey),
           let decoded = try? JSONDecoder().decode(DashboardResponse.self, from: cached) {
            Task { [weak self] in
                guard let self else { return }
                _ = try? await self.fetchAndCache(token: token, cacheKey: cacheKey)
            }
            return decoded
        }
        return try await fetchAndCache(token: token, cacheKey: cacheKey)
    }

    private func fetchAndCache(token: String, cacheKey: String) async throws -> DashboardResponse {
        var req = URLRequest(url: base.appendingPathComponent("v1/dashboard"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(DashboardResponse.self, from: data)
        MemoryTTLCache.shared.set(cacheKey, data: data, ttl: 25)
        return decoded
    }
}
