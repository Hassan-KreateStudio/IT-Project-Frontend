import Foundation

struct AuthPayload: Codable {
    let token: String
    let user: User
}

struct AuthCodePayload: Codable {
    let sent: Bool
    let debugCode: String?
}

struct AuthService {
    var client: GraphQLClient

    func requestAuthCode(email: String, role: String, displayName: String) async throws -> AuthCodePayload {
        struct Data: Decodable {
            let requestAuthCode: AuthCodePayload
        }
        var variables: [String: Any] = [
            "email": email,
            "role": role
        ]
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            variables["displayName"] = NSNull()
        } else {
            variables["displayName"] = name
        }
        let data: Data = try await client.execute(
            query: """
            mutation($email: String!, $role: Role!, $displayName: String) {
              requestAuthCode(email: $email, role: $role, displayName: $displayName) {
                sent
                debugCode
              }
            }
            """,
            variables: variables,
            as: Data.self
        )
        return data.requestAuthCode
    }

    func verifyAuthCode(email: String, code: String) async throws -> AuthPayload {
        struct Data: Decodable {
            let verifyAuthCode: AuthPayload
        }
        let data: Data = try await client.execute(
            query: """
            mutation($email: String!, $code: String!) {
              verifyAuthCode(email: $email, code: $code) {
                token
                user { id email displayName role }
              }
            }
            """,
            variables: ["email": email, "code": code],
            as: Data.self
        )
        return data.verifyAuthCode
    }
}
