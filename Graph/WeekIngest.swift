import Foundation

enum WeekIngest {
    /// First pull on a fresh install. HealthKit lets us ask for as much as it has.
    static let backfillDays = 90

    @MainActor
    static func run(
        patientId: String,
        displayName: String,
        health: HealthKitService,
        graph: GraphStore,
        activity: ActivityService,
        profile: ProfileService,
        report: (String) -> Void = { _ in }
    ) async throws -> Bool {
        if graph.catchingUp {
            Log.health("skip overlapping catch-up")
            return true
        }
        graph.catchingUp = true
        defer { graph.catchingUp = false }

        await health.requestProfileAccessIfNeeded()

        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let start: Date
        if let lastRead = HealthCursor.lastRead(patientId: patientId) {
            start = calendar.startOfDay(for: lastRead)
            Log.health("catch-up since \(HealthDay.sourceId(for: start)) (cursor \(lastRead))")
        } else if let backfill = calendar.date(byAdding: .day, value: -(Self.backfillDays - 1), to: today) {
            start = backfill
            Log.health("first pull last \(Self.backfillDays) days")
        } else {
            start = today
        }

        report("Reading from \(HealthDay.sourceId(for: start))")
        let samples = try await health.activity(from: start, to: now, calendar: calendar)
        report("Read \(samples.count) days from Health")
        let summary = samples
            .map { "\($0.sourceId) steps=\($0.stepCount) min=\($0.durationMinutes)" }
            .joined(separator: "; ")
        Log.health("got \(samples.count) days: \(summary)")

        try graph.upsert(patientId: patientId, displayName: displayName, samples: samples)
        report("Saved \(samples.count) days on this phone")
        HealthCursor.markRead(patientId: patientId, at: now)

        let traits = await health.profile()
        do {
            try await profile.sync(traits)
        } catch {
            Log.sync("profile failed: \(error.localizedDescription)")
        }

        report("Sending \(samples.count) days to the server")
        do {
            let synced = try await activity.sync(samples)
            try graph.markSynced(patientId: patientId, sourceIds: synced)
            report("Server accepted \(synced.count) days")
            Log.sync("wrote \(synced.count) records")
            return true
        } catch {
            Log.sync("failed (local graph kept, cursor moved): \(error.localizedDescription)")
            return false
        }
    }
}
