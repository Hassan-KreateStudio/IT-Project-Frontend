import Foundation

/// RFC3339 instants for the GraphQL `Time` scalar.
///
/// Encoding and parsing each apply the zone once. 08:30 in Africa/Nairobi is
/// `05:30:00Z`. Formatting that instant back in Nairobi is 08:30, not 11:30.
/// A string with no zone is rejected so a wall-clock "05:30" is not read as
/// UTC and then shown three hours later.
enum APITime {
    static func encode(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    static func parse(_ string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.timeZone = TimeZone(secondsFromGMT: 0)
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) {
            return date
        }
        let plain = ISO8601DateFormatter()
        plain.timeZone = TimeZone(secondsFromGMT: 0)
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }

    /// 24-hour clock in `timeZone`, zero-padded. Tests lock this to a single conversion.
    static func clock(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        formatter.isLenient = false
        return formatter.string(from: date)
    }
}
