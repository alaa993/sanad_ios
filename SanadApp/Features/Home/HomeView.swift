import SwiftUI

enum DashboardMode {
    case shortcutsOnly
    case dashboard
}

struct HomeView: View {
    @EnvironmentObject var authVM: AuthViewModel
    let mode: DashboardMode

    var body: some View {
        Group {
            switch (authVM.userRole ?? "patient").lowercased() {
            case "specialist":
                SpecialistDashboardView(mode: mode)
            case "organization":
                OrgDashboardView(mode: mode)
            case "admin":
                AdminDashboardView(mode: mode)
            default:
                PatientDashboardView(mode: mode)
            }
        }
    }
}

#Preview {
    HomeView(mode: .dashboard)
        .environmentObject(AuthViewModel())
}
