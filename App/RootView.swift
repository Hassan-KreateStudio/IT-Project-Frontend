import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        if session.isLoggedIn {
            HomePlaceholderView()
        } else {
            RoleSelectView()
        }
    }
}

#Preview {
    RootView()
        .environmentObject(SessionStore())
}
