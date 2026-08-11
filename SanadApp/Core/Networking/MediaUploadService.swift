import Foundation

public final class MediaUploadService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func uploadImage(_ data: Data, filename: String, token: String) async throws -> String {
        var req = URLRequest(url: base.appendingPathComponent("v1/community/media"))
        req.httpMethod = "POST"
        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")

        var body = Data()
        let boundaryPrefix = "--\(boundary)\r\n"
        body.append(boundaryPrefix.data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        req.httpBody = body

        let (respData, resp) = try await URLSession.shared.upload(for: req, from: body)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        // الاستجابة المتوقعة { url: "..." }
        let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any]
        if let url = json?["url"] as? String {
            return url
        }
        throw URLError(.cannotParseResponse)
    }
}
