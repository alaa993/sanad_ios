import SwiftUI

struct FilterChips: View {
    @Binding var selected: String
    let options: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { opt in
                    let active = selected == opt
                    Text(label(opt))
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(active ? SanadTheme.primary : SanadTheme.primary.opacity(0.1)))
                        .foregroundColor(active ? SanadTheme.onPrimary : SanadTheme.primary)
                        .onTapGesture { selected = opt }
                }
            }
        }
    }

    private func label(_ v: String) -> String {
        switch v {
        case "all": return "الكل"
        case "personal": return "شخصي"
        case "awareness": return "توعوي"
        case "official": return "رسمي"
        default: return v
        }
    }
}

