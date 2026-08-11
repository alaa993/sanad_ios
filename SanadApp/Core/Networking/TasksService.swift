import Foundation

public struct TaskItem: Identifiable, Decodable {
    public let id: Int
    public let title: String
    public let description: String?
    public let status: String?
    public let due_at: String?
    public let completion_note: String?
}

public struct TaskListResponse: Decodable {
    public let upcoming: [TaskItem]
    public let completed: [TaskItem]
}

public final class TasksService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func list(token: String) async throws -> TaskListResponse {
        var req = URLRequest(url: base.appendingPathComponent("v1/patient/tasks"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(TaskListResponse.self, from: data)
    }

    public func complete(id: Int, note: String?, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/patient/tasks/\(id)"))
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = ["status": "completed"]
        if let n = note { payload["notes"] = n }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func create(title: String, description: String?, dueAt: Date?, appointmentId: Int?, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/patient/tasks"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = ["title": title]
        if let d = description { payload["description"] = d }
        if let due = dueAt {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            payload["due_at"] = iso.string(from: due)
        }
        if let appId = appointmentId { payload["appointment_id"] = appId }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
