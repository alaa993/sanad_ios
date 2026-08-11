import Foundation

struct BootstrapResponse: Decodable {
    let ok: Bool
    let data: DataContainer?
    struct DataContainer: Decodable {
        let brand: Brand?
        let locales: [String]?
        struct Brand: Decodable { let name: String; let primary: String }
    }
}

enum ApiError: Error { case invalidURL, badResponse, decodingFailed }

final class BootstrapClient {
    static let shared = BootstrapClient()
    private init() {}

    func ping(completion: @escaping (Result<String, Error>) -> Void) {
        let url = AppConfig.BASE_URL.appendingPathComponent("ping")
        URLSession.shared.dataTask(with: url) { data, resp, err in
            if let err = err { return completion(.failure(err)) }
            guard let http = resp as? HTTPURLResponse, let data = data, http.statusCode == 200 else {
                return completion(.failure(ApiError.badResponse))
            }
            completion(.success(String(data: data, encoding: .utf8) ?? ""))
        }.resume()
    }

    func bootstrap(completion: @escaping (Result<BootstrapResponse, Error>) -> Void) {
        let url = AppConfig.BASE_URL.appendingPathComponent("bootstrap")
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let languageHeader = AppLanguage.currentCode
        req.setValue(languageHeader, forHTTPHeaderField: "Accept-Language")

        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err { return completion(.failure(err)) }
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200, let data = data else {
                return completion(.failure(ApiError.badResponse))
            }
            do {
                let decoded = try JSONDecoder().decode(BootstrapResponse.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(ApiError.decodingFailed))
            }
        }.resume()
    }
}
