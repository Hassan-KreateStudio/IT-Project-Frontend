import Foundation

/// The `dashboard` arguments. `offsetMinutes` has to be in the variables map:
/// declaring `$offset` in the query and then omitting it sends null, and the
/// server then buckets in UTC.
struct DashboardQuery: Equatable {
    var from: String
    var to: String
    var offsetMinutes: Int

    static func patient(days: Int, now: Date, calendar: Calendar) -> DashboardQuery {
        let range = DayClock.queryRange(days: days, now: now, calendar: calendar)
        return DashboardQuery(
            from: APITime.encode(range.from),
            to: APITime.encode(range.to),
            offsetMinutes: range.offsetMinutes
        )
    }
}
