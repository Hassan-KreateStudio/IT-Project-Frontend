import Foundation
import HealthKit
import WatchConnectivity

/// Whether a Watch is attached to this phone and actually feeding HealthKit.
/// Pairing alone says nothing about data, so the "connected" state also requires
/// a Watch-sourced heart-rate sample from the last day.
enum WatchLink {
    enum State {
        case connected
        case paired
        case absent
    }

    static func current() async -> State {
        guard WCSession.isSupported() else { return .absent }
        let session = WCSession.default
        if session.activationState != .activated {
            session.activate()
            // Activation is async and isPaired is meaningless before it lands.
            try? await Task.sleep(for: .milliseconds(500))
        }
        guard session.isPaired else { return .absent }
        return await wroteRecently() ? .connected : .paired
    }

    private static func wroteRecently() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKQuantityType.quantityType(forIdentifier: .heartRate)
        else { return false }

        let store = HKHealthStore()
        let since = Date().addingTimeInterval(-24 * 60 * 60)
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: false)
                    return
                }
                let device = sample.device?.name ?? sample.device?.model ?? ""
                continuation.resume(returning: device.localizedCaseInsensitiveContains("watch"))
            }
            store.execute(query)
        }
    }
}
