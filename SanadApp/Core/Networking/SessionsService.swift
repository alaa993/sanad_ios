import Foundation

public struct SessionActor: Decodable {
    public let id: Int?
    public let name: String?
    public let avatar: String?
}

public struct SessionItem: Decodable, Identifiable {
    public let id: Int
    public let type: String?
    public let status: String?
    public let scheduled_at: String?
    public let ends_at: String?
    public let notes: String?
    public let specialist_notes: String?
    public let rating: Int?
    public let survey_submitted: Bool?
    public let transferred_at: String?
    public let transfer_reason: String?
    public let join_url: String?
    public let chat_id: Int?
    public let points_cost: Int?
    public let duration_minutes: Int?
    public let extended_minutes: Int?
    public let specialist: SessionActor?
    public let organization: SessionActor?
    public let user: SessionActor?
}

public struct SessionsResponse: Decodable {
    public let upcoming: [SessionItem]
    public let history: [SessionItem]
}

/// Sessions REST: list/book/actions plus short MemoryTTLCache on list to reduce resume churn.
public final class SessionsService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func list(token: String, status: String? = nil, from: String? = nil, to: String? = nil) async throws -> SessionsResponse {
        var components = URLComponents(url: base.appendingPathComponent("v1/sessions"), resolvingAgainstBaseURL: false)
        var query: [URLQueryItem] = []
        if let status = status { query.append(URLQueryItem(name: "status", value: status)) }
        if let from = from { query.append(URLQueryItem(name: "from", value: from)) }
        if let to = to { query.append(URLQueryItem(name: "to", value: to)) }
        components?.queryItems = query.isEmpty ? nil : query

        let url = components?.url ?? base.appendingPathComponent("v1/sessions")
        let cacheKey = "sessions:\(token.prefix(16)):\(url.absoluteString)"
        if let cached = MemoryTTLCache.shared.get(cacheKey),
           let decoded = try? JSONDecoder().decode(SessionsResponse.self, from: cached) {
            Task { [weak self] in
                guard let self else { return }
                _ = try? await self.fetchSessions(url: url, token: token, cacheKey: cacheKey)
            }
            return decoded
        }
        return try await fetchSessions(url: url, token: token, cacheKey: cacheKey)
    }

    private func fetchSessions(url: URL, token: String, cacheKey: String) async throws -> SessionsResponse {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(SessionsResponse.self, from: data)
        MemoryTTLCache.shared.set(cacheKey, data: data, ttl: 20)
        return decoded
    }

    public func show(id: Int, token: String) async throws -> SessionItem {
        var req = URLRequest(url: base.appendingPathComponent("v1/sessions/\(id)"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SessionItem.self, from: data)
    }

    public func start(id: Int, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/sessions/\(id)/start"))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func extend(id: Int, minutes: Int, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/sessions/\(id)/extend"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let payload: [String: Any] = ["minutes": minutes]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func complete(id: Int, diagnosisNotes: String? = nil, patientFeedback: Int? = nil, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/sessions/\(id)/complete"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = [:]
        if let diagnosisNotes, !diagnosisNotes.isEmpty {
            payload["diagnosis_notes"] = diagnosisNotes
        }
        if let patientFeedback {
            payload["patient_feedback"] = patientFeedback
        }
        if !payload.isEmpty {
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        }
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func create(
        type: String,
        specialistId: Int?,
        organizationId: Int?,
        scheduledAt: Date,
        pointsCost: Int?,
        notes: String?,
        weeklyRecurring: Bool = false,
        recurrenceCount: Int? = nil,
        token: String
    ) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/sessions"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        var payload: [String: Any] = [
            "type": type,
            "scheduled_at": iso.string(from: scheduledAt)
        ]
        if let s = specialistId { payload["specialist_id"] = s }
        if let o = organizationId { payload["organization_id"] = o }
        if let p = pointsCost { payload["points_cost"] = p }
        if let n = notes { payload["notes"] = n }
        if weeklyRecurring {
            payload["weekly_recurring"] = true
            payload["recurrence_count"] = recurrenceCount ?? 4
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BookingError.message(code: Self.extractBookingCode(from: data), text: Self.bookingMessage(from: data))
        }
    }

    public enum BookingError: LocalizedError {
        case message(code: String?, text: String)

        public var errorDescription: String? {
            switch self {
            case .message(_, let text):
                return text
            }
        }

        public var code: String? {
            switch self {
            case .message(let code, _):
                return code
            }
        }
    }

    private static func bookingMessage(from data: Data?) -> String {
        let fallback = NSLocalizedString("book_session_failed", comment: "")
        guard let data, !data.isEmpty else { return fallback }

        struct ApiErrorResponse: Decodable {
            let message: String?
            let error: String?
            let msg: String?
            let detail: String?
            let errors: [String: [String]]?
        }

        if let decoded = try? JSONDecoder().decode(ApiErrorResponse.self, from: data) {
            if let mapped = mapKnownBookingCode(decoded.message) { return mapped }
            if let mapped = mapKnownBookingCode(decoded.error) { return mapped }
            if let mapped = mapKnownBookingCode(decoded.msg) { return mapped }
            if let detail = decoded.detail, !detail.isEmpty { return detail }
            if let errors = decoded.errors {
                let joined = errors.flatMap(\.value).filter { !$0.isEmpty }.joined(separator: "\n")
                if !joined.isEmpty { return joined }
            }
            if let message = decoded.message, !message.isEmpty, !looksLikeJSON(message) { return message }
            if let error = decoded.error, !error.isEmpty, !looksLikeJSON(error) { return error }
        }

        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty,
           !looksLikeJSON(text) {
            return text
        }

        return fallback
    }

    private static func extractBookingCode(from data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        struct ApiErrorResponse: Decodable {
            let message: String?
            let error: String?
            let msg: String?
        }
        guard let decoded = try? JSONDecoder().decode(ApiErrorResponse.self, from: data) else { return nil }
        if let message = decoded.message, mapKnownBookingCode(message) != nil { return message }
        if let error = decoded.error, mapKnownBookingCode(error) != nil { return error }
        return decoded.msg
    }

    private static func mapKnownBookingCode(_ code: String?) -> String? {
        guard let code, !code.isEmpty else { return nil }
        switch code {
        case "intake_required":
            return NSLocalizedString("book_session_error_intake_required", comment: "")
        case "pre_session_required":
            return NSLocalizedString("book_session_error_pre_session_required", comment: "")
        case "insufficient_points":
            return NSLocalizedString("book_session_error_insufficient_points", comment: "")
        case "past_datetime":
            return NSLocalizedString("book_session_error_past_datetime", comment: "")
        default:
            return nil
        }
    }

    private static func looksLikeJSON(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("{") || trimmed.hasPrefix("[")
    }

    public func cancel(id: Int, reason: String?, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/sessions/\(id)/cancel"))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        if let reason, !reason.isEmpty {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: ["reason": reason])
        }
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func confirmPayment(id: Int, method: String = "points", coupon: String? = nil, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/sessions/\(id)/confirm-payment"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = ["method": method]
        if let coupon, !coupon.isEmpty { payload["coupon"] = coupon }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
