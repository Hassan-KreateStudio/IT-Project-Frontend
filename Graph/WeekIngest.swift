import Foundation

enum WeekIngest {
    @MainActor
    static func run(
        patientId: String,
        displayName: String,
        health: HealthKitService,
        graph: GraphStore,
        activity: ActivityService
    ) async throws -> Bool {
        Log.health("pulling last 7 days (simulator is often zeros)")
        let samples = try await health.weekActivity()
        let summary = samples
            .map { "\($0.sourceId) steps=\($0.stepCount) min=\($0.durationMinutes)" }
            .joined(separator: "; ")
        Log.health("got \(samples.count) days: \(summary)")

        try graph.upsert(patientId: patientId, displayName: displayName, samples: samples)

        do {
            let synced = try await activity.sync(samples)
            try graph.markSynced(patientId: patientId, sourceIds: synced)
            Log.sync("wrote \(synced.count) records")
            return true
        } catch {
            Log.sync("failed (local week kept): \(error.localizedDescription)")
            return false
        }
    }
}
