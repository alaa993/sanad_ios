import Foundation

public struct SessionTask: Decodable, Identifiable {
    public let id: Int
    public let title: String?
    public let description: String?
    public let type: String?
    public let status: String?
    public let patient_answer: String?
    public let completed_at: String?
}

private struct TasksResponse: Decodable {
    let data: [SessionTask]
}

private struct TaskResponse: Decodable {
    let ok: Bool?
    let task: SessionTask?
}

private struct SimpleResponse: Decodable {
    let ok: Bool?
}

public final class SessionActionsService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func listTasks(sessionId: Int, token: String) async throws -> [SessionTask] {
        var req = URLRequest(url: base.appendingPathComponent("v1/sessions/\(sessionId)/tasks"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(TasksResponse.self, from: data).data
    }

    public func addTask(sessionId: Int, title: String, description: String?, type: String, dueAt: String? = nil, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/sessions/\(sessionId)/tasks"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = ["title": title, "type": type, "create_follow_up": true]
        if let description = description, !description.isEmpty {
            payload["description"] = description
        }
        if let dueAt, !dueAt.isEmpty {
            payload["due_at"] = dueAt
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func completeTask(taskId: Int, answer: String?, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/sessions/tasks/\(taskId)/complete"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let payload: [String: Any] = ["answer": answer ?? ""]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        _ = try? JSONDecoder().decode(TaskResponse.self, from: data)
    }

    public func rateSpecialist(sessionId: Int, score: Int, comment: String?, token: String) async throws {
        try await rate(path: "v1/sessions/\(sessionId)/rate-specialist", score: score, comment: comment, token: token)
    }

    public func ratePatient(sessionId: Int, score: Int, comment: String?, token: String) async throws {
        try await rate(path: "v1/sessions/\(sessionId)/rate-patient", score: score, comment: comment, token: token)
    }

    public func submitSurvey(sessionId: Int, score: Int, comment: String?, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/sessions/\(sessionId)/survey"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = ["patient_feedback": score]
        if let comment, !comment.isEmpty {
            payload["comment"] = comment
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func rate(path: String, score: Int, comment: String?, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = ["score": score]
        if let comment = comment, !comment.isEmpty {
            payload["comment"] = comment
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        _ = try? JSONDecoder().decode(SimpleResponse.self, from: data)
    }
}
