import SwiftUI

@main
struct ArcheryWatchApp: App {
    @StateObject private var motionManager = MotionManager()
    @StateObject private var sessionManager = WatchSessionManager.shared

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(motionManager)
                .environmentObject(sessionManager)
        }
    }
}
