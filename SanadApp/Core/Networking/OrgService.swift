import Foundation

public struct OrgSpecialist: Decodable, Identifiable {
    public let id: Int
    public let name: String?
    public let role: String?
    public let email: String?
    public let sessions_count: Int?
    public let commitment_rate: Double?
    public let avg_rating: Double?
    public let next_session_at: String?
}

public struct OrgAppointment: Decodable, Identifiable {
    public let id: Int
    public let status: String?
    public let starts_at: String?
    public let ends_at: String?
    public let specialist_id: Int?
    public let patient_id: Int?
}

public struct OrgBeneficiary: Decodable, Identifiable {
    public let id: Int
    public let name: String?
    public let email: String?
    public let status: String?
    public let risk_level: String?
    public let primary_issue: String?
    public let specialist_name: String?
    public let last_session_at: String?
}

public struct OrgReportSummary: Decodable {
    public struct Period: Decodable { public let from: String?; public let to: String? }
    public struct Metrics: Decodable {
        public let beneficiaries_total: Int?
        public let beneficiaries_active: Int?
        public let high_risk_cases: Int?
        public let sessions_completed: Int?
        public let sessions_cancelled: Int?
        public let sessions_upcoming_week: Int?
        public let engagement_rate: Double?
    }
    public struct TopBeneficiary: Decodable, Identifiable {
        public let id: Int
        public let name: String?
        public let risk_level: String?
        public let primary_issue: String?
        public let last_session_at: String?
    }
    public let period: Period?
    public let metrics: Metrics?
    public let top_beneficiaries: [TopBeneficiary]?
}

public struct OrgBillingOverview: Decodable {
    public struct Plan: Decodable { public let name: String?; public let status: String?; public let renews_at: String? }
    public struct SeatUsage: Decodable { public let limit: Int?; public let used: Int? }
    public struct SessionUsage: Decodable { public let limit: Int?; public let used: Int? }
    public struct Wallet: Decodable { public let balance: Int?; public let points: Int?; public let currency: String? }
    public struct Invoice: Decodable, Identifiable {
        public let id: Int
        public let total: Int?
        public let currency: String?
        public let status: String?
        public let pdf_url: String?
        public let created_at: String?
    }
    public let plan: Plan?
    public let seats: SeatUsage?
    public let sessions: SessionUsage?
    public let wallet: Wallet?
    public let invoices: [Invoice]?
}

public struct OrgSupportRoom: Decodable {
    public let community_id: Int
    public let slug: String?
    public let name: String?
    public let visibility: String?
}

private struct OrgSpecialistsResponse: Decodable { let data: [OrgSpecialist] }
private struct OrgSessionsResponse: Decodable { let data: [OrgAppointment] }
private struct OrgBeneficiariesResponse: Decodable { let data: [OrgBeneficiary] }

public final class OrgService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func specialists(token: String) async throws -> [OrgSpecialist] {
        return try await fetch(path: "v1/org/specialists", token: token, type: OrgSpecialistsResponse.self).data
    }

    public func supportRoom(token: String) async throws -> OrgSupportRoom {
        return try await fetch(path: "v1/org/support-room", token: token, type: OrgSupportRoom.self)
    }

    public func sessions(token: String) async throws -> [OrgAppointment] {
        return try await fetch(path: "v1/org/sessions", token: token, type: OrgSessionsResponse.self).data
    }

    public func beneficiaries(token: String) async throws -> [OrgBeneficiary] {
        return try await fetch(path: "v1/org/beneficiaries", token: token, type: OrgBeneficiariesResponse.self).data
    }

    public func beneficiaryDetail(id: Int, token: String) async throws -> OrgBeneficiaryDetail {
        return try await fetch(path: "v1/org/beneficiaries/\(id)", token: token, type: OrgBeneficiaryDetail.self)
    }

    public func reportsSummary(token: String) async throws -> OrgReportSummary {
        return try await fetch(path: "v1/org/reports/summary", token: token, type: OrgReportSummary.self)
    }

    public func billingOverview(token: String) async throws -> OrgBillingOverview {
        return try await fetch(path: "v1/org/billing/overview", token: token, type: OrgBillingOverview.self)
    }

    public func specialistDetail(id: Int, token: String) async throws -> OrgSpecialistDetail {
        return try await fetch(path: "v1/org/specialists/\(id)", token: token, type: OrgSpecialistDetail.self)
    }

    public func createBeneficiary(token: String, name: String, email: String?, primaryIssue: String?) async throws {
        var body: [String: String] = ["name": name]
        if let email, !email.isEmpty { body["email"] = email }
        if let primaryIssue, !primaryIssue.isEmpty { body["primary_issue"] = primaryIssue }
        try await postJSON(path: "v1/org/beneficiaries", token: token, body: body)
    }

    public func assignSpecialist(beneficiaryId: Int, specialistId: Int, token: String) async throws {
        try await postJSON(path: "v1/org/beneficiaries/\(beneficiaryId)/assign-specialist", token: token, body: ["specialist_id": specialistId])
    }

    private func postJSON(path: String, token: String, body: [String: Any]) async throws {
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

    private func fetch<T: Decodable>(path: String, token: String, type: T.Type) async throws -> T {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
