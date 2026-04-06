import SwiftUI

@main
struct DiffBuddyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)
    }
}
