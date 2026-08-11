import Foundation
import UniformTypeIdentifiers

public struct SpecialistDocument: Decodable, Identifiable {
    public let id: Int
    public let type: String?
    public let title: String?
    public let file_path: String?
    public let meta: DocumentMeta?

    public struct DocumentMeta: Decodable {
        public let original_name: String?
        public let mime: String?
    }
}

public struct SpecialistProfileData: Decodable {
    public let specialty: String?
    public let bio: [String: String]?
    public let years_exp: Int?
    public let rate_cents: Int?
    public let currency: String?
    public let languages: [String]?
    public let accepting_new: Bool?
    public let status: String?
    public let verification_notes: String?
    public let avatar: String?
    public let requires_avatar: Bool?
    public let documents: [SpecialistDocument]?
    public let user: User?

    public struct User: Decodable {
        public let name: String?
        public let email: String?
    }
}

public final class SpecialistProfileService {
    let base: URL

    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func fetchProfile(token: String) async throws -> SpecialistProfileData {
        try await fetch(path: "v1/specialist/profile", token: token, type: SpecialistProfileData.self)
    }

    public func fetchDocuments(token: String) async throws -> [SpecialistDocument] {
        struct DocumentsResponse: Decodable {
            let documents: [SpecialistDocument]?
        }
        let response = try await fetch(path: "v1/specialist/documents", token: token, type: DocumentsResponse.self)
        return response.documents ?? []
    }

    public func updateProfile(token: String, payload: [String: Any]) async throws {
        var req = URLRequest(url: base.appendingPathComponent("v1/specialist/profile"))
        req.httpMethod = "PUT"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    public func uploadAvatar(token: String, data avatarData: Data, filename: String, mime: String) async throws -> String {
        let boundary = UUID().uuidString
        var req = URLRequest(url: base.appendingPathComponent("v1/specialist/profile/avatar"))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = multipartBody(boundary: boundary, data: avatarData, fieldName: "avatar", fileName: filename, mimeType: mime, fields: [:])
        let (responseData, resp) = try await URLSession.shared.upload(for: req, from: req.httpBody ?? Data())
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
        return decoded?["url"] as? String ?? ""
    }

    public func uploadDocument(token: String, url: URL, type: String, title: String?) async throws -> SpecialistDocument {
        let boundary = UUID().uuidString
        var req = URLRequest(url: base.appendingPathComponent("v1/specialist/documents"))
        req.httpMethod = "POST"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let documentData = try Data(contentsOf: url)
        let mime = mimeType(for: url) ?? "application/octet-stream"
        var fields: [String: String] = ["type": type]
        if let title = title { fields["title"] = title }
        req.httpBody = multipartBody(boundary: boundary, data: documentData, fieldName: "file", fileName: url.lastPathComponent, mimeType: mime, fields: fields)
        let (responseData, resp) = try await URLSession.shared.upload(for: req, from: req.httpBody ?? Data())
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SpecialistDocument.self, from: responseData)
    }

    public func deleteDocument(token: String, id: Int) async throws {
        _ = try await fetch(path: "v1/specialist/documents/\(id)", token: token, httpMethod: "DELETE", type: EmptyResponse.self)
    }

    // MARK: - Helpers

    private func fetch<T: Decodable>(path: String, token: String, httpMethod: String = "GET", type: T.Type) async throws -> T {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = httpMethod
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private struct EmptyResponse: Decodable {}

    private func multipartBody(boundary: String,
                               data: Data,
                               fieldName: String,
                               fileName: String,
                               mimeType: String,
                               fields: [String: String]) -> Data {
        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    private func mimeType(for url: URL) -> String? {
        let path = url.pathExtension
        if path.isEmpty { return nil }
        if let uti = UTType(filenameExtension: path)?.preferredMIMEType {
            return uti
        }
        return nil
    }
}
