import Foundation

public struct GroupSession: Decodable, Identifiable {
    public let id: Int
    public let title: String?
    public let topic: String?
    public let type: String?
    public let start_at: String?
    public let end_at: String?
    public let status: String?
    public let participants_count: Int?
    public let max_capacity: Int?
    public let spots_left: Int?
    public let is_public: Bool?
    public let specialist_name: String?
    public let age_category: String?
    public let disorder_tag: String?
    public let join_url: String?
    public let chat_id: Int?
    public let joined: Bool?
}

private struct GroupSessionListResponse: Decodable {
    let data: [GroupSession]
}

public final class GroupSessionsService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func list(token: String, ageCategory: String? = nil, disorderTag: String? = nil) async throws -> [GroupSession] {
        var components = URLComponents(url: base.appendingPathComponent("v1/group-sessions"), resolvingAgainstBaseURL: false)
        var items: [URLQueryItem] = []
        if let ageCategory, !ageCategory.isEmpty { items.append(URLQueryItem(name: "age_category", value: ageCategory)) }
        if let disorderTag, !disorderTag.isEmpty { items.append(URLQueryItem(name: "disorder_tag", value: disorderTag)) }
        if !items.isEmpty { components?.queryItems = items }
        guard let url = components?.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(GroupSessionListResponse.self, from: data).data
    }

    public func show(id: Int, token: String) async throws -> GroupSession {
        var req = URLRequest(url: base.appendingPathComponent("v1/group-sessions/\(id)"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(GroupSession.self, from: data)
    }

    public func join(id: Int, token: String) async throws -> GroupSession {
        return try await postDetail(path: "v1/group-sessions/\(id)/join", token: token)
    }

    public func leave(id: Int, token: String) async throws -> GroupSession {
        return try await postDetail(path: "v1/group-sessions/\(id)/leave", token: token)
    }

    public func create(title: String,
                       topic: String?,
                       type: String,
                       startAt: Date,
                       endAt: Date,
                       participantIds: [Int],
                       token: String) async throws -> GroupSession {
        var req = URLRequest(url: base.appendingPathComponent("v1/group-sessions"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var payload: [String: Any] = [
            "title": title,
            "type": type,
            "start_at": formatter.string(from: startAt),
            "end_at": formatter.string(from: endAt),
            "timezone": TimeZone.current.identifier
        ]
        if let topic = topic, !topic.isEmpty {
            payload["topic"] = topic
        }
        if !participantIds.isEmpty {
            payload["participant_ids"] = participantIds
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(GroupSession.self, from: data)
    }

    public func liveKitToken(id: Int, token: String) async throws -> LiveKitTokenResponse {
        var req = URLRequest(url: base.appendingPathComponent("v1/group-sessions/\(id)/livekit-token"))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(LiveKitTokenResponse.self, from: data)
    }

    private func postDetail(path: String, token: String) async throws -> GroupSession {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(GroupSession.self, from: data)
    }
}
