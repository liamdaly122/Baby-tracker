import MissionCore
import MissionUI
import SwiftUI

/// Ends labour mode. If the baby's here, compose the one-tap "baby's here" message first.
struct EndLabourView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.missionMode) private var mode
    @State private var babyName = ""
    @State private var weight = ""
    @State private var wellbeing = "Mum and baby are doing well."
    @State private var visiting = "We'll be in touch about visiting."
    @State private var confirmingEnd = false

    private var message: String {
        let time = model.labour.currentTime.formatted(date: .omitted, time: .shortened)
        let opener = model.profile.humour == .full ? "The Payload has landed!" : "Baby's here!"
        var parts = [opener]
        let name = babyName.trimmingCharacters(in: .whitespaces)
        parts.append(name.isEmpty ? "Born at \(time)." : "\(name) was born at \(time).")
        if !weight.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append("\(weight.trimmingCharacters(in: .whitespaces)).")
        }
        if !wellbeing.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append(wellbeing.trimmingCharacters(in: .whitespaces))
        }
        if !visiting.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append(visiting.trimmingCharacters(in: .whitespaces))
        }
        return parts.joined(separator: " ")
    }

    var body: some View {
        if mode == .practice {
            practiceEnd
        } else {
            liveEnd
        }
    }

    /// A practice run just ends: no message to send, nothing kept.
    private var practiceEnd: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("End the practice run?")
                .font(.largeTitle.bold())
                .foregroundStyle(LabourTheme.primaryText)
            Text("Nothing from the drill is kept. Real labour mode is one tap away whenever you need it.")
                .foregroundStyle(LabourTheme.secondaryText)
            Button {
                model.endDrill()
            } label: {
                Text("End the drill")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LabourTheme.blueprint))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(16)
    }

    private var liveEnd: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Baby's here?")
                    .font(.largeTitle.bold())
                    .foregroundStyle(LabourTheme.primaryText)
                Text(
                    "Send one message to everyone, then end labour mode. Nothing is posted anywhere unless you send it."
                )
                .foregroundStyle(LabourTheme.secondaryText)
                field("Baby's name (optional)", text: $babyName)
                field("Weight (optional), e.g. 7 lb 2 oz", text: $weight)
                field("How they're doing", text: $wellbeing)
                field("Visiting", text: $visiting)
                Text(message)
                    .font(.title3)
                    .foregroundStyle(LabourTheme.primaryText)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LabourTheme.surface))
                ShareLink(item: message) {
                    Label("Send the message", systemImage: "paperplane.fill")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LabourTheme.amber))
                }
                Button {
                    if confirmingEnd {
                        model.labour.end()
                    } else {
                        withAnimation { confirmingEnd = true }
                    }
                } label: {
                    Text(confirmingEnd ? "Tap again to end labour mode" : "End labour mode")
                        .font(.headline)
                        .foregroundStyle(confirmingEnd ? Color.white : LabourTheme.primaryText)
                        .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(confirmingEnd ? LabourTheme.urgent : LabourTheme.surface)
                        )
                }
                .buttonStyle(.plain)
                Text("False alarm? Ending labour mode keeps nothing running. You can launch again any time.")
                    .font(.footnote)
                    .foregroundStyle(LabourTheme.secondaryText)
            }
            .padding(16)
        }
        .background(LabourTheme.background)
        .navigationTitle("End labour")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .font(.title3)
            .padding(.horizontal, 14)
            .frame(minHeight: LabourTheme.minimumControlSize)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LabourTheme.surface))
    }
}

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
            Section("Hospital") {
                NavigationLink("Mission profile and hospital details") { MissionProfileForm() }
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
