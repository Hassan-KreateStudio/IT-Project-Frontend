import Foundation

enum GlucoseRange {
    /// Abbott FreeStyle Libre / Dexcom reportable window, used by ShanghaiT2DM CGM values.
    static let minMgDl: Double = 40
    static let maxMgDl: Double = 400
}

struct GlucoseService {
    var client: GraphQLClient

    func add(value: Double, recordedAt: Date) async throws {
        struct Data: Decodable {
            struct Reading: Decodable {
                let value: Double
            }

            let addGlucose: Reading
        }

        let saved: Data = try await client.execute(
            query: """
            mutation($value: Float!, $recordedAt: Time!) {
              addGlucose(value: $value, recordedAt: $recordedAt) {
                id
                value
                recordedAt
              }
            }
            """,
            variables: [
                "value": value,
                "recordedAt": Self.encode(recordedAt)
            ],
            as: Data.self
        )
        Log.sync("glucose \(saved.addGlucose.value) mg/dL")
    }

    private static func encode(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
