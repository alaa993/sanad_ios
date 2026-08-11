import Foundation

public struct VentPostModel: Identifiable, Decodable {
    public let id: Int
    public let alias: String?
    public let body: String
    public let created_at: String?
    public let empathy_count: Int?
    public let support_count: Int?
    public let user_empathy: Bool?
    public let user_support: Bool?
}

public struct VentListResponse: Decodable {
    public let data: [VentPostModel]
}

public struct VentReactResponse: Decodable {
    public let type: String?
    public let active: Bool?
    public let count: Int?
}

public struct VentChatResponse: Decodable {
    public let reply: String?
    public let sent: String?
    public let tips: [String]?
    public let prompt: String?
    public let mood: String?
    public let stage: String?
    public let next_stage: String?
    public let next_prompt: String?
}

public final class VentService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func list(token: String) async throws -> [VentPostModel] {
        var req = URLRequest(url: base.appendingPathComponent("v1/vent"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(VentListResponse.self, from: data)
        return decoded.data
    }

    public func create(body: String, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/vent"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["body": body])
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func react(postId: Int, type: String, token: String) async throws -> VentReactResponse {
        var req = URLRequest(url: base.appendingPathComponent("v1/vent/\(postId)/react"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["type": type])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(VentReactResponse.self, from: data)
    }

    public func report(postId: Int, reason: String?, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/vent/\(postId)/report"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = [:]
        if let reason = reason { payload["reason"] = reason }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func chat(message: String, mood: String?, stage: String?, token: String) async throws -> VentChatResponse {
        var req = URLRequest(url: base.appendingPathComponent("v1/vent/chat"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = ["message": message]
        if let m = mood { payload["mood"] = m }
        if let s = stage { payload["stage"] = s }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(VentChatResponse.self, from: data)
    }
}
