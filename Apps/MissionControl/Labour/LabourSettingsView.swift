import MissionCore
import MissionUI
import SwiftUI

/// Labour-time settings: the thresholds in use and the hospital details.
struct LabourSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PaperPage("Labour settings", subtitle: "When to call, the hospital, her details") {
            PaperSection("This labour's thresholds", note: "Your midwife may give you different advice. Use theirs.") {
                PaperCard {
                    ForEach(Self.summaries(model.labour.thresholds), id: \.0) { label, value in
                        HStack(alignment: .firstTextBaseline) {
                            Text(label)
                                .font(MissionType.body(15))
                            Spacer(minLength: 8)
                            Text(value)
                                .font(MissionType.body(15).weight(.semibold))
                                .multilineTextAlignment(.trailing)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                NavigationLink("Change when to call") { ThresholdEditor() }
                    .buttonStyle(PaperButtonStyle(.ghost))
            }
            PaperSection("Hospital and her details") {
                NavigationLink("Hospital or birth centre") { BirthPlacesView() }
                    .buttonStyle(PaperButtonStyle(.ghost))
                NavigationLink("Her details for the call") { MissionProfileForm() }
                    .buttonStyle(PaperButtonStyle(.ghost))
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
