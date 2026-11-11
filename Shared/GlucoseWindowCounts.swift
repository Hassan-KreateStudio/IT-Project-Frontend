import Foundation

/// One definition for the glucose card.
///
/// A high day is a day whose average is above 180 mg/dL. A low day is below 70.
/// 180 and 70 themselves are in range. The stat and the sentence both read
/// these counts, so they cannot disagree. The server alert text uses another
/// window ("3 of 19") and a broken plural ("1 day day"); the card does not show it.
struct GlucoseWindowCounts: Equatable {
    static let highMgDl = 180.0
    static let lowMgDl = 70.0

    var daysWithReadings: Int
    var highDays: Int
    var lowDays: Int
    var inRangeDays: Int

    init(averages: [Double]) {
        daysWithReadings = averages.count
        highDays = averages.filter { $0 > Self.highMgDl }.count
        lowDays = averages.filter { $0 < Self.lowMgDl }.count
        inRangeDays = averages.filter { (Self.lowMgDl ... Self.highMgDl).contains($0) }.count
    }

    var inRangePercent: Int? {
        guard daysWithReadings > 0 else { return nil }
        return Int((Double(inRangeDays) / Double(daysWithReadings) * 100).rounded())
    }

    /// "1 of 7 days averaged above 180" — the numerator is `highDays`.
    var highClause: String {
        Self.tally(count: highDays, total: daysWithReadings, tail: "averaged above 180")
    }

    var highSentence: String {
        highClause + "."
    }

    static func tally(count: Int, total: Int, tail: String) -> String {
        if total == 0 { return "No days with a reading" }
        let unit = total == 1 ? "day" : "days"
        return "\(count) of \(total) \(unit) \(tail)"
    }
}

enum Plural {
    static func days(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
    }

    static func readings(_ count: Int) -> String {
        count == 1 ? "1 reading" : "\(count) readings"
    }

    static func minutes(_ count: Int) -> String {
        count == 1 ? "1 minute" : "\(count) minutes"
    }
}

enum AlertCopy {
    /// Server glucose alerts recount a different window from the card stat.
    static func isGlucoseTally(code: String, message: String) -> Bool {
        let code = code.uppercased()
        if code.contains("GLUCOSE") { return true }
        let text = message.lowercased()
        if text.contains("above 180") || text.contains("below 70") { return true }
        if text.contains("mg/dl") && (text.contains("high") || text.contains("low")) { return true }
        return false
    }

    /// "1 day day" and "3 days day" come from a server template that appends
    /// "day" to a word that is already "day" or "days".
    static func normalized(_ message: String) -> String {
        var text = message.replacingOccurrences(of: "days day", with: "days")
        text = text.replacingOccurrences(of: "day day", with: "day")
        return text
    }
}
