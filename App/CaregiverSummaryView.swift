import SwiftUI

/// The caregiver's Summary: one week strip per patient, coloured by that day's
/// average glucose, plus the week's numbers underneath.
struct CaregiverSummaryView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var cards: [WatchCard] = []
    @State private var waiting: [User] = []
    @State private var busy = true
    @State private var errorText: String?

    var body: some View {
        LightStage {
            VStack(alignment: .leading, spacing: 3) {
                Text("Summary")
                    .font(AppFont.largeTitle)
                    .tracking(AppTracking.largeTitle)
                    .foregroundStyle(Color.ink)
                Text(subtitle)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.mute)
            }

            if let errorText {
                Text(errorText)
                    .font(AppFont.captionMedium)
                    .foregroundStyle(Color.alert)
                    .panel(padding: 12)
            }

            if busy && cards.isEmpty {
                Text("Reading…")
                    .font(AppFont.body)
                    .foregroundStyle(Color.mute)
                    .panel(padding: 16)
            } else if cards.isEmpty {
                emptyState
            } else {
                ForEach(cards) { card in
                    patientCard(card)
                }
            }

            if !warnings.isEmpty {
                Text("Worth knowing").sectionHeading().padding(.top, 6)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(warnings.enumerated()), id: \.offset) { _, alert in
                        warningRow(alert)
                    }
                }
                .panel(padding: 14)
            }

            if !waiting.isEmpty {
                Text(waitingSentence)
                    .font(AppFont.chip)
                    .foregroundStyle(Color.mute)
                    .padding(.top, 4)
            }
        }
        .refreshable { await load() }
        .onAppear { Task { await load() } }
    }

    private var subtitle: String {
        if cards.isEmpty { return waiting.isEmpty ? "Nobody yet" : "Waiting on \(waiting.count)" }
        return cards.count == 1 ? "1 person you watch" : "\(cards.count) people you watch"
    }

    private var waitingSentence: String {
        let names = waiting.map(\.displayName).joined(separator: ", ")
        return "Waiting for \(names) to accept."
    }

    private var warnings: [DashboardSnapshot.Alert] {
        cards.flatMap(\.warnings)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("None yet")
                .font(AppFont.section)
                .foregroundStyle(Color.ink)
            Text("Ask a patient from Sharing. They approve before you see anything.")
                .font(AppFont.body)
                .foregroundStyle(Color.mute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 20)
    }

    private func patientCard(_ card: WatchCard) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(card.initials)
                    .font(.custom("BricolageGrotesque-ExtraBold", size: 12))
                    .foregroundStyle(Color.ink)
                    .frame(width: 36, height: 36)
                    .background(Color.mist)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(card.name)
                        .font(.custom("BricolageGrotesque-ExtraBold", size: 17))
                        .tracking(-0.3)
                        .foregroundStyle(Color.ink)
                    Text("Average this week")
                        .font(AppFont.chip)
                        .foregroundStyle(Color.mute)
                }
                Spacer(minLength: 8)

                if let average = card.average {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(String(Int(average.rounded())))
                            .font(.custom("BricolageGrotesque-ExtraBold", size: 26))
                            .tracking(-1)
                            .foregroundStyle(tint(for: average))
                        Text("mg/dL")
                            .font(AppFont.chip)
                            .foregroundStyle(Color.mute)
                    }
                }
            }

            HStack(spacing: 5) {
                ForEach(card.week.indices, id: \.self) { index in
                    weekCell(card.week[index])
                }
            }
            .padding(.top, 13)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 16) {
                    stat("In range", card.inRangePercent.map { "\($0)%" } ?? "—", tint: nil)
                    stat("Readings", "\(card.readings)", tint: nil)
                    stat("High days", "\(card.highDays)", tint: card.highDays > 0 ? Color.warn : nil)
                }
                if card.highDays > 0 {
                    Text(card.highSentence)
                        .font(AppFont.chip)
                        .foregroundStyle(Color.mute)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 11)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.hairline).frame(height: 1)
            }
            .padding(.top, 13)

            HStack(spacing: 0) {
                mini("Steps", card.stepsToday.map { $0.formatted() } ?? "—", tint: nil)
                mini("Active", "\(card.activeMinutes)m", tint: nil)
                mini("Sitting", "\(card.sittingHours)h", tint: card.sittingHours >= 16 ? Color.warn : nil)
            }
            .padding(.top, 12)
        }
        .panel()
    }

    private func weekCell(_ day: WeekDay) -> some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(day.fill)
                    .frame(height: 42)
                if let value = day.value {
                    Text(String(Int(value.rounded())))
                        .font(.custom("BricolageGrotesque-ExtraBold", size: 12))
                        .foregroundStyle(Color.ink)
                }
            }
            .frame(height: 42)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(day.isToday ? Color.flare : Color.clear, lineWidth: 2)
            )

            Text(day.label)
                .font(AppFont.chip)
                .foregroundStyle(day.isToday ? Color.flare : Color.mute)
        }
        .frame(maxWidth: .infinity)
    }

    private func stat(_ label: String, _ value: String, tint: Color?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).sectionHeading()
            Text(value)
                .font(.custom("BricolageGrotesque-ExtraBold", size: 15))
                .foregroundStyle(tint ?? Color.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mini(_ label: String, _ value: String, tint: Color?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.custom("BricolageGrotesque-ExtraBold", size: 17))
                .tracking(-0.4)
                .foregroundStyle(tint ?? Color.ink)
            Text(label)
                .font(AppFont.chip)
                .foregroundStyle(Color.mute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func warningRow(_ alert: DashboardSnapshot.Alert) -> some View {
        let tint = alert.severity == "warning" ? Color.alert : Color.warn
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.ink)
                .frame(width: 24, height: 24)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(AlertCopy.normalized(alert.message))
                .font(AppFont.chip)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func tint(for value: Double) -> Color {
        if value < 70 { return Color.alert }
        if value > 180 { return Color.warn }
        return Color.ink
    }

    private func load() async {
        errorText = nil
        do {
            let service = CaregiverService(client: session.client())
            async let accepted = service.monitoredPatients()
            async let pending = service.pendingPatients()
            let patients = try await accepted
            waiting = try await pending

            var loaded: [WatchCard] = []
            for patient in patients {
                let dashboard = try? await service.dashboard(patientId: patient.id)
                loaded.append(card(for: patient, dashboard: dashboard))
            }

            // Anyone out of range first: the eye should land there.
            cards = loaded.sorted { lhs, rhs in
                let left = (lhs.highDays + lhs.lowDays) > 0 ? 1 : 0
                let right = (rhs.highDays + rhs.lowDays) > 0 ? 1 : 0
                if left != right { return left > right }
                return lhs.name < rhs.name
            }
        } catch {
            errorText = error.localizedDescription
        }
        busy = false
    }

    private func card(for patient: User, dashboard: DashboardSnapshot?) -> WatchCard {
        let trends = dashboard?.glucoseTrends ?? []
        let activity = dashboard?.activityTrends ?? []
        let counts = GlucoseWindowCounts(averages: trends.map(\.averageValue))
        let todayActivity = activity.last
        let activeMinutes = todayActivity?.durationMinutes ?? 0

        return WatchCard(
            id: patient.id,
            name: patient.displayName,
            initials: initials(patient.displayName),
            average: counts.daysWithReadings == 0
                ? nil
                : trends.map(\.averageValue).reduce(0, +) / Double(counts.daysWithReadings),
            week: Self.weekDays(trends: trends),
            inRangePercent: counts.inRangePercent,
            readings: trends.reduce(0) { $0 + $1.readingCount },
            highDays: counts.highDays,
            highSentence: counts.highSentence,
            lowDays: counts.lowDays,
            stepsToday: todayActivity?.stepCount,
            activeMinutes: activeMinutes,
            sittingHours: max(0, (960 - activeMinutes) / 60),
            warnings: (dashboard?.alerts ?? []).filter { alert in
                alert.code != "HIGH_SEDENTARY"
                    && !AlertCopy.isGlucoseTally(code: alert.code, message: alert.message)
            }
        )
    }

    /// Seven slots ending today, matched by the server's yyyy-MM-dd keys.
    private static func weekDays(trends: [DashboardSnapshot.GlucoseTrend]) -> [WeekDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: Date())

        let glucose = Dictionary(trends.map { ($0.date, $0.averageValue) }, uniquingKeysWith: { _, latest in latest })

        return (0 ..< 7).compactMap { offset -> WeekDay? in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: today) else { return nil }
            let stamp = DayClock.dayKey(for: date, calendar: calendar)
            let value = glucose[stamp]

            let fill: Color
            switch value {
            case let v? where v < GlucoseWindowCounts.lowMgDl: fill = Color.alert
            case let v? where v > GlucoseWindowCounts.highMgDl: fill = Color.warn
            case .some: fill = Color.acid
            case nil: fill = Color.mist
            }

            return WeekDay(
                id: stamp,
                label: date.formatted(.dateTime.weekday(.narrow)),
                value: value,
                fill: fill,
                isToday: calendar.isDateInToday(date)
            )
        }
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}

struct WeekDay: Identifiable {
    var id: String
    var label: String
    var value: Double?
    var fill: Color
    var isToday: Bool
}

struct WatchCard: Identifiable {
    var id: String
    var name: String
    var initials: String
    var average: Double?
    var week: [WeekDay]
    var inRangePercent: Int?
    var readings: Int
    var highDays: Int
    var highSentence: String
    var lowDays: Int
    var stepsToday: Int?
    var activeMinutes: Int
    var sittingHours: Int
    var warnings: [DashboardSnapshot.Alert]
}
