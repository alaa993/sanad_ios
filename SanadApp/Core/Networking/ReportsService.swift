import Foundation

public struct ReportsOverviewCard: Decodable {
    public let key: String?
    public let value: Double?
}

public struct ReportsOverviewResponse: Decodable {
    public let cards: [ReportsOverviewCard]?
    public let period: ReportsPeriod?
}

public struct ReportsPeriod: Decodable {
    public let from: String?
    public let to: String?
}

public struct ReportsOverview {
    public let users: Int
    public let sessions: Int
    public let paidSessions: Int
    public let revenue: Int
    public let avgRating: Double?
    public let surveyResponseRate: Double?

    init(cards: [ReportsOverviewCard]) {
        var users = 0, sessions = 0, paid = 0, revenue = 0
        var avgRating: Double?
        var surveyRate: Double?
        for card in cards {
            guard let key = card.key else { continue }
            switch key {
            case "new_users": users = Int(card.value ?? 0)
            case "sessions_total": sessions = Int(card.value ?? 0)
            case "sessions_paid": paid = Int(card.value ?? 0)
            case "revenue": revenue = Int(card.value ?? 0)
            case "avg_rating": avgRating = card.value
            case "survey_response_rate": surveyRate = card.value
            default: break
            }
        }
        self.users = users
        self.sessions = sessions
        self.paidSessions = paid
        self.revenue = revenue
        self.avgRating = avgRating
        self.surveyResponseRate = surveyRate
    }
}

public struct ReportsSeriesPoint: Decodable, Identifiable {
    public var id: String { d ?? UUID().uuidString }
    public let d: String?
    public let v: Double?
}

private struct ReportsSeriesResponse: Decodable {
    let data: [ReportsSeriesPoint]?
}

public struct ReportsTopEntry: Decodable, Identifiable {
    public let id: Int
    public let name: String?
    public let specialty: String?
    public let sessions: Double?
    public let avg_rating: Double?
}

private struct ReportsTopResponse: Decodable {
    let data: [ReportsTopEntry]?
}

public struct ReportsRetentionRow: Decodable, Identifiable {
    public var id: String { week ?? UUID().uuidString }
    public let week: String?
    public let users: Int?
    public let retained: Int?
}

private struct ReportsRetentionResponse: Decodable {
    let data: [ReportsRetentionRow]?
}

public struct ReportsFunnelStage: Decodable, Identifiable {
    public var id: String { stage ?? UUID().uuidString }
    public let stage: String?
    public let value: Int?
}

private struct ReportsFunnelResponse: Decodable {
    let data: [ReportsFunnelStage]?
}

public struct ReportsSurveySummary: Decodable {
    public let completed_sessions: Int?
    public let survey_responses: Int?
    public let response_rate: Double?
    public let avg_score: Double?
}

public enum ReportsError: Error {
    case badResponse
}

public final class ReportsService {
    let base: URL

    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func overview(from: String? = nil, to: String? = nil, token: String) async throws -> (ReportsOverview, ReportsPeriod?) {
        let data = try await getData(path: "v1/reports/overview", from: from, to: to, token: token)
        let decoded = try JSONDecoder().decode(ReportsOverviewResponse.self, from: data)
        return (ReportsOverview(cards: decoded.cards ?? []), decoded.period)
    }

    public func surveySummary(from: String? = nil, to: String? = nil, token: String) async throws -> ReportsSurveySummary {
        let data = try await getData(path: "v1/reports/surveys/summary", from: from, to: to, token: token)
        return try JSONDecoder().decode(ReportsSurveySummary.self, from: data)
    }

    public func sessionsSeries(from: String? = nil, to: String? = nil, token: String) async throws -> [ReportsSeriesPoint] {
        let data = try await getData(path: "v1/reports/timeseries/sessions", from: from, to: to, token: token)
        return try JSONDecoder().decode(ReportsSeriesResponse.self, from: data).data ?? []
    }

    public func usersSeries(from: String? = nil, to: String? = nil, token: String) async throws -> [ReportsSeriesPoint] {
        let data = try await getData(path: "v1/reports/timeseries/users", from: from, to: to, token: token)
        return try JSONDecoder().decode(ReportsSeriesResponse.self, from: data).data ?? []
    }

    public func revenueSeries(from: String? = nil, to: String? = nil, token: String) async throws -> [ReportsSeriesPoint] {
        let data = try await getData(path: "v1/reports/timeseries/revenue", from: from, to: to, token: token)
        return try JSONDecoder().decode(ReportsSeriesResponse.self, from: data).data ?? []
    }

    public func topSpecialists(from: String? = nil, to: String? = nil, token: String) async throws -> [ReportsTopEntry] {
        let data = try await getData(path: "v1/reports/top/specialists", from: from, to: to, token: token)
        return try JSONDecoder().decode(ReportsTopResponse.self, from: data).data ?? []
    }

    public func topOrganizations(from: String? = nil, to: String? = nil, token: String) async throws -> [ReportsTopEntry] {
        let data = try await getData(path: "v1/reports/top/organizations", from: from, to: to, token: token)
        return try JSONDecoder().decode(ReportsTopResponse.self, from: data).data ?? []
    }

    public func retention(from: String? = nil, to: String? = nil, token: String) async throws -> [ReportsRetentionRow] {
        let data = try await getData(path: "v1/reports/retention", from: from, to: to, token: token)
        return try JSONDecoder().decode(ReportsRetentionResponse.self, from: data).data ?? []
    }

    public func conversion(from: String? = nil, to: String? = nil, token: String) async throws -> [ReportsFunnelStage] {
        let data = try await getData(path: "v1/reports/conversion", from: from, to: to, token: token)
        return try JSONDecoder().decode(ReportsFunnelResponse.self, from: data).data ?? []
    }

    public func exportCSVURL(type: String = "overview", from: String? = nil, to: String? = nil, token: String) -> URL? {
        var components = URLComponents(url: base.appendingPathComponent("v1/reports/export/csv"), resolvingAgainstBaseURL: false)
        var query = [URLQueryItem(name: "type", value: type)]
        if let from, !from.isEmpty { query.append(URLQueryItem(name: "from", value: from)) }
        if let to, !to.isEmpty { query.append(URLQueryItem(name: "to", value: to)) }
        components?.queryItems = query
        return components?.url
    }

    private func getData(path: String, from: String?, to: String?, token: String) async throws -> Data {
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        var query: [URLQueryItem] = []
        if let from, !from.isEmpty { query.append(URLQueryItem(name: "from", value: from)) }
        if let to, !to.isEmpty { query.append(URLQueryItem(name: "to", value: to)) }
        components?.queryItems = query.isEmpty ? nil : query
        guard let url = components?.url else { throw ReportsError.badResponse }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ReportsError.badResponse
        }
        return data
    }
}
