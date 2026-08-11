import Foundation

public struct CalendarActor: Decodable, Identifiable {
    public let id: Int
    public let name: String?
}

public struct CalendarAppointment: Decodable, Identifiable {
    public let id: Int
    public let type: String?
    public let status: String?
    public let starts_at: String?
    public let ends_at: String?
    public let notes: String?
    public let specialist: CalendarActor?
    public let patient: CalendarActor?
}

public struct CalendarAppointmentList: Decodable {
    public let data: [CalendarAppointment]
}

public struct CalendarSlot: Identifiable, Decodable {
    public let id: Int
    public let weekday: Int
    public let start_time: String
    public let end_time: String
    public let repeat_rule: String?
}

public struct CalendarBlock: Identifiable, Decodable {
    public let id: Int
    public let start_at: String
    public let end_at: String
    public let reason: String?
}

public struct CalendarAvailabilityResponse: Decodable {
    public let slots: [CalendarSlot]
    public let blocks: [CalendarBlock]
}

public enum CalendarServiceError: LocalizedError {
    case invalidRange

    public var errorDescription: String? {
        switch self {
        case .invalidRange: return "الموعد غير صالح"
        }
    }
}

public final class CalendarService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func appointments(scope: String = "patient", from: String? = nil, to: String? = nil, token: String) async throws -> [CalendarAppointment] {
        var comps = URLComponents(url: base.appendingPathComponent("v1/cal/appointments"), resolvingAgainstBaseURL: false)
        var query: [URLQueryItem] = [URLQueryItem(name: "scope", value: scope)]
        if let from = from, !from.isEmpty {
            query.append(URLQueryItem(name: "from", value: from))
        }
        if let to = to, !to.isEmpty {
            query.append(URLQueryItem(name: "to", value: to))
        }
        comps?.queryItems = query
        guard let url = comps?.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CalendarAppointmentList.self, from: data).data
    }

    public func cancel(id: Int, reason: String?, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/cal/appointments/\(id)/cancel"))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        if let reason = reason, !reason.isEmpty {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: ["reason": reason])
        }
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func availability(token: String) async throws -> CalendarAvailabilityResponse {
        var req = URLRequest(url: base.appendingPathComponent("v1/cal/availability"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CalendarAvailabilityResponse.self, from: data)
    }

    public func createSlot(weekday: Int, start: String, end: String, repeatRule: String?, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/cal/availability"))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = [
            "weekday": weekday,
            "start_time": start,
            "end_time": end
        ]
        if let rule = repeatRule, !rule.isEmpty {
            payload["repeat_rule"] = rule
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func deleteSlot(id: Int, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/cal/availability/\(id)"))
        req.httpMethod = "DELETE"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func block(start: String, end: String, reason: String?, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/cal/block"))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = [
            "start_at": start,
            "end_at": end
        ]
        if let reason = reason, !reason.isEmpty {
            payload["reason"] = reason
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func unblock(id: Int, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/cal/block/\(id)"))
        req.httpMethod = "DELETE"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func createAppointment(specialistId: Int, startsAt: Date, endsAt: Date, notes: String?, token: String) async throws {
        guard endsAt > startsAt else { throw CalendarServiceError.invalidRange }
        var req = URLRequest(url: base.appendingPathComponent("v1/cal/appointments"))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var payload: [String: Any] = [
            "specialist_id": specialistId,
            "starts_at": iso.string(from: startsAt),
            "ends_at": iso.string(from: endsAt)
        ]
        if let notes = notes, !notes.isEmpty {
            payload["notes"] = notes
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func acceptAppointment(id: Int, token: String) async throws {
        try await postAppointmentAction(path: "v1/cal/appointments/\(id)/accept", token: token, payload: nil)
    }

    public func rejectAppointment(id: Int, reason: String?, token: String) async throws {
        var payload: [String: Any]? = nil
        if let reason, !reason.isEmpty { payload = ["reason": reason] }
        try await postAppointmentAction(path: "v1/cal/appointments/\(id)/reject", token: token, payload: payload)
    }

    public func rescheduleAppointment(id: Int, startsAt: Date, endsAt: Date, token: String) async throws {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let payload: [String: Any] = [
            "starts_at": iso.string(from: startsAt),
            "ends_at": iso.string(from: endsAt)
        ]
        try await postAppointmentAction(path: "v1/cal/appointments/\(id)/reschedule", token: token, payload: payload)
    }

    private func postAppointmentAction(path: String, token: String, payload: [String: Any]?) async throws {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        if let payload {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        }
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
