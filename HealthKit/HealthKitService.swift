import Foundation
import HealthKit

struct HealthDay: Sendable {
    let start: Date
    let sourceId: String
    let recordedAt: Date
    let stepCount: Int
    let heartRate: Int?
    let durationMinutes: Int
    let intensity: String
    let sedentaryMinutes: Int

    static func sourceId(for date: Date, calendar: Calendar = .current) -> String {
        let start = calendar.startOfDay(for: date)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return "hk:\(formatter.string(from: start))"
    }
}

/// Reads HealthKit on the phone (Watch → HealthKit → this app). Never talks to Render.
/// Caregivers never call this — they have no Watch graph of their own.
struct HealthKitService {
    private let store = HKHealthStore()
    private static let promptedKey = "itproject.healthkit.prompted"
    private static let wakingMinutes = 960

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var hasPrompted: Bool {
        UserDefaults.standard.bool(forKey: Self.promptedKey)
    }

    func requestAccess() async throws {
        guard Self.isAvailable else { return }
        Log.health("requesting read access")
        try await store.requestAuthorization(toShare: Set<HKSampleType>(), read: Self.readTypes)
        UserDefaults.standard.set(true, forKey: Self.promptedKey)
        Log.health("permission sheet finished (prompted=true even if samples are empty)")
    }

    func weekActivity(now: Date = Date(), calendar: Calendar = .current) async throws -> [HealthDay] {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -6, to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today)
        else {
            return []
        }
        Log.health("query \(HealthDay.sourceId(for: start)) .. \(HealthDay.sourceId(for: today))")

        let steps = try await dailyTotals(identifier: .stepCount, options: .cumulativeSum, unit: .count(), start: start, end: end)
        let exercise = try await dailyTotals(
            identifier: .appleExerciseTime,
            options: .cumulativeSum,
            unit: .minute(),
            start: start,
            end: end
        )
        let heart = try await dailyTotals(
            identifier: .heartRate,
            options: .discreteAverage,
            unit: HKUnit.count().unitDivided(by: .minute()),
            start: start,
            end: end
        )

        return (0 ..< 7).compactMap { offset -> HealthDay? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let stepCount = Int((steps[day] ?? 0).rounded())
            let durationMinutes = Int((exercise[day] ?? 0).rounded())
            let heartRate: Int? = heart[day].map { Int($0.rounded()) }
            let intensity = durationMinutes > 0 ? "MODERATE" : "LIGHT"
            return HealthDay(
                start: day,
                sourceId: HealthDay.sourceId(for: day, calendar: calendar),
                recordedAt: day,
                stepCount: stepCount,
                heartRate: heartRate,
                durationMinutes: durationMinutes,
                intensity: intensity,
                sedentaryMinutes: max(0, Self.wakingMinutes - durationMinutes)
            )
        }
    }

    private func dailyTotals(
        identifier: HKQuantityTypeIdentifier,
        options: HKStatisticsOptions,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async throws -> [Date: Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            Log.health("missing type \(identifier.rawValue)")
            return [:]
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: start,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, collection, error in
                if let error {
                    Log.health("\(identifier.rawValue) failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                var map: [Date: Double] = [:]
                collection?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let quantity: HKQuantity?
                    if options.contains(.cumulativeSum) {
                        quantity = statistics.sumQuantity()
                    } else {
                        quantity = statistics.averageQuantity()
                    }
                    if let quantity {
                        map[statistics.startDate] = quantity.doubleValue(for: unit)
                    }
                }
                Log.health("\(identifier.rawValue) days with values=\(map.count)")
                continuation.resume(returning: map)
            }
            store.execute(query)
        }
    }

    private static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let heart = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heart)
        }
        if let exercise = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exercise)
        }
        if let stand = HKQuantityType.quantityType(forIdentifier: .appleStandTime) {
            types.insert(stand)
        }
        return types
    }
}
