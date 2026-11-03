import Foundation

/// requestAccess, respond, revoke, stopMonitoring, lists, dashboard.
struct CaregiverService {
    var client: GraphQLClient

    /// Asks a patient to share. Creates a request only — no access until they accept.
    func requestAccess(email: String) async throws -> User {
        struct Data: Decodable {
            let requestAccess: User
        }
        let data: Data = try await client.execute(
            query: """
            mutation($email: String!) {
              requestAccess(patientEmail: $email) {
                id email displayName role
              }
            }
            """,
            variables: ["email": email],
            as: Data.self
        )
        return data.requestAccess
    }

    /// Patients this caregiver has asked and who have not answered yet.
    func pendingPatients() async throws -> [User] {
        struct Data: Decodable {
            let pendingPatients: [User]
        }
        let data: Data = try await client.execute(
            query: "{ pendingPatients { id email displayName role } }",
            as: Data.self
        )
        return data.pendingPatients
    }

    /// Patient side: caregivers waiting on an answer.
    func caregiverRequests() async throws -> [CaregiverRequest] {
        struct Data: Decodable {
            let caregiverRequests: [CaregiverRequest]
        }
        let data: Data = try await client.execute(
            query: """
            {
              caregiverRequests {
                requestedAt
                caregiver { id email displayName role }
              }
            }
            """,
            as: Data.self
        )
        return data.caregiverRequests
    }

    func respond(caregiverId: String, accept: Bool) async throws {
        struct Data: Decodable {
            let respondToRequest: Bool
        }
        let _: Data = try await client.execute(
            query: """
            mutation($caregiverId: ID!, $accept: Boolean!) {
              respondToRequest(caregiverId: $caregiverId, accept: $accept)
            }
            """,
            variables: ["caregiverId": caregiverId, "accept": accept],
            as: Data.self
        )
    }

    /// Patient side: cut an accepted caregiver off.
    func revoke(caregiverId: String) async throws {
        struct Data: Decodable {
            let revokeCaregiver: Bool
        }
        let _: Data = try await client.execute(
            query: """
            mutation($caregiverId: ID!) {
              revokeCaregiver(caregiverId: $caregiverId)
            }
            """,
            variables: ["caregiverId": caregiverId],
            as: Data.self
        )
    }

    func stopMonitoring(patientId: String) async throws {
        struct Data: Decodable {
            let stopMonitoring: Bool
        }
        let data: Data = try await client.execute(
            query: """
            mutation($patientId: ID!) {
              stopMonitoring(patientId: $patientId)
            }
            """,
            variables: ["patientId": patientId],
            as: Data.self
        )
        if !data.stopMonitoring {
            throw GraphQLError(message: "not_found", extensions: GraphQLExtensions(code: "not_found"))
        }
    }

    func monitoredPatients() async throws -> [User] {
        struct Data: Decodable {
            let monitoredPatients: [User]
        }
        let data: Data = try await client.execute(
            query: "{ monitoredPatients { id email displayName role } }",
            as: Data.self
        )
        return data.monitoredPatients
    }

    func caregivers() async throws -> [User] {
        struct Data: Decodable {
            let caregivers: [User]
        }
        let data: Data = try await client.execute(
            query: "{ caregivers { id email displayName role } }",
            as: Data.self
        )
        return data.caregivers
    }

    /// Seven-day dashboard for one monitored patient. Alerts carry no timestamp
    /// on the server, so the date lives in the message text.
    func dashboard(patientId: String, days: Int = 7) async throws -> DashboardSnapshot {
        struct Data: Decodable {
            let patientDashboard: DashboardSnapshot
        }

        let to = Date()
        let from = Calendar.current.date(byAdding: .day, value: -(days - 1), to: to) ?? to
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let data: Data = try await client.execute(
            query: """
            query($patientId: ID!, $from: Time, $to: Time) {
              patientDashboard(patientId: $patientId, from: $from, to: $to) {
                summary { totalSteps averageGlucose glucoseReadingCount totalActiveMinutes }
                glucoseTrends { date averageValue readingCount }
                activityTrends { date stepCount durationMinutes }
                alerts { code message severity }
              }
            }
            """,
            variables: [
                "patientId": patientId,
                "from": formatter.string(from: from),
                "to": formatter.string(from: to)
            ],
            as: Data.self
        )
        return data.patientDashboard
    }
}

