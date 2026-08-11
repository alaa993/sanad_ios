import SwiftUI

/// يوجّه تبويب الملف حسب الدور — مطابق لـ Android (Profile / SpecialistProfile / AdminProfile).
struct ProfileTabView: View {
    @EnvironmentObject var authVM: AuthViewModel

    @ViewBuilder
    var body: some View {
        switch (authVM.userRole ?? "patient").lowercased() {
        case "admin":
            if #available(iOS 16.0, *) {
                NavigationStack { AdminProfileView().environmentObject(authVM) }
            } else {
                NavigationView { AdminProfileView().environmentObject(authVM) }
            }
        case "specialist":
            if #available(iOS 16.0, *) {
                NavigationStack { SpecialistProfileTabView() }
            } else {
                NavigationView { SpecialistProfileTabView() }
            }
        case "organization":
            OrgProfileTabView().environmentObject(authVM)
        default:
            ProfileView()
        }
    }
}
