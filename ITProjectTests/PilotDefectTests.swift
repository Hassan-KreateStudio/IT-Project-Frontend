import XCTest
#if canImport(ITProject)
@testable import ITProject
#else
@testable import ITLogic
#endif

final class PilotDefectTests: XCTestCase {
    private var nairobi: TimeZone { TimeZone(identifier: "Africa/Nairobi")! }
    private var newYork: TimeZone { TimeZone(identifier: "America/New_York")! }

    private func calendar(in zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, zone: TimeZone) -> Date {
        var parts = DateComponents()
        parts.calendar = calendar(in: zone)
        parts.timeZone = zone
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        parts.minute = minute
        return calendar(in: zone).date(from: parts)!
    }

    // MARK: D1 day keys

    func testNairobiMidnightIsPreviousUTCDayAndOffsetRestoresIt() {
        let zone = nairobi
        let calendar = calendar(in: zone)
        let midnight = DayClock.parseDayKey("2026-11-11", timeZone: zone)!
        XCTAssertEqual(DayClock.bucketedDay(of: midnight, offsetMinutes: 0), "2026-11-10")
        XCTAssertEqual(DayClock.offsetMinutes(at: midnight, timeZone: zone), 180)
        XCTAssertEqual(DayClock.bucketedDay(of: midnight, offsetMinutes: 180), "2026-11-11")

        let noon = DayClock.activityInstant(on: midnight, calendar: calendar)
        XCTAssertEqual(DayClock.bucketedDay(of: noon, offsetMinutes: 0), "2026-11-11")
        XCTAssertEqual(DayClock.bucketedDay(of: noon, offsetMinutes: 180), "2026-11-11")
        XCTAssertEqual(DayClock.dayKey(for: noon, calendar: calendar), "2026-11-11")
    }

    func testDaytimeGlucoseDoesNotShiftWhenActivityMidnightDoes() {
        let slot = APITime.parse("2026-11-11T05:30:00Z")!
        XCTAssertEqual(DayClock.bucketedDay(of: slot, offsetMinutes: 0), "2026-11-11")
        XCTAssertEqual(DayClock.bucketedDay(of: slot, offsetMinutes: 180), "2026-11-11")

        let midnight = DayClock.parseDayKey("2026-11-11", timeZone: nairobi)!
        XCTAssertNotEqual(
            DayClock.bucketedDay(of: midnight, offsetMinutes: 0),
            DayClock.bucketedDay(of: slot, offsetMinutes: 0)
        )
        XCTAssertEqual(
            DayClock.bucketedDay(of: midnight, offsetMinutes: 180),
            DayClock.bucketedDay(of: slot, offsetMinutes: 180)
        )
    }

    func testWestOfUTCMidnightStaysOnTheSameUTCDay() {
        let midnight = DayClock.parseDayKey("2026-11-11", timeZone: newYork)!
        XCTAssertEqual(DayClock.offsetMinutes(at: midnight, timeZone: newYork), -300)
        XCTAssertEqual(DayClock.bucketedDay(of: midnight, offsetMinutes: 0), "2026-11-11")
        XCTAssertEqual(DayClock.bucketedDay(of: midnight, offsetMinutes: -300), "2026-11-11")
    }

    func testDashboardQuerySendsNairobiOffsetAndCoversTheCivilWindow() {
        let zone = nairobi
        let now = date(2026, 11, 11, 5, 48, zone: zone)
        let query = DashboardQuery.patient(days: 30, now: now, calendar: calendar(in: zone))
        XCTAssertEqual(query.offsetMinutes, 180)
        XCTAssertEqual(query.from, "2026-10-12T21:00:00Z")
        XCTAssertEqual(query.to, "2026-11-11T02:48:00Z")
    }

    func testHistoryJoinDoesNotMoveActivityOntoAnotherDay() {
        let paired = HistoryJoin.rows(
            glucose: [HistoryJoin.Glucose(date: "2026-11-11", average: 100, readings: 1)],
            activity: [HistoryJoin.Activity(date: "2026-11-11", steps: 23, minutes: 0)]
        )
        XCTAssertEqual(paired.count, 1)
        XCTAssertEqual(paired[0].steps, 23)
        XCTAssertEqual(paired[0].glucose, 100)

        let split = HistoryJoin.rows(
            glucose: [HistoryJoin.Glucose(date: "2026-11-11", average: 100, readings: 1)],
            activity: [HistoryJoin.Activity(date: "2026-11-10", steps: 23, minutes: 0)]
        )
        XCTAssertEqual(split.map(\.stamp), ["2026-11-10", "2026-11-11"])
        XCTAssertEqual(split[0].steps, 23)
        XCTAssertNil(split[0].glucose)
        XCTAssertEqual(split[1].glucose, 100)
        XCTAssertEqual(split[1].steps, 0)
    }

    func testDatePrefixIsTheCivilDayNotASecondZoneShift() {
        let parsed = DayClock.parseDayKey("2026-11-11T05:30:00Z", timeZone: nairobi)!
        XCTAssertEqual(DayClock.dayKey(for: parsed, calendar: calendar(in: nairobi)), "2026-11-11")
        XCTAssertEqual(APITime.clock(parsed, timeZone: nairobi), "00:00")
    }

    // MARK: D4 timestamps

    func testEncodingAndDisplayApplyTheZoneOnce() {
        let morning = date(2026, 11, 11, 8, 30, zone: nairobi)
        XCTAssertEqual(APITime.encode(morning), "2026-11-11T05:30:00Z")
        XCTAssertEqual(APITime.clock(morning, timeZone: nairobi), "08:30")

        let parsed = APITime.parse(APITime.encode(morning))!
        XCTAssertEqual(APITime.clock(parsed, timeZone: nairobi), "08:30")
        XCTAssertNotEqual(APITime.clock(parsed, timeZone: nairobi), "11:30")
        XCTAssertEqual(APITime.encode(parsed), "2026-11-11T05:30:00Z")

        let storedSlot = APITime.parse("2026-11-11T05:30:00Z")!
        XCTAssertEqual(APITime.clock(storedSlot, timeZone: nairobi), "08:30")
        let afternoon = APITime.parse("2026-11-11T13:30:00Z")!
        let evening = APITime.parse("2026-11-11T19:30:00Z")!
        XCTAssertEqual(APITime.clock(afternoon, timeZone: nairobi), "16:30")
        XCTAssertEqual(APITime.clock(evening, timeZone: nairobi), "22:30")
    }

    func testFractionalTimestampsParseOnceAndBareClocksAreRejected() {
        let parsed = APITime.parse("2026-11-11T05:30:00.000Z")!
        XCTAssertEqual(APITime.clock(parsed, timeZone: nairobi), "08:30")
        XCTAssertNil(APITime.parse("2026-11-11T05:30:00"))
        XCTAssertNil(APITime.parse("05:30"))
    }

    // MARK: D3 counts

    func testHighDayStatAndSentenceShareOneDefinition() {
        let counts = GlucoseWindowCounts(averages: [190, 180, 70, 69, 200])
        XCTAssertEqual(counts.highDays, 2)
        XCTAssertEqual(counts.lowDays, 1)
        XCTAssertEqual(counts.inRangeDays, 2)
        XCTAssertEqual(counts.daysWithReadings, 5)
        XCTAssertEqual(counts.highClause, "2 of 5 days averaged above 180")
        XCTAssertTrue(counts.highSentence.hasPrefix("\(counts.highDays) of "))
        XCTAssertFalse(counts.highSentence.contains("day day"))
        XCTAssertEqual(counts.inRangePercent, 40)
    }

    func testSingleDayPluralDoesNotRepeatTheWord() {
        let one = GlucoseWindowCounts(averages: [208])
        XCTAssertEqual(one.highDays, 1)
        XCTAssertEqual(one.highSentence, "1 of 1 day averaged above 180.")
        XCTAssertFalse(one.highSentence.contains("day day"))
        XCTAssertFalse(one.highSentence.contains("days day"))

        let none = GlucoseWindowCounts(averages: [])
        XCTAssertEqual(none.highDays, 0)
        XCTAssertNil(none.inRangePercent)
        XCTAssertEqual(none.highClause, "No days with a reading")
    }

    func testServerGlucoseTallyIsNotShownAndDayDayIsRepaired() {
        XCTAssertTrue(AlertCopy.isGlucoseTally(code: "HIGH_GLUCOSE", message: "anything"))
        XCTAssertTrue(AlertCopy.isGlucoseTally(
            code: "NOTE",
            message: "3 of 19 days readings above 180"
        ))
        XCTAssertFalse(AlertCopy.isGlucoseTally(code: "LOW_STEPS", message: "Steps were low"))
        XCTAssertEqual(AlertCopy.normalized("High for 1 day day"), "High for 1 day")
        XCTAssertEqual(AlertCopy.normalized("3 days day above the line"), "3 days above the line")
        XCTAssertFalse(AlertCopy.normalized("1 day day").contains("day day"))
    }

    func testReadingPlural() {
        XCTAssertEqual(Plural.readings(0), "0 readings")
        XCTAssertEqual(Plural.readings(1), "1 reading")
        XCTAssertEqual(Plural.readings(3), "3 readings")
        XCTAssertEqual(Plural.days(1), "1 day")
        XCTAssertEqual(Plural.days(2), "2 days")
    }

    // MARK: D2 tips

    func testTipsCiteRealCountsAndNeverMentionMeals() {
        let days = (0 ..< 7).map { index in
            TipDay(
                steps: index == 6 ? 23 : 8_083,
                glucoseMgDl: index == 4 ? 208 : 120,
                isToday: index == 6
            )
        }
        let now = date(2026, 11, 11, 18, 0, zone: nairobi)
        let tips = SummaryTips.make(
            days: days,
            todaySteps: 23,
            todayActiveMinutes: 0,
            now: now,
            calendar: calendar(in: nairobi)
        )
        let text = tips.map { $0.title + " " + $0.detail }.joined(separator: "\n").lowercased()
        XCTAssertFalse(text.contains("meal"))
        XCTAssertFalse(text.contains("lunch"))
        XCTAssertFalse(text.contains("sit-down"))
        XCTAssertFalse(text.contains("three readings"))
        XCTAssertFalse(text.contains("day day"))
        XCTAssertFalse(text.contains("log "))
        XCTAssertFalse(tips.contains { $0.title == "Add an evening reading" })

        let high = tips.first { $0.title.contains("above 180") }
        XCTAssertEqual(high?.title, "1 day averaged above 180")
        XCTAssertTrue(high?.detail.contains("1 of 7 days averaged above 180") == true)
        XCTAssertTrue(high?.detail.contains("208") == true)

        XCTAssertTrue(tips.contains { $0.title == "Walk 15 minutes" && $0.detail.contains("23") })
    }

    func testSingleReadingDoesNotAskForAnother() {
        let thin = SummaryTips.make(
            days: [TipDay(steps: 6_000, glucoseMgDl: 110, isToday: true)],
            todaySteps: 6_000,
            todayActiveMinutes: 20,
            now: date(2026, 11, 11, 10, 0, zone: nairobi),
            calendar: calendar(in: nairobi)
        )
        XCTAssertEqual(thin.first?.title, "Inside range this week")
        XCTAssertFalse(thin.contains { $0.title.localizedCaseInsensitiveContains("log") })
        XCTAssertFalse(thin.contains { $0.title == "Walk 15 minutes" })

        let steady = SummaryTips.make(
            days: [TipDay(steps: 8_000, glucoseMgDl: 110, isToday: true)],
            todaySteps: 8_000,
            todayActiveMinutes: 30,
            now: date(2026, 11, 11, 19, 5, zone: nairobi),
            calendar: calendar(in: nairobi)
        )
        let steadyText = steady.map(\.detail).joined(separator: " ")
        XCTAssertFalse(steady.contains { $0.title.contains("reading") && $0.title != "Inside range this week" })
        XCTAssertTrue(steadyText.contains("1 of 1 day averaged inside 70–180"))
        XCTAssertFalse(steadyText.lowercased().contains("meal"))
    }

    func testEmptyTodayDoesNotAskForAReading() {
        let tips = SummaryTips.make(
            days: [TipDay(steps: 0, glucoseMgDl: nil, isToday: true)],
            todaySteps: 0,
            todayActiveMinutes: 0,
            now: date(2026, 11, 11, 8, 0, zone: nairobi),
            calendar: calendar(in: nairobi)
        )
        XCTAssertTrue(tips.isEmpty)
    }

    // MARK: D6 permission copy

    func testHealthExplanationListsOnlyTheRequestedKinds() throws {
        XCTAssertEqual(HealthAccessCopy.kinds.count, 6)
        let combined = (HealthAccessCopy.inApp + " " + HealthAccessCopy.systemSheet).lowercased()
        for kind in HealthAccessCopy.kinds {
            XCTAssertTrue(HealthAccessCopy.inApp.contains(kind))
            XCTAssertTrue(HealthAccessCopy.systemSheet.contains(kind))
        }
        XCTAssertFalse(combined.contains("stand"))
        XCTAssertFalse(combined.contains("movement"))
        XCTAssertFalse(combined.contains("graph health"))

        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        var plistURL = root.appendingPathComponent("Info.plist")
        for _ in 0 ..< 6 where !FileManager.default.fileExists(atPath: plistURL.path) {
            root.deleteLastPathComponent()
            plistURL = root.appendingPathComponent("Info.plist")
        }
        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        XCTAssertEqual(plist["NSHealthShareUsageDescription"] as? String, HealthAccessCopy.systemSheet)
    }

    // MARK: Token

    func testTokenLeavesUserDefaults() {
        let migrated = TokenBootstrap.decide(keychain: nil, defaults: "legacy-jwt")
        XCTAssertEqual(migrated.token, "legacy-jwt")
        XCTAssertEqual(migrated.writeToKeychain, "legacy-jwt")
        XCTAssertTrue(migrated.clearDefaults)

        let kept = TokenBootstrap.decide(keychain: "keychain-jwt", defaults: "legacy-jwt")
        XCTAssertEqual(kept.token, "keychain-jwt")
        XCTAssertNil(kept.writeToKeychain)
        XCTAssertTrue(kept.clearDefaults)

        let fresh = TokenBootstrap.decide(keychain: "keychain-jwt", defaults: nil)
        XCTAssertEqual(fresh.token, "keychain-jwt")
        XCTAssertFalse(fresh.clearDefaults)

        let loggedOut = TokenBootstrap.decide(keychain: nil, defaults: nil)
        XCTAssertNil(loggedOut.token)
        XCTAssertFalse(loggedOut.clearDefaults)
        XCTAssertNil(loggedOut.writeToKeychain)
    }
}
