import SwiftUI

struct HomePlaceholderView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Home")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.ink)

            Text(session.user?.displayName ?? "")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.ink)

            Text(session.user?.email ?? "")
                .font(.system(size: 15))
                .foregroundStyle(Color.mute)

            Button("Sign out") {
                session.signOut()
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color.forest)

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.canvas.ignoresSafeArea())
    }
}
