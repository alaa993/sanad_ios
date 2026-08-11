import Foundation

public struct SpecialistDashboard: Decodable {
    public struct Counters: Decodable {
        public let upcoming: Int?
        public let today: Int?
        public let pending: Int?
    }
    public let counters: Counters?
}

public struct SpecialistSessionActor: Decodable, Identifiable {
    public let id: Int?
    public let name: String?
    public let avatar: String?
}

public struct SpecialistPatientMini: Decodable, Identifiable {
    public let id: Int
    public let name: String?
    public let avatar: String?
}

public struct SpecialistAppointment: Decodable, Identifiable {
    public let id: Int
    public let patient_id: Int?
    public let status: String?
    public let type: String?
    public let scheduled_at: String?
    public let ends_at: String?
    public let join_url: String?
    public let notes: String?
    public let patient_name: String?
    public let patient: SpecialistSessionActor?
    public let organization: SpecialistSessionActor?
}

public struct SpecialistPatientSession: Decodable, Identifiable {
    public let id: Int
    public let status: String?
    public let starts_at: String?
    public let closed_at: String?
    public let specialist_notes: String?
    public let rating: Int?
    public let type: String?
}

public struct SpecialistPatientIntake: Decodable {
    public let full_name: String?
    public let age: Int?
    public let occupation: String?
    public let issue_duration: String?
    public let severity_level: String?
    public let impact_level: String?
    public let primary_issue: String?
    public let symptoms: [String]?
    public let risk_flags: [String]?
    public let triage_category: String?
    public let benefit_score: Int?
    public let previous_consult: Bool?
    public let consult_notes: String?
    public let notes: String?
    public let referral_physician_recommended: Bool?
}

public struct SpecialistPatientTask: Decodable, Identifiable {
    public let id: Int
    public let title: String
    public let description: String?
    public let status: String?
    public let due_at: String?
    public let completion_note: String?
}

private struct SpecialistPatientSessionsResponse: Decodable {
    let data: [SpecialistPatientSession]
}

private struct SpecialistAppointmentsResponse: Decodable {
    let data: [SpecialistAppointment]
}

private struct SpecialistPatientsResponse: Decodable {
    let data: [SpecialistPatientMini]
}

private struct SpecialistActionResponse: Decodable {
    let ok: Bool?
}

public final class SpecialistService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func dashboard(token: String) async throws -> SpecialistDashboard {
        var req = URLRequest(url: base.appendingPathComponent("v1/specialist/dashboard"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SpecialistDashboard.self, from: data)
    }

    public func sessions(scope: String, token: String) async throws -> [SpecialistAppointment] {
        var comps = URLComponents(url: base.appendingPathComponent("v1/specialist/sessions"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "scope", value: scope)]
        guard let url = comps?.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SpecialistAppointmentsResponse.self, from: data).data
    }

    public func patients(token: String) async throws -> [SpecialistPatientMini] {
        var req = URLRequest(url: base.appendingPathComponent("v1/specialist/patients"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SpecialistPatientsResponse.self, from: data).data
    }

    public func patientSessions(patientId: Int, token: String) async throws -> [SpecialistPatientSession] {
        var req = URLRequest(url: base.appendingPathComponent("v1/specialist/patients/\(patientId)/sessions"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SpecialistPatientSessionsResponse.self, from: data).data
    }

    public func patientIntake(patientId: Int, token: String) async throws -> SpecialistPatientIntake {
        var req = URLRequest(url: base.appendingPathComponent("v1/specialist/patients/\(patientId)/intake"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SpecialistPatientIntake.self, from: data)
    }

    public func patientTasks(patientId: Int, token: String) async throws -> [SpecialistPatientTask] {
        var req = URLRequest(url: base.appendingPathComponent("v1/specialist/patients/\(patientId)/tasks"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([SpecialistPatientTask].self, from: data)
    }

    public func updateIntake(
        patientId: Int,
        triageTags: [String]?,
        triageReason: String?,
        token: String
    ) async throws -> SpecialistPatientIntake {
        var req = URLRequest(url: base.appendingPathComponent("v1/specialist/patients/\(patientId)/intake"))
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = [:]
        if let triageTags { payload["triageTags"] = triageTags }
        if let triageReason { payload["triage_reason"] = triageReason }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SpecialistPatientIntake.self, from: data)
    }

    public func applyTaskTemplates(
        patientId: Int,
        templateIds: [String],
        appointmentId: Int?,
        token: String
    ) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/specialist/patients/\(patientId)/tasks/templates"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = ["template_ids": templateIds]
        if let appointmentId { payload["appointment_id"] = appointmentId }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func acknowledgePhysicianReferral(patientId: Int, notes: String?, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/specialist/patients/\(patientId)/acknowledge-physician-referral"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        if let notes, !notes.isEmpty {
            req.httpBody = try JSONSerialization.data(withJSONObject: ["notes": notes])
        }
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func accept(id: Int, token: String) async throws {
        try await postSimple(path: "v1/specialist/sessions/\(id)/accept", token: token, payload: nil)
    }

    public func reject(id: Int, token: String) async throws {
        try await postSimple(path: "v1/specialist/sessions/\(id)/reject", token: token, payload: nil)
    }

    public func reschedule(id: Int, startsAt: Date, token: String) async throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let payload: [String: Any] = [
            "starts_at": formatter.string(from: startsAt),
            "timezone": TimeZone.current.identifier
        ]
        try await postSimple(path: "v1/specialist/sessions/\(id)/reschedule", token: token, payload: payload)
    }

    public func extend(id: Int, minutes: Int, token: String) async throws {
        let payload: [String: Any] = ["minutes": minutes]
        try await postSimple(path: "v1/specialist/sessions/\(id)/extend", token: token, payload: payload)
    }

    public func complete(id: Int, diagnosisNotes: String? = nil, patientFeedback: Int? = nil, token: String) async throws {
        var payload: [String: Any] = [:]
        if let diagnosisNotes, !diagnosisNotes.isEmpty {
            payload["diagnosis_notes"] = diagnosisNotes
        }
        if let patientFeedback {
            payload["patient_feedback"] = patientFeedback
        }
        try await postSimple(path: "v1/specialist/sessions/\(id)/complete", token: token, payload: payload.isEmpty ? nil : payload)
    }

    private func postSimple(path: String, token: String, payload: [String: Any]?) async throws {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        if let payload = payload {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        _ = try? JSONDecoder().decode(SpecialistActionResponse.self, from: data)
    }
}
