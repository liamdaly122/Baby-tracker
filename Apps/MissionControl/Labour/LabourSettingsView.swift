import MissionCore
import MissionUI
import SwiftUI

/// Labour-time settings: the thresholds in use and the hospital details.
struct LabourSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                ForEach(Self.summaries(model.labour.thresholds), id: \.0) { label, value in
                    LabeledContent(label, value: value)
                }
                NavigationLink("Change when to call") { ThresholdEditor() }
            } header: {
                Text("This labour's thresholds")
            } footer: {
                Text("Your midwife may give you different advice. Use theirs.")
            }
            Section("Hospital and her details") {
                NavigationLink("Hospital or birth centre") { BirthPlacesView() }
                NavigationLink("Her details for the call") { MissionProfileForm() }
            }
        }
        .navigationTitle("Labour settings")
    }

    static func summaries(_ thresholds: ThresholdProfile) -> [(String, String)] {
        [
            ("Call when every", StateCopy.phrase(seconds: thresholds.adviceIntervalSec)),
            (
                "Lasting at least",
                thresholds.adviceDurationSec > 0 ? StateCopy.phrase(seconds: thresholds.adviceDurationSec) : "No rule"
            ),
            (
                "Wait at that rate first",
                thresholds.patternWindowSec > 0 ? StateCopy.phrase(seconds: thresholds.patternWindowSec) : "No (NHS)"
            ),
            ("Call now if one lasts over", StateCopy.phrase(seconds: thresholds.urgentSingleDurationSec)),
            ("Call now at", "\(thresholds.urgentCountIn10Min) in 10 minutes"),
        ]
    }
}
