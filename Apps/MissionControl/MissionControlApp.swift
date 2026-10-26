import MissionContent
import MissionCore
import MissionUI
import SwiftUI

@main
struct MissionControlApp: App {
    var body: some Scene {
        WindowGroup {
            ConsoleShellView()
        }
    }
}

/// Phase 0 shell. Labour mode arrives in Phase 3 and the pre-launch screens in Phase 6.
struct ConsoleShellView: View {
    private let thresholdsLoaded = (try? BundledContent.thresholdTable(for: .uk)) != nil

    var body: some View {
        VStack(spacing: 12) {
            Text("Mission Control")
                .font(.largeTitle.bold())
                .foregroundStyle(LabourTheme.amber)
            Text("Flight Director console. Systems coming online.")
                .foregroundStyle(LabourTheme.primaryText)
            Text(thresholdsLoaded ? "Telemetry thresholds loaded" : "Telemetry thresholds missing")
                .font(.footnote)
                .foregroundStyle(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LabourTheme.background)
    }
}
