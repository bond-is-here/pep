import SwiftUI

@main
struct PepApp: App {
    @State private var store = WorkoutStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .preferredColorScheme(RCAppearance.shared.colorScheme)
                .tint(RCTheme.accent)
        }
    }
}
