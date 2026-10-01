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
        if graph.catchingUp {
            Log.health("skip overlapping catch-up")
            return true
        }
        graph.catchingUp = true
        defer { graph.catchingUp = false }

        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let start: Date
        if let lastRead = HealthCursor.lastRead(patientId: patientId) {
            start = calendar.startOfDay(for: lastRead)
            Log.health("catch-up since \(HealthDay.sourceId(for: start)) (cursor \(lastRead))")
        } else if let backfill = calendar.date(byAdding: .day, value: -6, to: today) {
            start = backfill
            Log.health("first pull last 7 days (simulator is often zeros)")
        } else {
            start = today
        }

        let samples = try await health.activity(from: start, to: now, calendar: calendar)
        let summary = samples
            .map { "\($0.sourceId) steps=\($0.stepCount) min=\($0.durationMinutes)" }
            .joined(separator: "; ")
        Log.health("got \(samples.count) days: \(summary)")

        try graph.upsert(patientId: patientId, displayName: displayName, samples: samples)
        HealthCursor.markRead(patientId: patientId, at: now)

        do {
            let synced = try await activity.sync(samples)
            try graph.markSynced(patientId: patientId, sourceIds: synced)
            Log.sync("wrote \(synced.count) records")
            return true
        } catch {
            Log.sync("failed (local graph kept, cursor moved): \(error.localizedDescription)")
            return false
        }
    }
}
