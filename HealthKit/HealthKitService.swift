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

    func ensureReadAccess() async {
        guard Self.isAvailable else { return }
        try? await store.requestAuthorization(toShare: Set<HKSampleType>(), read: Self.readTypes)
    }

    func activity(from start: Date, to now: Date = Date(), calendar: Calendar = .current) async throws -> [HealthDay] {
        let fromDay = calendar.startOfDay(for: start)
        let today = calendar.startOfDay(for: now)
        guard fromDay <= today,
              let end = calendar.date(byAdding: .day, value: 1, to: today)
        else {
            return []
        }
        let dayCount = (calendar.dateComponents([.day], from: fromDay, to: today).day ?? 0) + 1
        Log.health("query \(HealthDay.sourceId(for: fromDay)) .. \(HealthDay.sourceId(for: today)) (\(dayCount) days)")

        let steps = try await dailyTotals(identifier: .stepCount, options: .cumulativeSum, unit: .count(), start: fromDay, end: end)
        let exercise = try await dailyTotals(
            identifier: .appleExerciseTime,
            options: .cumulativeSum,
            unit: .minute(),
            start: fromDay,
            end: end
        )
        let heart = try await dailyTotals(
            identifier: .heartRate,
            options: .discreteAverage,
            unit: HKUnit.count().unitDivided(by: .minute()),
            start: fromDay,
            end: end
        )

        return (0 ..< dayCount).compactMap { offset -> HealthDay? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: fromDay) else { return nil }
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
        if let dob = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) {
            types.insert(dob)
        }
        if let height = HKQuantityType.quantityType(forIdentifier: .height) {
            types.insert(height)
        }
        if let weight = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.insert(weight)
        }
        if let bmi = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) {
            types.insert(bmi)
        }
        return types
    }

    func profile() async -> HealthProfile {
        let ageYears = Self.ageYears(from: try? store.dateOfBirthComponents())
        let heightCm = await latestQuantity(.height, unit: .meterUnit(with: .centi))
        let weightKg = await latestQuantity(.bodyMass, unit: .gramUnit(with: .kilo))
        let bmi = await latestQuantity(.bodyMassIndex, unit: .count())
        Log.health(
            "profile age=\(ageYears.map { String($0) } ?? "nil") heightCm=\(heightCm.map { String($0) } ?? "nil") weightKg=\(weightKg.map { String($0) } ?? "nil") bmi=\(bmi.map { String($0) } ?? "nil")"
        )
        return HealthProfile(ageYears: ageYears, heightCm: heightCm, weightKg: weightKg, bmi: bmi)
    }

    private func latestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    Log.health("\(identifier.rawValue) latest failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                let sample = samples?.first as? HKQuantitySample
                continuation.resume(returning: sample?.quantity.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private static func ageYears(from components: DateComponents?) -> Int? {
        guard let components, let birth = Calendar.current.date(from: components) else {
            return nil
        }
        let years = Calendar.current.dateComponents([.year], from: birth, to: Date()).year
        guard let years, years >= 1 else { return nil }
        return years
    }
}

struct HealthProfile: Sendable {
    var ageYears: Int?
    var heightCm: Double?
    var weightKg: Double?
    var bmi: Double?

    var hasAny: Bool {
        ageYears != nil || heightCm != nil || weightKg != nil || bmi != nil
    }
}
