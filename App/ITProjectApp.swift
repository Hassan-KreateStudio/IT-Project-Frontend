import SwiftUI

@main
struct ITProjectApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var graph = GraphStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(graph)
        }
    }
}
