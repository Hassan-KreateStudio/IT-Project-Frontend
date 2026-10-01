import SwiftUI

enum AppTab: Hashable {
    case today, trends, people, you
}

struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var graph: GraphStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .today
    @State private var health = HealthKitService()

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
            styleTabBar()
            catchUpHealth()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { catchUpHealth() }
        }
        .preferredColorScheme(.light)
    }

    private func catchUpHealth() {
        guard !isCaregiver,
              let user = session.user,
              HealthKitService.isAvailable,
              health.hasPrompted
        else { return }
        Task {
            do {
                _ = try await WeekIngest.run(
                    patientId: user.id,
                    displayName: user.displayName,
                    health: health,
                    graph: graph,
                    activity: ActivityService(client: session.client())
                )
            } catch {
                Log.health("catch-up failed: \(error.localizedDescription)")
            }
        }
    }

    private func styleTabBar() {
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
}

private struct TodayView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var graph: GraphStore
    @State private var health = HealthKitService()
    @State private var prompted = false
    @State private var ingesting = false
    @State private var syncNote: String?
    @State private var errorText: String?

    private var isCaregiver: Bool { session.user?.role == "CAREGIVER" }

    var body: some View {
        ScrollView {
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
                } else if ingesting && graph.today == nil {
                    gettingThisWeek
                } else if let today = graph.today {
                    todayCards(today)
                    if ingesting || graph.catchingUp {
                        Text("Updating this week…")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.mute)
                    }
                } else {
                    gettingThisWeek
                }

                if let syncNote {
                    Text(syncNote)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.mute)
                }

                if let errorText {
                    Text(errorText)
                        .font(AppFont.captionMedium)
                        .foregroundStyle(Color.alert)
                    Button("Try again", action: ingestWeek)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.flare)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color.canvas.ignoresSafeArea())
        .onAppear {
            prompted = health.hasPrompted
            if let id = session.user?.id {
                graph.refreshToday(patientId: id)
            }
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
                Text(ingesting ? "Working…" : "Allow Health")
                    .font(AppFont.button)
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.flare)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(ingesting)
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

    private var gettingThisWeek: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Getting this week…")
                .font(AppFont.cardTitle)
                .foregroundStyle(Color.ink)
                .tracking(AppTracking.section)
            Text("Reading Health on this iPhone. Simulator days are often 0.")
                .font(AppFont.body)
                .foregroundStyle(Color.mute)
                .lineSpacing(4)
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

    private func todayCards(_ today: TodayMetrics) -> some View {
        VStack(spacing: 12) {
            metricCard(title: "Steps", value: "\(today.steps)")
            metricCard(
                title: "Heart rate",
                value: today.heartRate.map(String.init) ?? "—",
                unit: today.heartRate == nil ? nil : "bpm"
            )
            metricCard(title: "Duration", value: "\(today.durationMinutes)", unit: "min")
            metricCard(title: "Intensity", value: intensityLabel(today.intensity))
            metricCard(title: "Sedentary", value: "\(today.sedentaryMinutes)", unit: "min")
        }
    }

    private func intensityLabel(_ raw: String) -> String {
        switch raw {
        case "LIGHT": return "Light"
        case "MODERATE": return "Moderate"
        case "VIGOROUS": return "Vigorous"
        default: return raw
        }
    }

    private func metricCard(title: String, value: String, unit: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFont.label)
                .foregroundStyle(Color.mute)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(AppFont.metric)
                    .foregroundStyle(Color.ink)
                    .tracking(AppTracking.metric)
                if let unit {
                    Text(unit)
                        .font(AppFont.unit)
                        .foregroundStyle(Color.mute)
                }
            }
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
        ingesting = true
        Task {
            do {
                try await health.requestAccess()
                prompted = health.hasPrompted
                ingestWeek()
            } catch {
                ingesting = false
                errorText = error.localizedDescription
                Log.health("permission failed: \(error.localizedDescription)")
            }
        }
    }

    private func ingestWeek() {
        guard let user = session.user else { return }
        errorText = nil
        syncNote = nil
        ingesting = true
        Task {
            do {
                let synced = try await WeekIngest.run(
                    patientId: user.id,
                    displayName: user.displayName,
                    health: health,
                    graph: graph,
                    activity: ActivityService(client: session.client())
                )
                if synced {
                    syncNote = "Week is on the phone and sent to the API."
                } else {
                    syncNote = "Week is on the phone. Couldn’t reach the server — we’ll retry next time."
                }
            } catch {
                errorText = error.localizedDescription
                Log.health("ingest failed: \(error.localizedDescription)")
            }
            ingesting = false
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
