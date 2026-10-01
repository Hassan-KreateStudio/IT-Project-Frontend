import Foundation
import SwiftData
import SwiftUI

struct TodayMetrics: Equatable {
    var steps: Int
    var durationMinutes: Int
    var intensity: String
    var sedentaryMinutes: Int
}

@MainActor
final class GraphStore: ObservableObject {
    let container: ModelContainer
    @Published private(set) var today: TodayMetrics?

    private var context: ModelContext { container.mainContext }

    init(inMemory: Bool = false) {
        let schema = Schema([Person.self, Day.self, DayActivity.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            Log.graph("container failed (\(error.localizedDescription)); using in-memory")
            container = try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }

    func upsert(patientId: String, displayName: String, samples: [HealthDay]) throws {
        let person = try person(patientId: patientId, displayName: displayName)
        for sample in samples {
            let key = Self.dayKey(patientId: patientId, sourceId: sample.sourceId)
            let day = try day(key: key, date: sample.start, person: person)
            if let existing = day.activity {
                existing.sourceId = sample.sourceId
                existing.recordedAt = sample.recordedAt
                existing.stepCount = sample.stepCount
                existing.heartRate = sample.heartRate
                existing.durationMinutes = sample.durationMinutes
                existing.intensity = sample.intensity
                existing.sedentaryMinutes = sample.sedentaryMinutes
                existing.synced = false
            } else {
                let activity = DayActivity(
                    sourceId: sample.sourceId,
                    recordedAt: sample.recordedAt,
                    stepCount: sample.stepCount,
                    heartRate: sample.heartRate,
                    durationMinutes: sample.durationMinutes,
                    intensity: sample.intensity,
                    sedentaryMinutes: sample.sedentaryMinutes
                )
                activity.day = day
                day.activity = activity
                context.insert(activity)
            }
            Log.graph("\(sample.sourceId) steps=\(sample.stepCount) duration=\(sample.durationMinutes) intensity=\(sample.intensity) sedentary=\(sample.sedentaryMinutes)")
        }
        try context.save()
        refreshToday(patientId: patientId)
    }

    func markSynced(patientId: String, sourceIds: [String]) throws {
        for sourceId in sourceIds {
            let key = Self.dayKey(patientId: patientId, sourceId: sourceId)
            var descriptor = FetchDescriptor<Day>(predicate: #Predicate { $0.dayKey == key })
            descriptor.fetchLimit = 1
            if let day = try context.fetch(descriptor).first {
                day.activity?.synced = true
            }
        }
        try context.save()
    }

    func refreshToday(patientId: String) {
        let todayId = HealthDay.sourceId(for: Date())
        let key = Self.dayKey(patientId: patientId, sourceId: todayId)
        var descriptor = FetchDescriptor<Day>(predicate: #Predicate { $0.dayKey == key })
        descriptor.fetchLimit = 1
        let day = try? context.fetch(descriptor).first
        if let activity = day?.activity {
            today = TodayMetrics(
                steps: activity.stepCount,
                durationMinutes: activity.durationMinutes,
                intensity: activity.intensity,
                sedentaryMinutes: activity.sedentaryMinutes
            )
            Log.graph("today \(todayId) steps=\(activity.stepCount) duration=\(activity.durationMinutes)")
        } else {
            today = nil
            Log.graph("no today node yet")
        }
    }

    private func person(patientId: String, displayName: String) throws -> Person {
        var descriptor = FetchDescriptor<Person>(predicate: #Predicate { $0.patientId == patientId })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.displayName = displayName
            return existing
        }
        let person = Person(patientId: patientId, displayName: displayName)
        context.insert(person)
        Log.graph("created person \(patientId)")
        return person
    }

    private func day(key: String, date: Date, person: Person) throws -> Day {
        var descriptor = FetchDescriptor<Day>(predicate: #Predicate { $0.dayKey == key })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.date = date
            existing.person = person
            return existing
        }
        let day = Day(dayKey: key, date: date)
        day.person = person
        context.insert(day)
        return day
    }

    private static func dayKey(patientId: String, sourceId: String) -> String {
        "\(patientId)|\(sourceId)"
    }
}
