import SwiftUI
import UIKit

enum AppTab: Hashable {
    case summary, sharing, you
}

struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var graph: GraphStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .summary
    @State private var health = HealthKitService()

    private var isCaregiver: Bool { session.user?.role == "CAREGIVER" }

    var body: some View {
        TabView(selection: $tab) {
            SummaryView()
                .tabItem { Label("Summary", systemImage: "house") }
                .tag(AppTab.summary)

            PeopleView()
                .tabItem { Label("Sharing", systemImage: "person.2") }
                .tag(AppTab.sharing)

            YouView()
                .tabItem { Label("You", systemImage: "person") }
                .tag(AppTab.you)
        }
        .tint(Color.flare)
        .onAppear {
            if isCaregiver { tab = .sharing }
            styleTabBar()
            catchUpHealth()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { catchUpHealth() }
        }
    }

    private func catchUpHealth() {
        guard !isCaregiver,
              let user = session.user,
              HealthKitService.isAvailable,
              health.hasPrompted
        else { return }
        Task { @MainActor in
            do {
                await health.requestProfileAccessIfNeeded()
                _ = try await WeekIngest.run(
                    patientId: user.id,
                    displayName: user.displayName,
                    health: health,
                    graph: graph,
                    activity: ActivityService(client: session.client()),
                    profile: ProfileService(client: session.client())
                )
            } catch {
                Log.health("catch-up failed: \(error.localizedDescription)")
            }
            await flushGlucose()
        }
    }

    private func flushGlucose() async {
        guard let user = session.user,
              let pending = graph.pendingGlucose(patientId: user.id)
        else { return }
        do {
            try await GlucoseService(client: session.client()).add(
                value: pending.value,
                recordedAt: pending.recordedAt
            )
            try graph.markGlucoseSynced(patientId: user.id)
        } catch {
            Log.sync("glucose failed: \(error.localizedDescription)")
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
                .foregroundColor: UIColor(Color.flare)
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

private enum SummaryHero: Int, CaseIterable {
    case steps, heartRate, duration, intensity, sedentary, glucose
}

private struct SummaryView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var graph: GraphStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var health = HealthKitService()
    @State private var prompted = false
    @State private var ingesting = false
    @State private var errorText: String?
    @State private var hero: SummaryHero = .steps
    @State private var glucoseText = ""
    @State private var savingGlucose = false
    @FocusState private var glucoseFocused: Bool

    private var isCaregiver: Bool { session.user?.role == "CAREGIVER" }
    private var needsGlucose: Bool { !isCaregiver && graph.todayGlucose == nil }

    var body: some View {
        Group {
            if isCaregiver {
                messagePoster(
                    fill: Color.ink,
                    scheme: .dark,
                    ink: Color.card,
                    title: "Pick",
                    unit: nil,
                    leftover: "Sharing. Then this tab is their day."
                )
            } else if HealthKitService.isAvailable && !prompted {
                allowPoster
            } else if needsGlucose {
                glucosePoster
            } else if !HealthKitService.isAvailable {
                messagePoster(
                    fill: Color.ink,
                    scheme: .dark,
                    ink: Color.card,
                    title: "Off",
                    unit: nil,
                    leftover: "Health isn’t on this device."
                )
            } else if ingesting && graph.today == nil {
                messagePoster(
                    fill: Color.flare,
                    scheme: .light,
                    ink: Color.ink,
                    title: "Wait",
                    unit: nil,
                    leftover: "Reading Health on this iPhone."
                )
            } else if let today = graph.today {
                metricsPoster(today)
            } else {
                messagePoster(
                    fill: Color.flare,
                    scheme: .light,
                    ink: Color.ink,
                    title: "Wait",
                    unit: nil,
                    leftover: "Reading Health on this iPhone."
                )
            }
        }
        .onAppear(perform: refreshDay)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshDay() }
        }
    }

    private func refreshDay() {
        prompted = health.hasPrompted
        if let id = session.user?.id {
            graph.refreshToday(patientId: id)
        }
    }

    private var weekday: String {
        Date.now.formatted(.dateTime.weekday(.wide))
    }

    private var allowPoster: some View {
        DippedStage(fill: Color.flare, scheme: .light) {
            VStack(alignment: .leading, spacing: 0) {
                Text(weekday)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.ink)
                Spacer()
                Text("Allow")
                    .font(AppFont.poster)
                    .foregroundStyle(Color.ink)
                    .tracking(AppTracking.poster)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                Text("Health")
                    .font(AppFont.unit)
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                Spacer()
                Text("Watch writes here. We only read steps, heart, and movement.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.ink)
                    .lineSpacing(4)
                    .padding(.bottom, 16)
                if let errorText {
                    Text(errorText)
                        .font(AppFont.captionMedium)
                        .foregroundStyle(Color.ink)
                        .padding(.bottom, 8)
                }
                Button(action: allowHealth) {
                    Text(ingesting ? "Working…" : "Allow Health")
                        .font(AppFont.button)
                        .foregroundStyle(Color.card)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(ingesting)
            }
        }
    }

    private var glucosePoster: some View {
        DippedStage(fill: Color.ink, scheme: .dark) {
            VStack(alignment: .leading, spacing: 0) {
                Text(weekday)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.card)
                Spacer()
                TextField("", text: $glucoseText, prompt: Text("0").foregroundStyle(Color.dusk))
                    .font(AppFont.poster)
                    .foregroundStyle(Color.flare)
                    .tracking(AppTracking.poster)
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .focused($glucoseFocused)
                    .minimumScaleFactor(0.25)
                    .frame(maxWidth: .infinity)
                Text("mg/dL")
                    .font(AppFont.unit)
                    .foregroundStyle(Color.card)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                Spacer()
                Text("Today’s glucose. Then the day.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.card)
                    .padding(.bottom, 16)
                if let errorText {
                    Text(errorText)
                        .font(AppFont.captionMedium)
                        .foregroundStyle(Color.alert)
                        .padding(.bottom, 8)
                }
                Button(action: saveGlucose) {
                    Text(savingGlucose ? "Working…" : "Save")
                        .font(AppFont.button)
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.flare)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(savingGlucose || glucoseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            UITextField.appearance().textColor = UIColor(Color.flare)
            glucoseFocused = true
        }
        .onDisappear {
            UITextField.appearance().textColor = UIColor(Color.ink)
        }
    }

    private func saveGlucose() {
        guard let user = session.user else { return }
        errorText = nil
        let raw = glucoseText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(raw), (GlucoseRange.minMgDl ... GlucoseRange.maxMgDl).contains(value) else {
            errorText = "Enter a mg/dL reading between 40 and 400."
            return
        }
        savingGlucose = true
        let now = Date()
        Task {
            defer { savingGlucose = false }
            do {
                try graph.saveGlucose(
                    patientId: user.id,
                    displayName: user.displayName,
                    value: value,
                    recordedAt: now
                )
                do {
                    try await GlucoseService(client: session.client()).add(value: value, recordedAt: now)
                    try graph.markGlucoseSynced(patientId: user.id)
                } catch {
                    Log.sync("glucose failed: \(error.localizedDescription)")
                }
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func metricsPoster(_ today: TodayMetrics) -> some View {
        let page = page(for: today)
        return Button(action: cycle) {
            DippedStage(fill: page.fill, scheme: page.scheme) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(weekday)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(page.ink)
                    Spacer()
                    Text(page.value)
                        .font(AppFont.poster)
                        .foregroundStyle(page.number)
                        .tracking(AppTracking.poster)
                        .minimumScaleFactor(0.25)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    if let unit = page.unit {
                        Text(unit)
                            .font(AppFont.unit)
                            .foregroundStyle(page.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(page.leftover)
                            .font(AppFont.body)
                            .foregroundStyle(page.ink)
                        if ingesting || graph.catchingUp {
                            Text("Updating…")
                                .font(AppFont.caption)
                                .foregroundStyle(page.ink)
                        }
                        if let errorText {
                            Text(errorText)
                                .font(AppFont.captionMedium)
                                .foregroundStyle(page.scheme == .dark ? Color.alert : Color.ink)
                            Text("Try again")
                                .font(AppFont.bodyMedium)
                                .foregroundStyle(page.ink)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(page.accessibility)
        .accessibilityHint("Shows the next reading")
    }

    private func messagePoster(
        fill: Color,
        scheme: ColorScheme,
        ink: Color,
        title: String,
        unit: String?,
        leftover: String
    ) -> some View {
        DippedStage(fill: fill, scheme: scheme) {
            VStack(alignment: .leading, spacing: 0) {
                Text(weekday)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(ink)
                Spacer()
                Text(title)
                    .font(AppFont.poster)
                    .foregroundStyle(ink)
                    .tracking(AppTracking.poster)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                if let unit {
                    Text(unit)
                        .font(AppFont.unit)
                        .foregroundStyle(ink)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                Spacer()
                Text(leftover)
                    .font(AppFont.body)
                    .foregroundStyle(ink)
                    .lineSpacing(4)
            }
        }
    }

    private struct HeroPage {
        var fill: Color
        var scheme: ColorScheme
        var ink: Color
        var number: Color
        var value: String
        var unit: String?
        var leftover: String
        var accessibility: String
    }

    private func page(for today: TodayMetrics) -> HeroPage {
        let steps = today.steps.formatted()
        let glucoseNote = today.glucose.map { "\(formatGlucose($0)) mg/dL" } ?? "glucose not in yet"
        switch hero {
        case .steps:
            return HeroPage(
                fill: Color.flare,
                scheme: .light,
                ink: Color.ink,
                number: Color.ink,
                value: steps,
                unit: "steps",
                leftover: glucoseNote,
                accessibility: "\(today.steps) steps"
            )
        case .heartRate:
            return HeroPage(
                fill: Color.ink,
                scheme: .dark,
                ink: Color.card,
                number: Color.card,
                value: today.heartRate.map(String.init) ?? "—",
                unit: "bpm",
                leftover: "\(steps) steps",
                accessibility: today.heartRate.map { "\($0) beats per minute" } ?? "No heart rate"
            )
        case .duration:
            return HeroPage(
                fill: Color.acid,
                scheme: .light,
                ink: Color.ink,
                number: Color.ink,
                value: "\(today.durationMinutes)",
                unit: "min",
                leftover: "\(steps) steps",
                accessibility: "\(today.durationMinutes) minutes"
            )
        case .intensity:
            return HeroPage(
                fill: Color.night,
                scheme: .dark,
                ink: Color.card,
                number: Color.acid,
                value: intensityLabel(today.intensity),
                unit: "intensity",
                leftover: "\(steps) steps",
                accessibility: "Intensity \(intensityLabel(today.intensity))"
            )
        case .sedentary:
            return HeroPage(
                fill: Color.ink,
                scheme: .dark,
                ink: Color.card,
                number: Color.warn,
                value: "\(today.sedentaryMinutes)",
                unit: "min sitting",
                leftover: "\(steps) steps",
                accessibility: "\(today.sedentaryMinutes) sedentary minutes"
            )
        case .glucose:
            return HeroPage(
                fill: Color.ink,
                scheme: .dark,
                ink: Color.card,
                number: Color.flare,
                value: today.glucose.map(formatGlucose) ?? "—",
                unit: "mg/dL",
                leftover: "\(steps) steps",
                accessibility: today.glucose.map { "\($0) milligrams per deciliter" } ?? "Glucose not in yet"
            )
        }
    }

    private func formatGlucose(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func cycle() {
        if errorText != nil {
            ingestWeek()
            return
        }
        let all = SummaryHero.allCases
        hero = all[(hero.rawValue + 1) % all.count]
    }

    private func intensityLabel(_ raw: String) -> String {
        switch raw {
        case "LIGHT": return "Light"
        case "MODERATE": return "Moderate"
        case "VIGOROUS": return "Vigorous"
        default: return raw
        }
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
        ingesting = true
        Task {
            do {
                _ = try await WeekIngest.run(
                    patientId: user.id,
                    displayName: user.displayName,
                    health: health,
                    graph: graph,
                    activity: ActivityService(client: session.client()),
                    profile: ProfileService(client: session.client())
                )
            } catch {
                errorText = error.localizedDescription
                Log.health("ingest failed: \(error.localizedDescription)")
            }
            ingesting = false
        }
    }
}

private struct YouView: View {
    @EnvironmentObject private var session: SessionStore

    private var isCaregiver: Bool { session.user?.role == "CAREGIVER" }
    private var name: String {
        let raw = session.user?.displayName.firstName ?? ""
        return raw.isEmpty ? "You" : raw
    }

    var body: some View {
        DippedStage(fill: Color.ink, scheme: .dark) {
            VStack(spacing: 12) {
                Spacer()
                Text(name)
                    .font(AppFont.poster)
                    .foregroundStyle(Color.card)
                    .tracking(AppTracking.poster)
                    .minimumScaleFactor(0.25)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                Text(session.user?.email ?? "")
                    .font(AppFont.body)
                    .foregroundStyle(Color.mute)
                Text(isCaregiver ? "Caregiver" : "Patient")
                    .font(AppFont.chip)
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isCaregiver ? Color.acid : Color.flare)
                    .clipShape(Capsule())
                Spacer()
                Button("Sign out") {
                    session.signOut()
                }
                .font(AppFont.bodyMedium)
                .foregroundStyle(Color.card)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
