import Foundation
import HealthKit
import WatchConnectivity

/// Whether a Watch is attached to this phone and actually feeding HealthKit.
///
/// HealthKit is asked first: a Watch-sourced sample is evidence the Watch is
/// alive, while `isPaired` only says one was once paired. Pairing is the
/// fallback, and it can only be believed after the session finishes activating.
enum WatchLink {
    enum State {
        case connected
        case paired
        case absent
    }

    static func current() async -> State {
        // Data beats metadata: if the Watch wrote recently it is connected,
        // whatever WatchConnectivity thinks.
        if await wroteRecently() { return .connected }

        guard WCSession.isSupported() else { return .absent }

        let session = WCSession.default
        if session.activationState != .activated {
            session.delegate = WatchActivationWaiter.shared
            session.activate()
            // `isPaired` is meaningless until activation lands.
            await WatchActivationWaiter.shared.wait()
        }
        return session.isPaired ? .paired : .absent
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

/// Bridges WCSession activation to async, with a deadline so a session that
/// never calls back cannot stall the badge.
final class WatchActivationWaiter: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchActivationWaiter()

    private let lock = NSLock()
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var settled = false

    func wait(timeout: TimeInterval = 2) async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if settled {
                lock.unlock()
                continuation.resume()
                return
            }
            continuations.append(continuation)
            lock.unlock()

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
                self?.settle()
            }
        }
    }

    private func settle() {
        lock.lock()
        guard !settled else {
            lock.unlock()
            return
        }
        settled = true
        let pending = continuations
        continuations.removeAll()
        lock.unlock()

        pending.forEach { $0.resume() }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .watchLinkSettled, object: nil)
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        settle()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // The Watch changed; re-activate so the next read is accurate.
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .watchLinkSettled, object: nil)
        }
    }
}

extension Notification.Name {
    static let watchLinkSettled = Notification.Name("itproject.watchLinkSettled")
}
