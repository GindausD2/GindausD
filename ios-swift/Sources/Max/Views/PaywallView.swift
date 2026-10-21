import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var authService: AuthService
    var body: some View {
        ZStack {
            CompanionCanvas()
            PlanPage(onBack: { authService.signOut() })
        }
    }
}
