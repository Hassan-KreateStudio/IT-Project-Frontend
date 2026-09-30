import Foundation
import HealthKit

/// Reads HealthKit on the phone (Watch → HealthKit → this app). Never talks to Render.
/// Caregivers never call this — they have no Watch graph of their own.
struct HealthKitService {
    private let store = HKHealthStore()
    private static let promptedKey = "itproject.healthkit.prompted"

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var hasPrompted: Bool {
        UserDefaults.standard.bool(forKey: Self.promptedKey)
    }

    func requestAccess() async throws {
        guard Self.isAvailable else { return }
        try await store.requestAuthorization(toShare: Set<HKSampleType>(), read: Self.readTypes)
        UserDefaults.standard.set(true, forKey: Self.promptedKey)
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
