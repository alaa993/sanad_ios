import Foundation

/// صلاحيات واجهة المجتمع حسب الدور — تبسيط العرض ومنع الخيارات غير المناسبة.
struct CommunityRolePolicy {
    let role: String

    init(rawRole: String?) {
        let r = (rawRole ?? "patient").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if r.contains("admin") {
            role = "admin"
        } else if r.contains("specialist") || r.contains("therapist") || r.contains("counselor") {
            role = "specialist"
        } else if r.contains("organization") || r == "org" {
            role = "organization"
        } else if r.contains("patient") || r.isEmpty {
            role = "patient"
        } else {
            role = r
        }
    }

    var screenTitleKey: String {
        switch role {
        case "organization": return "community_org_title"
        case "specialist": return "community_specialist_title"
        case "admin": return "community_admin_title"
        default: return "community_list_title"
        }
    }

    var screenSubtitleKey: String {
        switch role {
        case "organization": return "community_org_subtitle"
        case "specialist": return "community_specialist_subtitle"
        case "admin": return "community_header_subtitle_admin"
        default: return "community_header_subtitle"
        }
    }

    var showsSearch: Bool { role == "patient" || role == "specialist" || role == "admin" }

    var showsFilters: Bool { role == "patient" }

    var showsPublicFeedCta: Bool { role != "organization" }

    var showsVent: Bool { role == "patient" }

    var showsAnonymousMatch: Bool { role == "patient" }

    var showsCoach: Bool { role == "patient" }

    var canJoinFreely: Bool { role != "organization" }

    var canCreateCommunity: Bool { role == "admin" || role == "organization" }

    var defaultPostType: String {
        switch role {
        case "patient": return "personal"
        case "admin": return "official"
        default: return "awareness"
        }
    }

    func canPost(in community: CommunitySummary?) -> Bool {
        guard community?.joined == true else { return false }
        switch role {
        case "organization":
            return community?.organization_owned == true
        default:
            return true
        }
    }

    func canAnswerQA() -> Bool {
        role == "specialist" || role == "admin" || role == "organization"
    }

    func filters(_ communities: [CommunitySummary]) -> [CommunitySummary] {
        switch role {
        case "organization":
            return communities.filter { $0.organization_owned == true || ($0.slug?.hasPrefix("org-support") == true) }
        case "patient":
            return communities.filter { $0.organization_owned != true }
        default:
            return communities
        }
    }
}
