import SwiftUI

struct HomePlaceholderView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Home")
                .font(AppFont.largeTitle)
                .foregroundStyle(Color.ink)
                .tracking(AppTracking.largeTitle)

            Text(session.user?.displayName ?? "")
                .font(AppFont.section)
                .foregroundStyle(Color.ink)
                .tracking(AppTracking.section)

            Text(session.user?.email ?? "")
                .font(AppFont.body)
                .foregroundStyle(Color.mute)

            Button("Sign out") {
                session.signOut()
            }
            .font(AppFont.bodyMedium)
            .foregroundStyle(Color.flare)

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.canvas.ignoresSafeArea())
    }
}
