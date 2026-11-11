import Foundation
import SwiftData
import SwiftUI

struct TodayMetrics: Equatable {
    var steps: Int
    var heartRate: Int?
    var durationMinutes: Int
    var intensity: String
    var sedentaryMinutes: Int
    var glucose: Double?
}

struct WeekPoint: Identifiable, Equatable {
    var id: Date { date }
    var date: Date
    var steps: Int
    var glucose: Double?
}

@MainActor
final class GraphStore: ObservableObject {
    let container: ModelContainer
    @Published private(set) var today: TodayMetrics?
    @Published var catchingUp = false

    private var context: ModelContext { container.mainContext }

    init(inMemory: Bool = false) {
        let schema = Schema([Person.self, Day.self, DayActivity.self, DayGlucose.self])
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
        let day = todayDay(patientId: patientId)
        if let activity = day?.activity {
            today = TodayMetrics(
                steps: activity.stepCount,
                heartRate: activity.heartRate,
                durationMinutes: activity.durationMinutes,
                intensity: activity.intensity,
                sedentaryMinutes: activity.sedentaryMinutes,
                glucose: nil
            )
            Log.graph("today \(todayId) steps=\(activity.stepCount) hr=\(activity.heartRate.map(String.init) ?? "—") duration=\(activity.durationMinutes) intensity=\(activity.intensity) sedentary=\(activity.sedentaryMinutes)")
        } else {
            today = nil
            Log.graph("no today activity yet")
        }
    }

    /// Last `days` calendar days for one patient, oldest first. Days with no
    /// activity still appear so the chart keeps an even time axis.
    func week(patientId: String, days: Int = 7, now: Date = Date()) -> [WeekPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        let descriptor = FetchDescriptor<Day>(
            predicate: #Predicate<Day> { $0.date >= start },
            sortBy: [SortDescriptor(\.date)]
        )
        let stored = (try? context.fetch(descriptor)) ?? []

        return (0 ..< days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let day = stored.first {
                $0.person?.patientId == patientId && calendar.isDate($0.date, inSameDayAs: date)
            }
            return WeekPoint(
                date: date,
                steps: day?.activity?.stepCount ?? 0,
                glucose: nil
            )
        }
    }

    private func todayDay(patientId: String) -> Day? {
        let todayId = HealthDay.sourceId(for: Date())
        let key = Self.dayKey(patientId: patientId, sourceId: todayId)
        var descriptor = FetchDescriptor<Day>(predicate: #Predicate { $0.dayKey == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
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
