import Foundation

struct TipDay: Equatable {
    var steps: Int
    var glucoseMgDl: Double?
    var readingCount: Int
    var isToday: Bool
}

struct SummaryTip: Equatable, Identifiable {
    var symbol: String
    var title: String
    var detail: String
    var id: String { title + "\n" + detail }
}

/// "What to try next", from the week actually loaded.
///
/// Meals are never recorded, so a tip cannot mention a meal, lunch, or a
/// sit-down cause. Each line cites a count the app has: high days, readings, or steps.
enum SummaryTips {
    static let quietStepCount = 2_000
    static let afternoonHour = 11

    static func make(
        days: [TipDay],
        todaySteps: Int,
        todayActiveMinutes: Int,
        latestAt: Date?,
        now: Date,
        calendar: Calendar
    ) -> [SummaryTip] {
        var tips: [SummaryTip] = []
        let counts = GlucoseWindowCounts(averages: days.compactMap(\.glucoseMgDl))
        let today = days.last { $0.isToday }
        let serverReadings = today?.readingCount ?? 0
        let todayReadings = max(serverReadings, latestAt == nil ? 0 : 1)
        let hour = calendar.component(.hour, from: now)

        if todayReadings == 0 {
            tips.append(SummaryTip(
                symbol: "drop.fill",
                title: "Log today's glucose",
                detail: "Nothing is logged for today yet."
            ))
        } else if todayReadings == 1 {
            let when = latestAt.map { " at \(APITime.clock($0, timeZone: calendar.timeZone))" } ?? ""
            if hour >= 17 {
                tips.append(SummaryTip(
                    symbol: "moon.fill",
                    title: "Add an evening reading",
                    detail: "Today has \(Plural.readings(todayReadings))\(when)."
                ))
            } else {
                tips.append(SummaryTip(
                    symbol: "heart.fill",
                    title: "Log another reading later",
                    detail: "Today has \(Plural.readings(todayReadings))\(when). That one number is the whole day so far."
                ))
            }
        }

        if counts.highDays > 0, let highest = days.compactMap(\.glucoseMgDl).max() {
            tips.append(SummaryTip(
                symbol: "bolt.fill",
                title: "\(Plural.days(counts.highDays)) averaged above 180",
                detail: "\(counts.highSentence) Highest average \(Int(highest.rounded())) mg/dL."
            ))
        }

        if todaySteps < quietStepCount && hour >= afternoonHour && tips.count < 3 {
            tips.append(SummaryTip(
                symbol: "figure.walk",
                title: "Walk 15 minutes",
                detail: "Today is at \(grouped(todaySteps)) steps and \(Plural.minutes(todayActiveMinutes)) of exercise."
            ))
        }

        if tips.isEmpty, counts.daysWithReadings > 0 {
            let unit = counts.daysWithReadings == 1 ? "day" : "days"
            tips.append(SummaryTip(
                symbol: "heart.fill",
                title: "Inside range this week",
                detail: "\(counts.inRangeDays) of \(counts.daysWithReadings) \(unit) averaged inside 70–180."
            ))
        }

        return Array(tips.prefix(3))
    }

    static func grouped(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
