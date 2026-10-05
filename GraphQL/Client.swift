import Foundation

struct GraphQLClient {
    var token: String?

    func execute<T: Decodable>(query: String, variables: [String: Any] = [:], as _: T.Type) async throws -> T {
        var request = URLRequest(url: API.graphql)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: Any] = ["query": query]
        if !variables.isEmpty {
            body["variables"] = variables
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(GraphQLEnvelope<T>.self, from: data)
        if let error = decoded.errors?.first {
            throw error
        }
        guard let value = decoded.data else {
            throw GraphQLError(message: "empty_data", extensions: nil)
        }
        return value
    }
}

struct GraphQLEnvelope<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLError]?
}

struct GraphQLError: Decodable, LocalizedError {
    let message: String
    let extensions: GraphQLExtensions?

    var errorDescription: String? {
        switch extensions?.code ?? message {
        case "invalid_email": return "Enter a valid email."
        case "invalid_display_name": return "First time here — add your name."
        case "invalid_code": return "That code isn’t right."
        case "too_many_attempts": return "Too many tries. Request a new code."
        case "role_conflict": return "This email already belongs to the other role. Go back and pick that one."
        case "email_failed": return "Couldn’t send the email. Try again in a moment."
        case "otp_unavailable": return "Sign-in is down for a minute. Try again shortly."
        case "unauthorized": return "Sign in again."
        case "not_found": return "No caregiver account with that email yet. They sign in as caregiver first — then add them again."
        case "forbidden": return "Only a patient can add a caregiver."
        default: return message
        }
    }
}

struct GraphQLExtensions: Decodable {
    let code: String?
}
