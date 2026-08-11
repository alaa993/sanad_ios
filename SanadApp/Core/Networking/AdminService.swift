import Foundation

public struct AdminUser: Decodable, Identifiable {
    public let id: Int
    public let name: String?
    public let email: String?
    public let role: String?
    public let status: String?
    public let created_at: String?
    public let phone: String?
    public let banned: Bool?
}

public struct AdminSpecialist: Decodable, Identifiable {
    public let id: Int
    public let name: String?
    public let specialty: String?
    public let status: String?
    public let years_exp: Int?
    public let accepting_new: AcceptingNewValue?

    public struct AcceptingNewValue: Decodable {
        public let boolValue: Bool?
        public let intValue: Int?

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let bool = try? container.decode(Bool.self) {
                self.boolValue = bool
                self.intValue = nil
                return
            }
            if let int = try? container.decode(Int.self) {
                self.boolValue = int != 0
                self.intValue = int
                return
            }
            self.boolValue = nil
            self.intValue = nil
        }
    }
}

public struct AdminOrganization: Decodable, Identifiable {
    public let id: Int
    public let name: String?
    public let status: String?
}

public struct AdminAppointment: Decodable, Identifiable {
    public let id: Int
    public let status: String?
    public let starts_at: String?
    public let ends_at: String?
    public let type: String?
    public let patient_name: String?
    public let specialist_name: String?
    public let organization_name: String?
}

public struct AdminPost: Decodable, Identifiable {
    public let id: Int
    public let title: String?
    public let status: String?
    public let type: String?
    public let created_at: String?
    public let author: String?
    public let featured: Bool?
    public let comments: Int?
    public let likes: Int?
}

public struct AdminVentReport: Decodable, Identifiable {
    public let id: Int
    public let reason: String?
    public let status: String?
    public let created_at: String?
    public let post: VentPost?
    public let reporter: Reporter?

    public struct VentPost: Decodable {
        public let id: Int
        public let alias: String?
        public let body: String?
        public let hidden_at: String?
    }

    public struct Reporter: Decodable {
        public let id: Int
        public let name: String?
    }
}

public struct AdminDailyTip: Decodable, Identifiable {
    public let id: Int
    public let tip_date: String?
    public let title: [String: String]?
    public let body: [String: String]?
    public let active: Bool?
}

private struct AdminUsersResponse: Decodable { let data: [AdminUser] }
private struct AdminSpecialistsResponse: Decodable { let data: [AdminSpecialist] }
private struct AdminOrganizationsResponse: Decodable { let data: [AdminOrganization] }
private struct AdminAppointmentsResponse: Decodable { let data: [AdminAppointment] }
private struct AdminPostsResponse: Decodable { let data: [AdminPost] }
private struct AdminToggleResponse: Decodable { let ok: Bool?; let status: String? }

public final class AdminService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func users(token: String) async throws -> [AdminUser] {
        return try await fetchList(path: "v1/admin/users", token: token, type: AdminUsersResponse.self).data
    }

    public func specialists(token: String) async throws -> [AdminSpecialist] {
        return try await fetchList(path: "v1/admin/specialists", token: token, type: AdminSpecialistsResponse.self).data
    }

    public func createSpecialist(
        name: String,
        email: String,
        password: String,
        phone: String?,
        specialty: String?,
        token: String
    ) async throws {
        var payload: [String: Any] = [
            "name": name,
            "email": email,
            "password": password
        ]
        if let phone, !phone.isEmpty { payload["phone"] = phone }
        if let specialty, !specialty.isEmpty { payload["specialty"] = specialty }
        _ = try await post(path: "v1/admin/specialists", token: token, payload: payload)
    }

    public func organizations(token: String) async throws -> [AdminOrganization] {
        return try await fetchList(path: "v1/admin/organizations", token: token, type: AdminOrganizationsResponse.self).data
    }

    public func organizationDetail(id: Int, token: String) async throws -> AdminOrganizationDetail {
        return try await fetch(path: "v1/admin/organizations/\(id)", token: token, type: AdminOrganizationDetail.self)
    }

    public func appointments(token: String) async throws -> [AdminAppointment] {
        return try await fetchList(path: "v1/admin/appointments", token: token, type: AdminAppointmentsResponse.self).data
    }

    public func posts(token: String) async throws -> [AdminPost] {
        return try await fetchList(path: "v1/admin/library/posts", token: token, type: AdminPostsResponse.self).data
    }

    public func specialistDocuments(id: Int, token: String) async throws -> AdminSpecialistDocuments {
        return try await fetch(path: "v1/admin/specialists/\(id)/documents", token: token, type: AdminSpecialistDocuments.self)
    }

    public func togglePost(id: Int, token: String) async throws {
        _ = try await post(path: "v1/admin/library/posts/\(id)/toggle", token: token, payload: nil)
    }

    public func approveSpecialist(id: Int, token: String) async throws {
        _ = try await post(path: "v1/admin/specialists/\(id)/approve", token: token, payload: nil)
    }

    public func rejectSpecialist(id: Int, reason: String?, token: String) async throws {
        var payload: [String: Any] = [:]
        if let reason, !reason.isEmpty { payload["reason"] = reason }
        _ = try await post(path: "v1/admin/specialists/\(id)/reject", token: token, payload: payload.isEmpty ? nil : payload)
    }

    public func reviewSpecialist(
        id: Int,
        status: String,
        notes: String?,
        verifiedDocuments: [Int],
        token: String
    ) async throws {
        var payload: [String: Any] = ["status": status, "verified_documents": verifiedDocuments]
        if let notes, !notes.isEmpty { payload["notes"] = notes }
        _ = try await post(path: "v1/admin/specialists/\(id)/review", token: token, payload: payload)
    }

    public func approveOrganization(id: Int, token: String) async throws {
        _ = try await post(path: "v1/admin/organizations/\(id)/approve", token: token, payload: nil)
    }

    public func rejectOrganization(id: Int, reason: String?, token: String) async throws {
        var payload: [String: Any] = [:]
        if let reason, !reason.isEmpty { payload["reason"] = reason }
        _ = try await post(path: "v1/admin/organizations/\(id)/reject", token: token, payload: payload.isEmpty ? nil : payload)
    }

    public func ventReports(token: String) async throws -> [AdminVentReport] {
        struct Response: Decodable { let data: [AdminVentReport] }
        return try await fetchList(path: "v1/admin/vent/reports", token: token, type: Response.self).data
    }

    public func hideVentPost(id: Int, token: String) async throws {
        _ = try await post(path: "v1/admin/vent/posts/\(id)/hide", token: token, payload: nil)
    }

    public func dailyTips(token: String) async throws -> [AdminDailyTip] {
        struct Response: Decodable { let data: [AdminDailyTip] }
        return try await fetchList(path: "v1/admin/daily-tips", token: token, type: Response.self).data
    }

    public func createDailyTip(date: String, titleAr: String, bodyAr: String?, token: String) async throws {
        var payload: [String: Any] = [
            "tip_date": date,
            "title": ["ar": titleAr],
            "active": true
        ]
        if let bodyAr, !bodyAr.isEmpty { payload["body"] = ["ar": bodyAr] }
        _ = try await post(path: "v1/admin/daily-tips", token: token, payload: payload)
    }

    public func updateDailyTip(id: Int, date: String, titleAr: String, bodyAr: String?, token: String) async throws {
        var payload: [String: Any] = [
            "tip_date": date,
            "title": ["ar": titleAr],
            "active": true
        ]
        if let bodyAr, !bodyAr.isEmpty { payload["body"] = ["ar": bodyAr] }
        _ = try await put(path: "v1/admin/daily-tips/\(id)", token: token, payload: payload)
    }

    public func deleteDailyTip(id: Int, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/admin/daily-tips/\(id)"))
        req.httpMethod = "DELETE"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func fetchList<T: Decodable>(path: String, token: String, type: T.Type) async throws -> T {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
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

    private func post(path: String, token: String, payload: [String: Any]?) async throws -> AdminToggleResponse {
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
        return (try? JSONDecoder().decode(AdminToggleResponse.self, from: data)) ?? AdminToggleResponse(ok: true, status: nil)
    }

    private func put(path: String, token: String, payload: [String: Any]?) async throws {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "PUT"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        if let payload = payload {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        }
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
