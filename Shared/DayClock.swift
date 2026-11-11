import Foundation

/// Civil days for the dashboard.
///
/// The server buckets an instant by adding `offsetMinutes` (the reader's zone)
/// and reading the UTC calendar date. Activity used to be sent at local
/// midnight. East of Greenwich that instant is the previous UTC date, so with
/// the offset omitted every activity row landed on the day before while
/// daytime glucose (05:30Z and later) stayed on the civil day.
enum DayClock {
    struct QueryRange: Equatable {
        var from: Date
        var to: Date
        var offsetMinutes: Int
    }

    static func offsetMinutes(at date: Date, timeZone: TimeZone) -> Int {
        timeZone.secondsFromGMT(for: date) / 60
    }

    /// `yyyy-MM-dd` in `calendar`'s zone. The key is the civil day, not the UTC day.
    static func dayKey(for date: Date, calendar: Calendar) -> String {
        var calendar = calendar
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.string(from: date)
    }

    /// Parse a civil `yyyy-MM-dd` in the reader's zone. A longer value uses only
    /// that date prefix, so a time suffix is not parsed as an instant and then
    /// shifted again. The prefix is not rewritten into a different day.
    static func parseDayKey(_ key: String, timeZone: TimeZone) -> Date? {
        guard key.count >= 10 else { return nil }
        let civil = String(key.prefix(10))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: civil)
    }

    /// Noon on the civil day. For offsets inside ±12h the UTC calendar date
    /// matches the civil day, and adding `offsetMinutes` still names that day.
    /// Local midnight does neither once the zone is east of UTC.
    static func activityInstant(on dayStart: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: dayStart)
        return calendar.date(byAdding: .hour, value: 12, to: start) ?? start
    }

    /// Same bucketing the dashboard applies: shift by the reader's offset, then
    /// take the UTC `yyyy-MM-dd`. An offset of 0 is the UTC day.
    static func bucketedDay(of instant: Date, offsetMinutes: Int) -> String {
        let shifted = instant.addingTimeInterval(TimeInterval(offsetMinutes * 60))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.string(from: shifted)
    }

    /// `days` civil days ending today, inclusive. `from` is local midnight of
    /// the first day so a reading at the start of that day is inside the window.
    static func queryRange(days: Int, now: Date, calendar: Calendar) -> QueryRange {
        let span = max(days, 1)
        let today = calendar.startOfDay(for: now)
        let from = calendar.date(byAdding: .day, value: -(span - 1), to: today) ?? today
        return QueryRange(
            from: from,
            to: now,
            offsetMinutes: offsetMinutes(at: now, timeZone: calendar.timeZone)
        )
    }
}
