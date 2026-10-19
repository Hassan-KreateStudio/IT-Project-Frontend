import Foundation

/// linkPatient, stopMonitoring, monitoredPatients, caregivers.
struct CaregiverService {
    var client: GraphQLClient

    func linkPatient(email: String) async throws -> User {
        struct Data: Decodable {
            let linkPatient: User
        }
        let data: Data = try await client.execute(
            query: """
            mutation($email: String!) {
              linkPatient(patientEmail: $email) {
                id email displayName role
              }
            }
            """,
            variables: ["email": email],
            as: Data.self
        )
        return data.linkPatient
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
}
