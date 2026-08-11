import Foundation

public struct OrgBeneficiaryDetail: Decodable {
    public struct Detail: Decodable {
        public let beneficiary: OrgBeneficiaryInfo?
        public let patient: OrgPatient?
        public let assigned_specialist: OrgSpecialistMini?
        public let sessions: [OrgAppointment]?
    }
    public let data: Detail?
}

public struct OrgBeneficiaryInfo: Decodable {
    public let id: Int?
    public let organization_id: Int?
    public let patient_id: Int?
    public let assigned_specialist_id: Int?
    public let status: String?
    public let risk_level: String?
    public let primary_issue: String?
    public let notes: String?
    public let last_session_at: String?
}

public struct OrgPatient: Decodable {
    public let id: Int?
    public let name: String?
    public let email: String?
    public let phone: String?
}

public struct OrgSpecialistMini: Decodable {
    public let id: Int?
    public let name: String?
    public let email: String?
    public let phone: String?
}

public struct OrgSpecialistDetail: Decodable {
    public struct Detail: Decodable {
        public let specialist: OrgSpecialistMini?
        public let stats: Stats?
        public let sessions: [OrgAppointment]?
        public let beneficiaries: [OrgBeneficiaryMini]?
    }

    public struct Stats: Decodable {
        public let sessions_count: Int?
        public let commitment_rate: Double?
        public let next_session_at: String?
    }

    public let data: Detail?
}

public struct OrgBeneficiaryMini: Decodable, Identifiable {
    public let id: Int
    public let name: String?
    public let risk_level: String?
}
