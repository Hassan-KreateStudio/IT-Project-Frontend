import Foundation

enum Log {
    static func health(_ message: String) {
        print("[GraphHealth:Health] \(message)")
    }

    static func graph(_ message: String) {
        print("[GraphHealth:Graph] \(message)")
    }

    static func sync(_ message: String) {
        print("[GraphHealth:Sync] \(message)")
    }
}
