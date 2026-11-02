import Foundation

enum HealthCursor {
    static func lastRead(patientId: String) -> Date? {
        UserDefaults.standard.object(forKey: key(patientId)) as? Date
    }

    static func markRead(patientId: String, at date: Date = Date()) {
        UserDefaults.standard.set(date, forKey: key(patientId))
        Log.graph("health cursor \(patientId.prefix(8))… → \(date)")
    }

    private static func key(_ patientId: String) -> String {
        // v2: the 90-day backfill re-runs once on installs that already synced the old 7.
        "itproject.health.lastRead.v2.\(patientId)"
    }
}
