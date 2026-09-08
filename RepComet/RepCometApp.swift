import SwiftUI

@main
struct PepApp: App {
    @State private var store: WorkoutStore

    init() {
        #if DEBUG
        _store = State(initialValue: WorkoutStore(fileURL: PepUITestLaunch.workoutFileURL))
        #else
        _store = State(initialValue: WorkoutStore())
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .preferredColorScheme(RCAppearance.shared.colorScheme)
                .tint(RCTheme.accent)
                #if DEBUG
                .modifier(PepUITestAccessibility())
                #endif
        }
    }
}

#if DEBUG
/// UI tests use real persistence in their own UUID directory. Keeping the same
/// session across launches tests recovery without touching ordinary app data.
enum PepUITestLaunch {
    private static var directory: URL? {
        let process = ProcessInfo.processInfo
        guard process.arguments.contains("--pep-ui-testing"),
              let value = process.environment["PEP_UI_TEST_SESSION"],
              let session = UUID(uuidString: value) else { return nil }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support.appendingPathComponent("PepUITests", isDirectory: true)
            .appendingPathComponent(session.uuidString, isDirectory: true)
    }

    static var workoutFileURL: URL? { directory?.appendingPathComponent("workouts.json") }
    static var appearanceFileURL: URL? { directory?.appendingPathComponent("appearance.json") }
    static var reduceMotion: Bool {
        directory != nil && ProcessInfo.processInfo.environment["PEP_UI_TEST_REDUCE_MOTION"] == "1"
    }
    static var largeText: Bool {
        directory != nil && ProcessInfo.processInfo.environment["PEP_UI_TEST_LARGE_TEXT"] == "1"
    }
}

private struct PepUITestAccessibility: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if PepUITestLaunch.largeText {
            content.dynamicTypeSize(.accessibility5)
        } else {
            content
        }
    }
}
#endif

extension EnvironmentValues {
    /// Release builds follow the device setting. Debug UI tests can exercise the
    /// same decision path without changing the runner's accessibility settings.
    var pepReduceMotion: Bool {
        #if DEBUG
        accessibilityReduceMotion || PepUITestLaunch.reduceMotion
        #else
        accessibilityReduceMotion
        #endif
    }
}
