import SwiftUI

/// Unified Sanad icon catalog (Assets.xcassets/Icons). Template-tinted with theme colors.
enum SanadIcon: String, CaseIterable, Identifiable {
    case home = "ic_home"
    case care = "ic_care"
    case profile = "ic_profile"
    case sessions = "ic_sessions"
    case bookSession = "ic_book_session"
    case chat = "ic_chat"
    case vent = "ic_vent"
    case community = "ic_community"
    case specialists = "ic_specialists"
    case patients = "ic_patients"
    case library = "ic_library"
    case wallet = "ic_wallet"
    case calendar = "ic_calendar"
    case notifications = "ic_notifications"
    case safePlace = "ic_safe_place"
    case tasks = "ic_tasks"
    case coach = "ic_coach"
    case match = "ic_match"
    case reports = "ic_reports"
    case settings = "ic_settings"
    case approveSpecialist = "ic_approve_specialist"
    case approveOrg = "ic_approve_org"
    case beneficiaries = "ic_beneficiaries"
    case billing = "ic_billing"
    case dailyTips = "ic_daily_tips"
    case mic = "ic_mic"
    case micOff = "ic_mic_off"
    case cam = "ic_cam"
    case camOff = "ic_cam_off"
    case callEnd = "ic_call_end"
    case switchCamera = "ic_switch_camera"
    case send = "ic_send"
    case attach = "ic_attach"
    case accept = "ic_action_accept"
    case reject = "ic_action_reject"
    case extend = "ic_action_extend"
    case complete = "ic_action_complete"
    case manage = "ic_action_manage"
    case email = "ic_email"
    case lock = "ic_lock"
    case chevronLeft = "ic_chevron_left"
    case chevronRight = "ic_chevron_right"
    case eye = "ic_eye"
    case eyeOff = "ic_eye_off"
    case empty = "ic_empty"
    case info = "ic_info"
    case error = "ic_error"
    case success = "ic_success"
    case warning = "ic_warning"
    case like = "ic_like"
    case star = "ic_star"
    case more = "ic_more"
    case image = "ic_image"
    case placeholder = "ic_placeholder"
    case addSession = "ic_add_session"
    case unread = "ic_unread"

    var id: String { rawValue }

    var image: Image {
        Image(rawValue)
            .renderingMode(.template)
    }

    @ViewBuilder
    func view(size: CGFloat = 22) -> some View {
        image
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }

    /// Map legacy SF Symbol / shortcut ids to Sanad icons.
    static func forShortcut(id: String) -> SanadIcon {
        let key = id.lowercased()
        if let exact = fromSystemName(key) { return exact }
        if key.contains("book") || key.contains("add_session") { return .bookSession }
        if key.contains("session") { return .sessions }
        if key.contains("chat") || key.contains("message") || key.contains("bubble") { return .chat }
        if key.contains("vent") || key == "wind" { return .vent }
        if key.contains("community") || key.contains("person.3") { return .community }
        if key.contains("group") && !key.contains("person") { return .community }
        if key.contains("specialist") || key.contains("doctor") || key.contains("stethoscope") { return .specialists }
        if key.contains("patient") && !key.contains("task") { return .patients }
        if key.contains("library") || key.contains("article") || key.contains("books") { return .library }
        if key.contains("wallet") || key.contains("creditcard") { return .wallet }
        if key.contains("calendar") || key.contains("appointment") || key.contains("availability") { return .calendar }
        if key.contains("notif") || key.contains("bell") { return .notifications }
        if key.contains("safe") || key.contains("lock.shield") || key.contains("shield") { return .safePlace }
        if key.contains("task") { return .tasks }
        if key.contains("coach") || key.contains("sparkle") { return .coach }
        if key.contains("match") || key.contains("anonymous") { return .match }
        if key.contains("report") || key.contains("chart") { return .reports }
        if key.contains("setting") || key.contains("gear") { return .settings }
        if key.contains("approve_special") || key.contains("checkmark.seal") { return .approveSpecialist }
        if key.contains("approve_org") || key.contains("building") { return .approveOrg }
        if key.contains("beneficiar") { return .beneficiaries }
        if key.contains("billing") || key.contains("invoice") { return .billing }
        if key.contains("tip") || key.contains("daily") || key.contains("lightbulb") { return .dailyTips }
        if key.contains("house") { return .home }
        if key.contains("heart.text") || key.contains("care") { return .care }
        if key.contains("person.crop") || key.contains("profile") || key.contains("user") { return .profile }
        if key.contains("star") { return .star }
        if key.contains("envelope") { return .unread }
        if key.contains("paperclip") { return .attach }
        if key.contains("paperplane") || key.contains("arrow.up") { return .send }
        if key.contains("mic.slash") { return .micOff }
        if key.contains("mic") { return .mic }
        if key.contains("video.slash") { return .camOff }
        if key.contains("video") { return .cam }
        if key.contains("phone.down") || key.contains("call") { return .callEnd }
        if key.contains("tray") { return .empty }
        if key.contains("lock") { return .lock }
        if key.contains("envelope") || key.contains("mail") { return .email }
        return .placeholder
    }

    static func fromSystemName(_ name: String) -> SanadIcon? {
        switch name {
        case "house.fill", "house": return .home
        case "heart.text.square.fill", "heart.fill", "heart": return .care
        case "person.crop.circle.fill", "person.fill", "person": return .profile
        case "calendar", "calendar.badge.clock": return .calendar
        case "envelope.badge": return .unread
        case "star.fill", "star": return .star
        case "bubble.left.and.bubble.right.fill", "bubble.left.and.bubble.right": return .chat
        case "wind": return .vent
        case "books.vertical.fill", "books.vertical", "book": return .library
        case "person.3", "person.3.fill": return .community
        case "stethoscope": return .specialists
        case "lock.shield.fill": return .safePlace
        case "bell", "bell.fill": return .notifications
        case "paperclip": return .attach
        case "paperplane.fill", "arrow.up.circle.fill": return .send
        case "mic.fill": return .mic
        case "mic.slash.fill": return .micOff
        case "video.fill": return .cam
        case "video.slash.fill": return .camOff
        case "phone.down.fill": return .callEnd
        case "arrow.triangle.2.circlepath.camera": return .switchCamera
        case "tray": return .empty
        case "checkmark.seal": return .approveSpecialist
        case "building.2": return .approveOrg
        case "chart.bar": return .reports
        case "gearshape", "gearshape.fill": return .settings
        case "lightbulb": return .dailyTips
        case "wallet.pass": return .wallet
        case "creditcard": return .billing
        case "person.crop.circle.badge.plus", "person.2", "person.2.fill": return .beneficiaries
        case "chevron.left": return .chevronLeft
        case "chevron.right", "chevron.forward": return .chevronRight
        case "eye.fill", "eye": return .eye
        case "eye.slash.fill", "eye.slash": return .eyeOff
        case "envelope", "envelope.fill": return .email
        case "lock", "lock.fill": return .lock
        case "exclamationmark.circle.fill": return .error
        case "info.circle.fill": return .info
        case "checkmark.circle.fill": return .success
        case "exclamationmark.triangle.fill": return .warning
        case "hand.thumbsup.fill": return .like
        default: return nil
        }
    }
}
