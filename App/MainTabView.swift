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
    @State private var health = HealthKitService()
    @State private var prompted = false
    @State private var busy = false
    @State private var errorText: String?

    private var isCaregiver: Bool { session.user?.role == "CAREGIVER" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isCaregiver ? "Their day" : greeting)
                .font(AppFont.largeTitle)
                .foregroundStyle(Color.ink)
                .tracking(AppTracking.largeTitle)

            if isCaregiver {
                Text("Pick someone in People. This tab will show their latest steps and glucose.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.mute)
                    .lineSpacing(4)
            } else if !HealthKitService.isAvailable {
                Text("Health isn’t on this device, so Watch steps can’t land here. You can still log glucose later.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.mute)
                    .lineSpacing(4)
            } else if !prompted {
                permissionCard
            } else {
                Text("Latest steps, glucose, and alerts will live here. Log a reading with + — not a fifth tab.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.mute)
                    .lineSpacing(4)
            }

            if let errorText {
                Text(errorText)
                    .font(AppFont.captionMedium)
                    .foregroundStyle(Color.alert)
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.canvas.ignoresSafeArea())
        .onAppear {
            prompted = health.hasPrompted
        }
    }

    private var greeting: String {
        let name = session.user?.displayName.split(separator: " ").first.map(String.init) ?? "there"
        return "Hi, \(name)"
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "applewatch")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Color.ink)

            Text("Allow Health")
                .font(AppFont.cardTitle)
                .foregroundStyle(Color.ink)
                .tracking(AppTracking.section)

            Text("Your Watch writes to Health on this iPhone. Graph Health only reads it — steps, heart rate, and movement — so Today can fill in.")
                .font(AppFont.body)
                .foregroundStyle(Color.mute)
                .lineSpacing(4)

            Button(action: allowHealth) {
                Text(busy ? "Working…" : "Allow Health")
                    .font(AppFont.button)
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.flare)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(busy)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.hairline, lineWidth: 1)
        )
    }

    private func allowHealth() {
        errorText = nil
        busy = true
        Task {
            defer { busy = false }
            do {
                try await health.requestAccess()
                prompted = health.hasPrompted
            } catch {
                errorText = error.localizedDescription
            }
        }
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
