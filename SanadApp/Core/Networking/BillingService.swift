import Foundation

public struct BillingPlan: Identifiable, Decodable {
    public let id: Int
    public let slug: String?
    public let type: String?
    public let cycle: String?
    public let name: String?
    public let description: String?
    public let price: Int?
    public let currency: String?
    public let interval: String?
    public let status: String?
    public let renews_at: String?
    public let features: [String]?
}

public struct BillingInvoice: Identifiable, Decodable {
    public let id: Int
    public let total: Int?
    public let currency: String?
    public let status: String?
    public let created_at: String?
    public let pdf_url: String?
}

public struct BillingTransaction: Identifiable, Decodable {
    public let id: Int
    public let type: String?
    public let amount: Int?
    public let points: Int?
    public let currency: String?
    public let status: String?
    public let created_at: String?
}

/// Plans, invoices, and transactions used alongside WalletService on the wallet/billing screens.
public final class BillingService {
    let base: URL

    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    private func request(path: String, token: String, method: String = "GET", payload: [String: Any]? = nil) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        if let payload = payload {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }

    private struct ListResponse<T: Decodable>: Decodable { let data: [T] }

    public func plans(token: String) async throws -> [BillingPlan] {
        let (data, _) = try await request(path: "v1/billing/plans", token: token)
        return try JSONDecoder().decode(ListResponse<BillingPlan>.self, from: data).data
    }

    public func subscribe(planId: Int, token: String) async throws {
        _ = try await request(path: "v1/billing/subscribe", token: token, method: "POST", payload: ["plan_id": planId])
    }

    public func cancel(token: String) async throws {
        _ = try await request(path: "v1/billing/cancel", token: token, method: "POST")
    }

    public func invoices(token: String) async throws -> [BillingInvoice] {
        let (data, _) = try await request(path: "v1/billing/invoices", token: token)
        return try JSONDecoder().decode(ListResponse<BillingInvoice>.self, from: data).data
    }

    public func transactions(token: String) async throws -> [BillingTransaction] {
        let (data, _) = try await request(path: "v1/billing/transactions", token: token)
        return try JSONDecoder().decode(ListResponse<BillingTransaction>.self, from: data).data
    }
}
