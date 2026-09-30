import Foundation

struct AuthPayload: Codable {
    let token: String
    let user: User
}

struct AuthService {
    var client: GraphQLClient

    func register(email: String, password: String, displayName: String, role: String) async throws -> AuthPayload {
        struct Data: Decodable {
            let register: AuthPayload
        }
        let data: Data = try await client.execute(
            query: """
            mutation($email: String!, $password: String!, $displayName: String!, $role: Role!) {
              register(email: $email, password: $password, displayName: $displayName, role: $role) {
                token
                user { id email displayName role }
              }
            }
            """,
            variables: [
                "email": email,
                "password": password,
                "displayName": displayName,
                "role": role
            ],
            as: Data.self
        )
        return data.register
    }

    func login(email: String, password: String) async throws -> AuthPayload {
        struct Data: Decodable {
            let login: AuthPayload
        }
        let data: Data = try await client.execute(
            query: """
            mutation($email: String!, $password: String!) {
              login(email: $email, password: $password) {
                token
                user { id email displayName role }
              }
            }
            """,
            variables: ["email": email, "password": password],
            as: Data.self
        )
        return data.login
    }
}
