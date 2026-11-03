import Foundation

/// dashboard and patientDashboard. Report on query, not a predictor.
///
/// The patient's own summary asks the server for processed numbers rather
/// than recomputing them from the local store, so two devices with the same
/// account agree.
struct AnalysisService {
    var client: GraphQLClient

    func dashboard(days: Int = 7) async throws -> DashboardSnapshot {
        struct Data: Decodable {
            let dashboard: DashboardSnapshot
        }

        let to = Date()
        let from = Calendar.current.date(byAdding: .day, value: -(days - 1), to: to) ?? to
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let data: Data = try await client.execute(
            query: """
            query($from: Time, $to: Time) {
              dashboard(from: $from, to: $to) {
                summary { totalSteps averageGlucose glucoseReadingCount totalActiveMinutes }
                glucoseTrends { date averageValue readingCount }
                activityTrends { date stepCount durationMinutes }
                alerts { code message severity }
              }
            }
            """,
            variables: ["from": formatter.string(from: from), "to": formatter.string(from: to)],
            as: Data.self
        )
        return data.dashboard
    }
}

extension DashboardSnapshot {
    /// Server trends reshaped onto a fixed day axis, matching `GraphStore.week`.
    func week(days: Int = 7, now: Date = Date()) -> [WeekPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        let glucoseByDate = Dictionary(
            glucoseTrends.map { ($0.date, $0.averageValue) },
            uniquingKeysWith: { _, latest in latest }
        )
        let stepsByDate = Dictionary(
            activityTrends.map { ($0.date, $0.stepCount) },
            uniquingKeysWith: { _, latest in latest }
        )
        let key = DateFormatter()
        key.calendar = calendar
        key.locale = Locale(identifier: "en_US_POSIX")
        key.timeZone = calendar.timeZone
        key.dateFormat = "yyyy-MM-dd"

        return (0 ..< days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let stamp = key.string(from: date)
            return WeekPoint(
                date: date,
                steps: stepsByDate[stamp] ?? 0,
                glucose: glucoseByDate[stamp]
            )
        }
    }
}
