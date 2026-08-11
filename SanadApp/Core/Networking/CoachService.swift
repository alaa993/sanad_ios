import Foundation

public struct CoachProgramSummary: Decodable, Identifiable {
    public let id: Int
    public let category: String?
    public let title: String?
    public let active: Bool?
    public let items_count: Int?
    public let checkins_count: Int?
}

public struct CoachPlanItem: Decodable, Identifiable {
    public let id: Int
    public let kind: String?
    public let title: String?
    public let schedule: String?
    public let is_done: Bool?
}

public struct CoachCheckin: Decodable, Identifiable {
    public let id: Int
    public let weight_kg: Double?
    public let mood: String?
    public let note: String?
    public let logged_at: String?
}

public struct CoachProgramDetail: Decodable, Identifiable {
    public let id: Int
    public let category: String?
    public let title: String?
    public let active: Bool?
    public let items_count: Int?
    public let checkins_count: Int?
    public let items: [CoachPlanItem]?
    public let checkins: [CoachCheckin]?
}

private struct CoachListResponse: Decodable { let data: [CoachProgramSummary]? }

public final class CoachService {
    let base: URL
    public init(baseURL: URL? = nil) { self.base = baseURL ?? AppConfig.BASE_URL }

    public func list(token: String) async throws -> [CoachProgramSummary] {
        var req = URLRequest(url: base.appendingPathComponent("v1/coach/programs"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CoachListResponse.self, from: data).data ?? []
    }

    public func create(category: String, title: String, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/coach/programs"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["category": category, "title": title])
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func show(id: Int, token: String) async throws -> CoachProgramDetail {
        var req = URLRequest(url: base.appendingPathComponent("v1/coach/programs/\(id)"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CoachProgramDetail.self, from: data)
    }

    public func checkin(programId: Int, mood: String, note: String?, weightKg: Double? = nil, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/coach/programs/\(programId)/checkins"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var body: [String: Any] = ["mood": mood]
        if let note { body["note"] = note }
        if let weightKg { body["weight_kg"] = weightKg }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func toggleItem(itemId: Int, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/coach/items/\(itemId)/complete"))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
