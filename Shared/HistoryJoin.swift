import Foundation

/// Pair glucose and activity on the server's date key, unchanged.
///
/// The history off-by-one is a bucket on the server (UTC day of an instant
/// sent at local midnight, with `offsetMinutes` never sent). Shifting activity
/// forward here would fix Nairobi and break zones west of UTC.
enum HistoryJoin {
    struct Glucose: Equatable {
        var date: String
        var average: Double
        var readings: Int
    }

    struct Activity: Equatable {
        var date: String
        var steps: Int
        var minutes: Int
    }

    struct Row: Equatable {
        var stamp: String
        var glucose: Double?
        var readings: Int
        var steps: Int
        var activeMinutes: Int
    }

    static func rows(glucose: [Glucose], activity: [Activity]) -> [Row] {
        let glucoseByDay = Dictionary(glucose.map { ($0.date, $0) }, uniquingKeysWith: { _, latest in latest })
        let activityByDay = Dictionary(activity.map { ($0.date, $0) }, uniquingKeysWith: { _, latest in latest })
        let keys = Set(glucoseByDay.keys).union(activityByDay.keys)
        return keys.map { key in
            Row(
                stamp: key,
                glucose: glucoseByDay[key]?.average,
                readings: glucoseByDay[key]?.readings ?? 0,
                steps: activityByDay[key]?.steps ?? 0,
                activeMinutes: activityByDay[key]?.minutes ?? 0
            )
        }
        .sorted { $0.stamp < $1.stamp }
    }
}
