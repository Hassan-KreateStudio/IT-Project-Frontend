import Foundation

/// The Health types `HealthKitService.readTypes` asks for, in words.
///
/// Stand minutes are not requested. The in-app screen and the iOS permission
/// sheet (Info.plist `NSHealthShareUsageDescription`) both use this list.
enum HealthAccessCopy {
    static let kinds = [
        "steps",
        "heart rate",
        "exercise minutes",
        "date of birth",
        "height",
        "weight"
    ]

    static var inApp: String {
        "IT Project reads your \(list) from Apple Health, so they can sit next to your glucose."
    }

    static var systemSheet: String {
        "IT Project reads \(list) from Apple Health."
    }

    private static var list: String {
        guard let last = kinds.last else { return "" }
        let head = kinds.dropLast().joined(separator: ", ")
        return head.isEmpty ? last : "\(head), and \(last)"
    }
}
