import Foundation

/// linkCaregiver, unlinkCaregiver, stopMonitoring, monitoredPatients.
struct CaregiverService {
    var client: GraphQLClient

    func link(email: String) async throws -> User {
        struct Data: Decodable {
            let linkCaregiver: User
        }
        let data: Data = try await client.execute(
            query: """
            mutation($email: String!) {
              linkCaregiver(caregiverEmail: $email) {
                id email displayName role
              }
            }
            """,
            variables: ["email": email],
            as: Data.self
        )
        return data.linkCaregiver
    }

    func unlink(email: String) async throws {
        struct Data: Decodable {
            let unlinkCaregiver: Bool
        }
        let data: Data = try await client.execute(
            query: """
            mutation($email: String!) {
              unlinkCaregiver(caregiverEmail: $email)
            }
            """,
            variables: ["email": email],
            as: Data.self
        )
        if !data.unlinkCaregiver {
            throw GraphQLError(message: "not_found", extensions: GraphQLExtensions(code: "not_found"))
        }
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
}
