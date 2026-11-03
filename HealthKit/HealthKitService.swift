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
    private static let profilePromptedKey = "itproject.healthkit.profile.prompted"
    private static let wakingMinutes = 960

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var hasPrompted: Bool {
        UserDefaults.standard.bool(forKey: Self.promptedKey)
    }

    var hasPromptedProfile: Bool {
        UserDefaults.standard.bool(forKey: Self.profilePromptedKey)
    }

    /// First Allow: activity + date of birth, height, and weight in one Health sheet.
    @MainActor
    func requestAccess() async throws {
        guard Self.isAvailable else { return }
        Log.health("requesting read access (activity + age/height/weight)")
        try await store.requestAuthorization(toShare: Set<HKSampleType>(), read: Self.readTypes)
        UserDefaults.standard.set(true, forKey: Self.promptedKey)
        UserDefaults.standard.set(true, forKey: Self.profilePromptedKey)
        Log.health("permission sheet finished (prompted=true even if samples are empty)")
    }

    /// Later installs already allowed steps: ask only for the three profile types, once.
    @MainActor
    func requestProfileAccessIfNeeded() async {
        guard Self.isAvailable, !hasPromptedProfile else { return }
        Log.health("requesting date of birth, height, weight")
        try? await store.requestAuthorization(toShare: Set<HKSampleType>(), read: Self.profileTypes)
        UserDefaults.standard.set(true, forKey: Self.profilePromptedKey)
        Log.health("profile permission sheet finished")
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


    /// Today's numbers as the Watch itself counted them, so the cards match the
    /// watch face. Display only — WeekIngest still syncs the merged totals.
    /// Returns nil when no Watch source has written recently, so the caller
    /// falls back to the merged day.
    func watchDay(for day: Date = Date(), calendar: Calendar = .current) async -> HealthDay? {
        let sources = await watchSources()
        guard !sources.isEmpty else { return nil }

        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }

        let stepCount = Int((await watchTotal(.stepCount, options: [.cumulativeSum, .separateBySource], unit: .count(), start: start, end: end, sources: sources)).rounded())
        let durationMinutes = Int((await watchTotal(.appleExerciseTime, options: [.cumulativeSum, .separateBySource], unit: .minute(), start: start, end: end, sources: sources)).rounded())
        let heart = await watchTotal(.heartRate, options: [.discreteAverage, .separateBySource], unit: HKUnit.count().unitDivided(by: .minute()), start: start, end: end, sources: sources)
        let heartRate: Int? = heart > 0 ? Int(heart.rounded()) : nil

        guard stepCount > 0 || durationMinutes > 0 || heartRate != nil else { return nil }

        Log.health("watch day steps=\(stepCount) min=\(durationMinutes) hr=\(heartRate.map(String.init) ?? "nil")")
        return HealthDay(
            start: start,
            sourceId: HealthDay.sourceId(for: start, calendar: calendar),
            recordedAt: start,
            stepCount: stepCount,
            heartRate: heartRate,
            durationMinutes: durationMinutes,
            intensity: durationMinutes > 0 ? "MODERATE" : "LIGHT",
            sedentaryMinutes: max(0, Self.wakingMinutes - durationMinutes)
        )
    }

    /// Which HealthKit sources are watchOS devices. productType is the only
    /// stable signal (name and bundle id are not documented).
    private func watchSources() async -> Set<HKSource> {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }
        let since = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 100, sortDescriptors: [sort]) { _, samples, _ in
                var sources = Set<HKSource>()
                for case let sample as HKSample in samples ?? [] {
                    if sample.sourceRevision.productType?.localizedCaseInsensitiveContains("watch") == true {
                        sources.insert(sample.sourceRevision.source)
                    }
                }
                continuation.resume(returning: sources)
            }
            store.execute(query)
        }
    }

    /// Sums (or averages) one day's statistics over the given sources only.
    /// `.separateBySource` is required — without it `sources` comes back nil.
    private func watchTotal(
        _ identifier: HKQuantityTypeIdentifier,
        options: HKStatisticsOptions,
        unit: HKUnit,
        start: Date,
        end: Date,
        sources: Set<HKSource>
    ) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: options) { _, statistics, _ in
                guard let statistics else {
                    continuation.resume(returning: 0)
                    return
                }
                var total = 0.0
                for source in statistics.sources ?? [] where sources.contains(source) {
                    let quantity = options.contains(.cumulativeSum)
                        ? statistics.sumQuantity(for: source)
                        : statistics.averageQuantity(for: source)
                    total += quantity?.doubleValue(for: unit) ?? 0
                }
                continuation.resume(returning: total)
            }
            store.execute(query)
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

    private static var profileTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let dob = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) {
            types.insert(dob)
        }
        if let height = HKQuantityType.quantityType(forIdentifier: .height) {
            types.insert(height)
        }
        if let weight = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.insert(weight)
        }
        return types
    }

    private static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = profileTypes
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
