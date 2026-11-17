// App entry point (starting point for all features / shows S-02)
// F-06, F-01: owns the one and only audio engine
import SwiftUI

@main
struct MyApp: App {
    // There must be exactly one engine per process (AVAudioSession is also one per app).
    // The App struct is created once, so owning the engine here means every iPad window shares the same engine.
    @State private var engine = HearingAudioEngine()

    var body: some Scene {
        WindowGroup {
            ContentView(engine: engine)
        }
    }
}
