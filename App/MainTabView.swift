import SwiftUI

enum AppTab: Hashable {
    case today, trends, people, you
}

struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var tab: AppTab = .today

    private var isCaregiver: Bool { session.user?.role == "CAREGIVER" }

    var body: some View {
        TabView(selection: $tab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "house") }
                .tag(AppTab.today)

            TrendsView()
                .tabItem { Label("Trends", systemImage: "square.grid.2x2") }
                .tag(AppTab.trends)

            PeopleView()
                .tabItem { Label("People", systemImage: "person.2") }
                .tag(AppTab.people)

            YouView()
                .tabItem { Label("You", systemImage: "person") }
                .tag(AppTab.you)
        }
        .tint(Color.flare)
        .onAppear {
            if isCaregiver { tab = .people }
            let item = UITabBarItem.appearance()
            item.setTitleTextAttributes(
                [
                    .font: UIFont(name: "Outfit-Medium", size: 10) as Any,
                    .foregroundColor: UIColor(Color.mute)
                ],
                for: .normal
            )
            item.setTitleTextAttributes(
                [
                    .font: UIFont(name: "Outfit-Medium", size: 10) as Any,
                    .foregroundColor: UIColor(Color.ink)
                ],
                for: .selected
            )
            let bar = UITabBarAppearance()
            bar.configureWithOpaqueBackground()
            bar.backgroundColor = UIColor(Color.canvas)
            bar.shadowColor = UIColor(Color.hairline)
            UITabBar.appearance().standardAppearance = bar
            UITabBar.appearance().scrollEdgeAppearance = bar
        }
        .preferredColorScheme(.light)
    }
}

private struct TodayView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        tabScreen(
            title: session.user?.role == "CAREGIVER" ? "Their day" : greeting,
            body: session.user?.role == "CAREGIVER"
                ? "Pick someone in People. This tab will show their latest steps and glucose."
                : "Latest steps, glucose, and alerts will live here. Log a reading with + — not a fifth tab."
        )
    }

    private var greeting: String {
        let name = session.user?.displayName.split(separator: " ").first.map(String.init) ?? "there"
        return "Hi, \(name)"
    }
}

private struct TrendsView: View {
    var body: some View {
        tabScreen(
            title: "Trends",
            body: "Query-time rollups from dashboard. Not a stored predictor."
        )
    }
}

private struct PeopleView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        tabScreen(
            title: "People",
            body: session.user?.role == "CAREGIVER"
                ? "Patients who added this email. Empty until they link you."
                : "Add a caregiver with their email. They sign in as caregiver with that same address."
        )
    }
}

private struct YouView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("You")
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

            Text(session.user?.role == "CAREGIVER" ? "Caregiver" : "Patient")
                .font(AppFont.chip)
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(session.user?.role == "CAREGIVER" ? Color.acid : Color.flare)
                .clipShape(Capsule())

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

private func tabScreen(title: String, body: String) -> some View {
    VStack(alignment: .leading, spacing: 16) {
        Text(title)
            .font(AppFont.largeTitle)
            .foregroundStyle(Color.ink)
            .tracking(AppTracking.largeTitle)

        Text(body)
            .font(AppFont.body)
            .foregroundStyle(Color.mute)
            .lineSpacing(4)

        Spacer()
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color.canvas.ignoresSafeArea())
}
