import MissionCore
import MissionUI
import SwiftUI

@main
struct MissionControlWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchShellView()
        }
    }
}

/// Phase 0 shell. The standalone labour timer arrives in Phase 5.
struct WatchShellView: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("Mission Control")
                .font(.headline)
                .foregroundStyle(LabourTheme.amber)
            Text("Standing by")
                .foregroundStyle(LabourTheme.primaryText)
        }
    }
}
