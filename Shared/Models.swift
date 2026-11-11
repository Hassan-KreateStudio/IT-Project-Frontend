import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let displayName: String
    let role: String
    /// Set on monitoredPatients/caregivers: when access was granted.
    var since: Date?
}

/// One pending caregiver ask, as the patient sees it. The timestamp stays a
/// string: GraphQLClient decodes with a plain JSONDecoder.
struct CaregiverRequest: Codable, Identifiable {
    var id: String { caregiver.id }
    let caregiver: User
    let requestedAt: String

    var askedAt: Date? {
        APITime.parse(requestedAt)
    }
}

/// The `dashboard` / `patientDashboard` payload. Both summary screens use it.
struct DashboardSnapshot: Decodable {
    struct Summary: Decodable {
        var totalSteps: Int
        var averageGlucose: Double?
        var glucoseReadingCount: Int
        var totalActiveMinutes: Int
    }

    struct GlucoseTrend: Decodable {
        var date: String
        var averageValue: Double
        var readingCount: Int
    }

    struct ActivityTrend: Decodable {
        var date: String
        var stepCount: Int
        var durationMinutes: Int
    }

    struct Alert: Decodable {
        var code: String
        var message: String
        var severity: String
    }

    var summary: Summary
    var glucoseTrends: [GlucoseTrend]
    var activityTrends: [ActivityTrend]
    var alerts: [Alert]
}
