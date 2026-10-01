import Foundation

/// syncActivity. HealthKit mapping lives in HealthKit/, not here.
struct ActivityService {
    var client: GraphQLClient

    func sync(_ samples: [HealthDay]) async throws -> [String] {
        struct Data: Decodable {
            struct Record: Decodable {
                let sourceId: String
            }

            let syncActivity: [Record]
        }

        let records: [[String: Any]] = samples.map { sample in
            var row: [String: Any] = [
                "sourceId": sample.sourceId,
                "recordedAt": Self.encode(sample.recordedAt),
                "stepCount": sample.stepCount,
                "durationMinutes": sample.durationMinutes,
                "intensity": sample.intensity,
                "sedentaryMinutes": sample.sedentaryMinutes
            ]
            if let heartRate = sample.heartRate {
                row["heartRate"] = heartRate
            }
            return row
        }
        Log.sync("POST \(samples.count) days")
        let data: Data = try await client.execute(
            query: """
            mutation($records: [ActivityRecordInput!]!) {
              syncActivity(records: $records) {
                sourceId
                stepCount
                durationMinutes
              }
            }
            """,
            variables: ["records": records],
            as: Data.self
        )
        return data.syncActivity.map(\.sourceId)
    }

    private static func encode(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
