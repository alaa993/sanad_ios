import Foundation

public struct WalletBalance: Decodable {
    public let balance: Int?
    public let points: Int?
    public let transactions: [BillingTransaction]?
}

public struct WalletTopupResponse: Decodable {
    public let ok: Bool?
    public let client_secret: String?
    public let balance: Int?
    public let points: Int?
    public let msg: String?
}

public struct MtnInitResponse: Decodable {
    public let ok: Bool?
    public let reference: String?
    public let instructions: String?
    public let amount: Int?
    public let currency: String?
    public let sandbox: Bool?
    public let provider: String?
    public let ussd: String?
}

public struct MtnConfirmResponse: Decodable {
    public let ok: Bool?
    public let balance: Int?
    public let points: Int?
    public let msg: String?
}

public typealias MobileMoneyInitResponse = MtnInitResponse
public typealias MobileMoneyConfirmResponse = MtnConfirmResponse

public struct PaymentMethodsResponse: Decodable {
    public let methods: [String]?
    public let mtn_enabled: Bool?
    public let syriatel_enabled: Bool?
    public let topup_presets: [Int]?
}

/// Wallet balance, Stripe top-up intent, MTN/Syriatel Cash init+confirm, payment-method presets.
public final class WalletService {
    let base: URL
    public init(baseURL: URL? = nil) {
        self.base = baseURL ?? AppConfig.BASE_URL
    }

    public func balance(token: String) async throws -> WalletBalance {
        var req = URLRequest(url: base.appendingPathComponent("v1/wallet/me"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(WalletBalance.self, from: data)
    }

    public func applyCoupon(code: String, token: String) async throws -> WalletBalance {
        var req = URLRequest(url: base.appendingPathComponent("v1/wallet/apply-coupon"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["code": code])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(WalletBalance.self, from: data)
    }

    public func createTopupIntent(amount: Int, token: String) async throws -> WalletTopupResponse {
        var req = URLRequest(url: base.appendingPathComponent("v1/wallet/topup/intent"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["amount": amount])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(WalletTopupResponse.self, from: data)
    }

    public func mtnInit(amount: Int, phone: String?, token: String) async throws -> MtnInitResponse {
        var req = URLRequest(url: base.appendingPathComponent("v1/wallet/mtn/init"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = ["amount": amount]
        if let phone, !phone.isEmpty { payload["phone"] = phone }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(MtnInitResponse.self, from: data)
    }

    public func mtnConfirm(reference: String, transactionId: String, token: String) async throws -> MtnConfirmResponse {
        var req = URLRequest(url: base.appendingPathComponent("v1/wallet/mtn/confirm"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "reference": reference,
            "transaction_id": transactionId
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(MtnConfirmResponse.self, from: data)
    }

    public func syriatelInit(amount: Int, phone: String?, token: String) async throws -> MtnInitResponse {
        var req = URLRequest(url: base.appendingPathComponent("v1/wallet/syriatel/init"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = ["amount": amount]
        if let phone, !phone.isEmpty { payload["phone"] = phone }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(MtnInitResponse.self, from: data)
    }

    public func syriatelConfirm(reference: String, transactionId: String, token: String) async throws -> MtnConfirmResponse {
        var req = URLRequest(url: base.appendingPathComponent("v1/wallet/syriatel/confirm"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "reference": reference,
            "transaction_id": transactionId
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(MtnConfirmResponse.self, from: data)
    }

    public func paymentMethods(token: String) async throws -> PaymentMethodsResponse {
        var req = URLRequest(url: base.appendingPathComponent("v1/billing/payment-methods"))
        req.httpMethod = "GET"
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(PaymentMethodsResponse.self, from: data)
    }
}
