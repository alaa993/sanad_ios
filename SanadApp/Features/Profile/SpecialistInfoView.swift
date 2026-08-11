import SwiftUI

/// مطابق لـ `SpecialistInfoFragment`.
struct SpecialistInfoView: View {
    let profile: SpecialistProfileData

    var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 14) {
                infoRow("specialist_profile_specialty", value: profile.specialty ?? NSLocalizedString("specialist_profile_specialty_unset", comment: ""))
                infoRow("specialist_edit_years", value: "\(profile.years_exp ?? 0)")
                infoRow("specialist_profile_price", value: rateText)
                infoRow("specialist_edit_accepting", value: String(format: NSLocalizedString("specialist_accepting_label", comment: ""), acceptingText))
                infoRow("specialist_profile_languages", value: profile.languages?.joined(separator: " · ") ?? NSLocalizedString("specialist_profile_specialty_unset", comment: ""))
                infoRow("specialist_profile_verification_status", value: statusLabel(profile.status))
                if let notes = profile.verification_notes, !notes.isEmpty {
                    infoRow("specialist_profile_verification_notes", value: notes)
                }
                infoRow("specialist_edit_bio", value: bioText)
            }
            .padding(20)
        }
        .background(SanadTheme.surface.ignoresSafeArea())
        .navigationTitle("specialist_info")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var rateText: String {
        guard let cents = profile.rate_cents, cents > 0 else {
            return NSLocalizedString("specialist_profile_specialty_unset", comment: "")
        }
        let curr = (profile.currency ?? "USD").uppercased()
        return String(format: NSLocalizedString("specialist_rate_format", comment: ""), curr, Float(cents) / 100)
    }

    private var acceptingText: String {
        SpecialistAccepting.isAccepting(profile.accepting_new)
            ? NSLocalizedString("specialist_accepting_yes", comment: "")
            : NSLocalizedString("specialist_accepting_no", comment: "")
    }

    private var bioText: String {
        guard let bio = profile.bio, !bio.isEmpty else {
            return NSLocalizedString("specialist_profile_specialty_unset", comment: "")
        }
        if let ar = bio["ar"], !ar.isEmpty { return ar }
        return bio.values.first ?? NSLocalizedString("specialist_profile_specialty_unset", comment: "")
    }

    private func infoRow(_ key: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(key)
                .font(.system(size: 12))
                .foregroundColor(SanadTheme.placeholder)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(SanadTheme.onBg)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(SanadTheme.card))
    }

    private func statusLabel(_ status: String?) -> String {
        switch status?.lowercased() {
        case "approved": return NSLocalizedString("specialist_verification_approved", comment: "")
        case "rejected": return NSLocalizedString("specialist_verification_rejected", comment: "")
        case "under_review": return NSLocalizedString("specialist_verification_under_review", comment: "")
        default: return NSLocalizedString("specialist_verification_pending", comment: "")
        }
    }
}

enum SpecialistAccepting {
    static func isAccepting(_ value: Bool?) -> Bool {
        value == true
    }
}
