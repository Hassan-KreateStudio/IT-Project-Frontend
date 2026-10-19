import Foundation

struct ProfileService {
    var client: GraphQLClient

    func sync(_ profile: HealthProfile) async throws {
        guard profile.hasAny else { return }
        struct Data: Decodable {
            struct Saved: Decodable {
                let ageYears: Int?
                let heightCm: Double?
                let weightKg: Double?
                let bmi: Double?
            }

            let syncProfile: Saved
        }

        var input: [String: Any] = [:]
        if let ageYears = profile.ageYears { input["ageYears"] = ageYears }
        if let heightCm = profile.heightCm { input["heightCm"] = heightCm }
        if let weightKg = profile.weightKg { input["weightKg"] = weightKg }
        if let bmi = profile.bmi { input["bmi"] = bmi }

        let saved: Data = try await client.execute(
            query: """
            mutation($input: PatientProfileInput!) {
              syncProfile(input: $input) {
                ageYears
                heightCm
                weightKg
                bmi
              }
            }
            """,
            variables: ["input": input],
            as: Data.self
        )
        Log.sync(
            "profile age=\(saved.syncProfile.ageYears.map { String($0) } ?? "nil") height=\(saved.syncProfile.heightCm.map { String($0) } ?? "nil")"
        )
    }
}
