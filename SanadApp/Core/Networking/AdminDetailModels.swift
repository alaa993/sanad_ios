import Foundation

public struct AdminOrganizationDetail: Decodable {
    public struct Detail: Decodable {
        public let organization: AdminOrganization?
        public let stats: Stats?
    }

    public struct Stats: Decodable {
        public let members: Int?
        public let specialists: Int?
        public let beneficiaries: Int?
        public let sessions_total: Int?
        public let upcoming: Int?
    }

    public let data: Detail?
}

public struct AdminSpecialistDocuments: Decodable {
    public let status: String?
    public let verification_notes: String?
    public let documents: [AdminSpecialistDocument]?
}

public struct AdminSpecialistDocument: Decodable, Identifiable {
    public let id: Int
    public let type: String?
    public let title: String?
    public let file_path: String?
    public let verified_at: String?
    public let meta: AdminDocumentMeta?
}

public struct AdminDocumentMeta: Decodable {
    public let original_name: String?
    public let mime: String?
}
