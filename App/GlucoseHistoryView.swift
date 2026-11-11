import SwiftUI

/// Past days, newest first, straight from the server dashboard. Averages, not
/// individual readings — the phone only ever keeps one reading per day.
struct GlucoseHistoryView: View {
    var client: GraphQLClient

    @Environment(\.dismiss) private var dismiss
    @State private var days: [HistoryDay] = []
    @State private var loading = true
    @State private var errorText: String?

    var body: some View {
        DippedStage(fill: Color.ink, scheme: .dark) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("History")
                                .font(AppFont.largeTitle)
                                .foregroundStyle(Color.card)
                            Text("Glucose and movement, last 30 days")
                                .font(AppFont.caption)
                                .foregroundStyle(Color.mute)
                        }
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.card)
                                .frame(width: 36, height: 36)
                                .background(Color.night)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 16)

                    if let errorText {
                        Text(errorText)
                            .font(AppFont.captionMedium)
                            .foregroundStyle(Color.alert)
                            .padding(.bottom, 12)
                    }

                    if loading && days.isEmpty {
                        Text("Reading…")
                            .font(AppFont.body)
                            .foregroundStyle(Color.mute)
                            .padding(.vertical, 30)
                    } else if days.isEmpty {
                        Text("Nothing logged yet.")
                            .font(AppFont.body)
                            .foregroundStyle(Color.mute)
                            .padding(.vertical, 30)
                    } else {
                        ForEach(days) { day in
                            row(day)
                            if day.id != days.last?.id {
                                Rectangle()
                                    .fill(Color.dusk)
                                    .frame(height: 1)
                                    .padding(.leading, 58)
                            }
                        }
                    }
                }
            }
        }
        .task { await load() }
    }

    private func row(_ day: HistoryDay) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 0) {
                Text(day.weekday)
                    .font(AppFont.chip)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.mute)
                Text(day.dayNumber)
                    .font(.custom("BricolageGrotesque-ExtraBold", size: 20))
                    .foregroundStyle(Color.card)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 3) {
                if let average = day.glucose {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(Int(average.rounded())))
                            .font(.custom("BricolageGrotesque-ExtraBold", size: 24))
                            .tracking(-0.8)
                            .foregroundStyle(tint(average))
                        Text("mg/dL")
                            .font(AppFont.chip)
                            .foregroundStyle(Color.mute)
                        Text(day.readingLabel)
                            .font(AppFont.chip)
                            .foregroundStyle(Color.mute)
                            .padding(.leading, 2)
                    }
                } else {
                    Text("No reading")
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.mute)
                }
                Text("\(day.steps.formatted()) steps · \(day.activeMinutes) min")
                    .font(AppFont.chip)
                    .foregroundStyle(Color.mute)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
    }

    private func tint(_ value: Double) -> Color {
        if value < 70 { return Color.alert }
        if value > 180 { return Color.warn }
        return Color.flare
    }

    private func load() async {
        do {
            let snapshot = try await AnalysisService(client: client).dashboard(days: 30)
            days = HistoryDay.from(snapshot).reversed()
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
        loading = false
    }
}

struct HistoryDay: Identifiable {
    var id: String { stamp }
    var stamp: String
    var date: Date
    var glucose: Double?
    var readings: Int
    var steps: Int
    var activeMinutes: Int

    var weekday: String { date.formatted(.dateTime.weekday(.abbreviated)) }
    var dayNumber: String { date.formatted(.dateTime.day()) }
    var readingLabel: String { Plural.readings(readings) }

    static func from(_ snapshot: DashboardSnapshot, timeZone: TimeZone = .current) -> [HistoryDay] {
        HistoryJoin.rows(
            glucose: snapshot.glucoseTrends.map {
                HistoryJoin.Glucose(date: $0.date, average: $0.averageValue, readings: $0.readingCount)
            },
            activity: snapshot.activityTrends.map {
                HistoryJoin.Activity(date: $0.date, steps: $0.stepCount, minutes: $0.durationMinutes)
            }
        )
        .compactMap { row in
            guard let date = DayClock.parseDayKey(row.stamp, timeZone: timeZone) else { return nil }
            return HistoryDay(
                stamp: row.stamp,
                date: date,
                glucose: row.glucose,
                readings: row.readings,
                steps: row.steps,
                activeMinutes: row.activeMinutes
            )
        }
        .sorted { $0.date < $1.date }
    }
}
