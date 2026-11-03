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
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: requestedAt) ?? ISO8601DateFormatter().date(from: requestedAt)
    }
}
