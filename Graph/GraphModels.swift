import Foundation
import SwiftData

@Model
final class Person {
    @Attribute(.unique) var patientId: String
    var displayName: String
    @Relationship(deleteRule: .cascade, inverse: \Day.person)
    var days: [Day] = []

    init(patientId: String, displayName: String) {
        self.patientId = patientId
        self.displayName = displayName
        self.days = []
    }
}

@Model
final class Day {
    @Attribute(.unique) var dayKey: String
    var date: Date
    var person: Person?
    @Relationship(deleteRule: .cascade, inverse: \DayActivity.day)
    var activity: DayActivity?

    init(dayKey: String, date: Date) {
        self.dayKey = dayKey
        self.date = date
    }
}

@Model
final class DayActivity {
    var sourceId: String
    var recordedAt: Date
    var stepCount: Int
    var heartRate: Int?
    var durationMinutes: Int
    var intensity: String
    var sedentaryMinutes: Int
    var synced: Bool
    var day: Day?

    init(
        sourceId: String,
        recordedAt: Date,
        stepCount: Int,
        heartRate: Int?,
        durationMinutes: Int,
        intensity: String,
        sedentaryMinutes: Int,
        synced: Bool = false
    ) {
        self.sourceId = sourceId
        self.recordedAt = recordedAt
        self.stepCount = stepCount
        self.heartRate = heartRate
        self.durationMinutes = durationMinutes
        self.intensity = intensity
        self.sedentaryMinutes = sedentaryMinutes
        self.synced = synced
    }
}
