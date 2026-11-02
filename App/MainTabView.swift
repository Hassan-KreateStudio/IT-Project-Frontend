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
}

private struct WatchBadge: View {
    var state: WatchLink.State

    private var dotColor: Color {
        switch state {
        case .connected: return Color.acid
        case .paired: return Color.warn
        case .absent: return Color.mute
        }
    }

    private var label: String {
        switch state {
        case .connected: return "Watch connected and syncing"
        case .paired: return "Watch paired, no recent data"
        case .absent: return "No Watch paired"
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(Color.night)
                .overlay(Circle().stroke(Color.dusk, lineWidth: 1))
                .overlay(
                    Image(systemName: "applewatch")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(state == .absent ? Color.mute : Color.card)
                )
                .frame(width: 40, height: 40)
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(Color.ink, lineWidth: 2))
        }
        .accessibilityElement()
        .accessibilityLabel(label)
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
    @State private var dragX: CGFloat = 0
    @State private var dragAxis: Axis?
    @State private var isFlinging = false
    @State private var glucoseText = ""
    @State private var savingGlucose = false
    @State private var watch: WatchLink.State = .absent
    @State private var showingGlucose = false
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
                metricsDeck(today)
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
        .sheet(isPresented: $showingGlucose) {
            glucosePoster
        }
    }

    private func refreshDay() {
        prompted = health.hasPrompted
        if let id = session.user?.id {
            graph.refreshToday(patientId: id)
        }
        Task { watch = await WatchLink.current() }
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
                    .keyboardType(.numberPad)
                    .focused($glucoseFocused)
                    .onChange(of: glucoseText) { old, new in
                        let digits = new.filter(\.isNumber)
                        // Drop the keystroke that leaves the 40–400 window; >3 digits can't be valid.
                        glucoseText = digits.count > 3 || (Int(digits) ?? 0) > Int(GlucoseRange.maxMgDl) ? old : digits
                    }
                    .minimumScaleFactor(0.25)
                    .frame(maxWidth: .infinity)
                Text("mg/dL")
                    .font(AppFont.unit)
                    .foregroundStyle(Color.card)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                Spacer()
                Text("Insert today’s glucose.")
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
                showingGlucose = false
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

    private func metricsDeck(_ today: TodayMetrics) -> some View {
        let current = page(for: today, hero: hero)
        let ahead = page(for: today, hero: neighbor(1))
        let behind = page(for: today, hero: neighbor(-1))

        return DippedStage(fill: Color.ink, scheme: .dark) {
            GeometryReader { geo in
                let cardWidth = geo.size.width
                let cardHeight = min(cardWidth * 1.12, geo.size.height * 0.56)

                VStack(alignment: .leading, spacing: 0) {
                    header

                    ZStack(alignment: .bottom) {
                        fanCard(behind, today: today, width: cardWidth, height: cardHeight)
                            .rotationEffect(.degrees(-11), anchor: .bottom)
                            .offset(y: 34)
                            .scaleEffect(0.9)
                            .opacity(0.75)
                        fanCard(ahead, today: today, width: cardWidth, height: cardHeight)
                            .rotationEffect(.degrees(-5.5), anchor: .bottom)
                            .offset(y: 18)
                            .scaleEffect(0.95)
                            .opacity(0.9)
                        fanCard(current, today: today, width: cardWidth, height: cardHeight)
                            .offset(x: dragX)
                            .rotationEffect(.degrees(Double(dragX / max(cardWidth, 1)) * 4), anchor: .bottom)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: cardHeight + 44)
                    .padding(.top, 26)
                    .contentShape(Rectangle())
                    .highPriorityGesture(cardSwipe(width: geo.size.width))
                    .onTapGesture {
                        if errorText != nil { ingestWeek() }
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 6) {
                        ForEach(SummaryHero.allCases, id: \.self) { item in
                            Capsule()
                                .fill(item == hero ? Color.flare : Color.dusk)
                                .frame(width: item == hero ? 18 : 6, height: 6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .animation(.easeOut(duration: 0.2), value: hero)

                    Text("Swipe for \(ahead.label.lowercased())")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.mute)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    Button {
                        glucoseText = ""
                        showingGlucose = true
                    } label: {
                        Text("Add glucose")
                            .font(AppFont.button)
                            .foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.card)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.top, 14)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(current.accessibility)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: cycle(1)
                case .decrement: cycle(-1)
                default: break
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today")
                    .font(AppFont.largeTitle)
                    .foregroundStyle(Color.card)
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.mute)
            }
            Spacer()
            WatchBadge(state: watch)
        }
    }

    private func fanCard(_ page: HeroPage, today: TodayMetrics, width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(page.label)
                .font(AppFont.chip)
                .tracking(2.2)
                .textCase(.uppercase)
                .foregroundStyle(page.ink.opacity(0.55))

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(page.value)
                    .font(.custom("BricolageGrotesque-ExtraBold", size: page.value.count > 4 ? 66 : 104))
                    .tracking(-5)
                    .foregroundStyle(page.number)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                if let unit = page.unit {
                    Text(unit)
                        .font(AppFont.unit)
                        .foregroundStyle(page.ink.opacity(0.6))
                }
            }
            .padding(.top, 6)

            HStack(spacing: 7) {
                Circle()
                    .fill(page.ink)
                    .frame(width: 7, height: 7)
                Text(page.leftover)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(page.ink.opacity(0.72))
                    .lineLimit(2)
            }
            .padding(.top, 12)

            Spacer(minLength: 0)

            if ingesting || graph.catchingUp {
                Text("Updating…")
                    .font(AppFont.caption)
                    .foregroundStyle(page.ink.opacity(0.7))
            }
            if let errorText {
                Text(errorText)
                    .font(AppFont.captionMedium)
                    .foregroundStyle(page.scheme == .dark ? Color.alert : Color.ink)
                    .lineLimit(2)
            }

            if page.label == "Glucose" {
                HStack(spacing: 0) {
                    contextStat("Steps", today.steps.formatted(), ink: page.ink)
                    contextStat("Active", "\(today.durationMinutes) min", ink: page.ink)
                    contextStat("Heart", today.heartRate.map { "\($0) bpm" } ?? "—", ink: page.ink)
                }
                .padding(.top, 14)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(page.ink.opacity(0.16))
                        .frame(height: 1)
                }
            }
        }
        .padding(22)
        .frame(width: width, height: height, alignment: .topLeading)
        .background(page.fill)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private func contextStat(_ label: String, _ value: String, ink: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(AppFont.chip)
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(ink.opacity(0.5))
            Text(value)
                .font(.custom("BricolageGrotesque-ExtraBold", size: 20))
                .tracking(-0.5)
                .foregroundStyle(ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cardSwipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isFlinging else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                if dragAxis == nil {
                    if abs(dx) > abs(dy) { dragAxis = .horizontal }
                    else if abs(dy) > 10 { dragAxis = .vertical }
                }
                guard dragAxis == .horizontal else { return }
                dragX = dx
            }
            .onEnded { value in
                defer { dragAxis = nil }
                guard dragAxis == .horizontal else {
                    dragX = 0
                    return
                }
                let predicted = value.predictedEndTranslation.width
                let threshold = width * 0.22
                if predicted < -threshold || value.translation.width < -threshold {
                    fling(to: -width * 1.2, step: 1)
                } else if predicted > threshold || value.translation.width > threshold {
                    fling(to: width * 1.2, step: -1)
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        dragX = 0
                    }
                }
            }
    }

    private func fling(to x: CGFloat, step: Int) {
        isFlinging = true
        withAnimation(.easeIn(duration: 0.28)) {
            dragX = x
        } completion: {
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) {
                cycle(step)
                dragX = 0
            }
            isFlinging = false
        }
    }

    private func neighbor(_ step: Int) -> SummaryHero {
        let all = SummaryHero.allCases
        return all[(hero.rawValue + step + all.count) % all.count]
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
        var label: String
        var fill: Color
        var scheme: ColorScheme
        var ink: Color
        var number: Color
        var icon: String
        var value: String
        var unit: String?
        var leftover: String
        var accessibility: String
    }

    private func page(for today: TodayMetrics, hero: SummaryHero) -> HeroPage {
        let steps = today.steps.formatted()
        let glucoseNote = today.glucose.map { "\(formatGlucose($0)) mg/dL" } ?? "glucose not in yet"
        switch hero {
        case .steps:
            return HeroPage(
                label: "Steps",
                fill: Color.flare,
                scheme: .light,
                ink: Color.ink,
                number: Color.ink,
                icon: "figure.walk",
                value: steps,
                unit: "steps",
                leftover: glucoseNote,
                accessibility: "\(today.steps) steps"
            )
        case .heartRate:
            return HeroPage(
                label: "Heart rate",
                fill: Color.info,
                scheme: .light,
                ink: Color.ink,
                number: Color.ink,
                icon: "heart.fill",
                value: today.heartRate.map(String.init) ?? "—",
                unit: "bpm",
                leftover: "\(steps) steps",
                accessibility: today.heartRate.map { "\($0) beats per minute" } ?? "No heart rate"
            )
        case .duration:
            return HeroPage(
                label: "Exercise",
                fill: Color.acid,
                scheme: .light,
                ink: Color.ink,
                number: Color.ink,
                icon: "figure.run",
                value: "\(today.durationMinutes)",
                unit: "exercise min",
                leftover: "\(steps) steps",
                accessibility: "\(today.durationMinutes) minutes of exercise"
            )
        case .intensity:
            return HeroPage(
                label: "Intensity",
                fill: Color.aurora,
                scheme: .light,
                ink: Color.ink,
                number: Color.ink,
                icon: "flame.fill",
                value: intensityLabel(today.intensity),
                unit: "intensity",
                leftover: "\(steps) steps",
                accessibility: "Intensity \(intensityLabel(today.intensity))"
            )
        case .sedentary:
            return HeroPage(
                label: "Sedentary",
                fill: Color.warn,
                scheme: .light,
                ink: Color.ink,
                number: Color.ink,
                icon: "chair.fill",
                value: "\(today.sedentaryMinutes)",
                unit: "min sitting",
                leftover: "\(steps) steps",
                accessibility: "\(today.sedentaryMinutes) sedentary minutes"
            )
        case .glucose:
            return HeroPage(
                label: "Glucose",
                fill: Color.card,
                scheme: .light,
                ink: Color.ink,
                number: Color.flare,
                icon: "drop.fill",
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

    private func cycle(_ step: Int) {
        if errorText != nil {
            ingestWeek()
            return
        }
        let all = SummaryHero.allCases
        let next = (hero.rawValue + step + all.count) % all.count
        hero = all[next]
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
