import Foundation

/// dashboard and patientDashboard. Report on query, not a predictor.
///
/// The patient's own summary asks the server for processed numbers rather
/// than recomputing them from the local store, so two devices with the same
/// account agree.
struct AnalysisService {
    var client: GraphQLClient

    func dashboard(days: Int = 7, now: Date = Date(), calendar: Calendar = .current) async throws -> DashboardSnapshot {
        struct Data: Decodable {
            let dashboard: DashboardSnapshot
        }

        let query = DashboardQuery.patient(days: days, now: now, calendar: calendar)
        let data: Data = try await client.execute(
            query: """
            query($from: Time, $to: Time, $offsetMinutes: Int) {
              dashboard(from: $from, to: $to, offsetMinutes: $offsetMinutes) {
                summary { totalSteps averageGlucose glucoseReadingCount totalActiveMinutes }
                glucoseTrends { date averageValue readingCount }
                activityTrends { date stepCount durationMinutes }
                alerts { code message severity }
              }
            }
            """,
            variables: [
                "from": query.from,
                "to": query.to,
                "offsetMinutes": query.offsetMinutes
            ],
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
        return (0 ..< days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let stamp = DayClock.dayKey(for: date, calendar: calendar)
            return WeekPoint(
                date: date,
                steps: stepsByDate[stamp] ?? 0,
                glucose: glucoseByDate[stamp]
            )
        }
    }
}
