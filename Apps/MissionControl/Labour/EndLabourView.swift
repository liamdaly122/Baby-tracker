import MissionCore
import MissionUI
import SwiftUI

/// Ends labour mode, one of two ways: the baby's here (then "How is everyone?"), or it wasn't
/// labour after all. Plain words whatever the humour setting. A practice run just ends.
struct EndLabourView: View {
    @Environment(\.missionMode) private var mode
    @State private var exit: Exit?

    enum Exit {
        case born
        case notLabour
    }

    var body: some View {
        if mode == .practice {
            PracticeEnd()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch exit {
                    case nil:
                        chooser
                    case .born:
                        BirthOutcomeFlow()
                    case .notLabour:
                        NotLabourEnd()
                    }
                }
                .padding(16)
            }
            .background(LabourTheme.background)
            .navigationTitle("End labour mode")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var chooser: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How is labour mode ending?")
                .font(.largeTitle.bold())
                .foregroundStyle(LabourTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            EndChoice(title: "Labour has ended", detail: "The baby's here, or something has happened") { exit = .born }
            EndChoice(title: "Not in labour after all", detail: "Back home. Nothing is kept running") {
                exit = .notLabour
            }
        }
    }
}

/// One big, plain choice.
struct EndChoice: View {
    var title: String
    var detail: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3.bold())
                if !detail.isEmpty {
                    Text(detail).font(.subheadline).foregroundStyle(LabourTheme.secondaryText)
                }
            }
            .foregroundStyle(LabourTheme.primaryText)
            .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LabourTheme.surface))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// "How is everyone?", then the birth time and the message, or after a loss, only the way out.
private struct BirthOutcomeFlow: View {
    @Environment(AppModel.self) private var model
    @State private var outcome: PregnancyOutcome?
    @State private var bornAt = Date()
    @State private var babyName = ""
    @State private var weight = ""
    @State private var wellbeing = ""
    @State private var visiting = ""

    var body: some View {
        if let outcome {
            if outcome == .loss {
                lossEnd
            } else {
                birthEnd(outcome)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("How is everyone?")
                    .font(.largeTitle.bold())
                    .foregroundStyle(LabourTheme.primaryText)
                ForEach(PregnancyOutcome.allCases, id: \.self) { choice in
                    EndChoice(title: choice.choice, detail: "") {
                        bornAt = model.labour.currentTime
                        wellbeing = choice.defaultWellbeing
                        visiting = choice == .allWell ? "We'll be in touch about visiting." : ""
                        outcome = choice
                    }
                }
            }
        }
    }

    private var lossEnd: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("We're so sorry.")
                .font(.largeTitle.bold())
            Text(
                "Ending labour mode turns off its alerts and the countdown. Support you can call is on the next "
                    + "screen, for when you want it."
            )
            .foregroundStyle(LabourTheme.secondaryText)
            endButton("End labour mode") {
                model.recordOutcome(.loss, birthAt: nil, babyName: "")
            }
        }
        .foregroundStyle(LabourTheme.primaryText)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func birthEnd(_ outcome: PregnancyOutcome) -> some View {
        let message = BirthOutcomeMessage.text(
            outcome: outcome, bornAt: bornAt, babyName: babyName, details: [weight, wellbeing, visiting])
        return VStack(alignment: .leading, spacing: 16) {
            DatePicker("Born at", selection: $bornAt, in: ...model.labour.currentTime)
                .font(.title3)
                .foregroundStyle(LabourTheme.primaryText)
            field("Baby's name (optional)", text: $babyName)
            field("Weight (optional), e.g. 7 lb 2 oz", text: $weight)
            field(outcome == .allWell ? "How they're doing" : "How they're doing (optional)", text: $wellbeing)
            field("Visiting (optional)", text: $visiting)
            Text(
                outcome == .allWell
                    ? "One message to everyone. Nothing is sent unless you send it."
                    : "Only say as much as you want to. Nothing is sent unless you send it."
            )
            .font(.subheadline)
            .foregroundStyle(LabourTheme.secondaryText)
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
            endButton("End labour mode") {
                model.recordOutcome(outcome, birthAt: bornAt, babyName: babyName.trimmingCharacters(in: .whitespaces))
            }
        }
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .font(.title3)
            .padding(.horizontal, 14)
            .frame(minHeight: LabourTheme.minimumControlSize)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LabourTheme.surface))
    }
}

/// Not labour after all: nothing is recorded, and LAUNCH is there again on the home screen.
private struct NotLabourEnd: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Not in labour after all?")
                .font(.largeTitle.bold())
            Text(
                "That's common. If anything changes, launch again: it works the same at any time."
            )
            .foregroundStyle(LabourTheme.secondaryText)
            endButton("End labour mode") { model.labour.end() }
        }
        .foregroundStyle(LabourTheme.primaryText)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Ends on the second tap, so a stray tap can't end labour mode.
private struct EndButton: View {
    var title: String
    var action: @MainActor () -> Void
    @State private var confirming = false

    var body: some View {
        Button {
            if confirming {
                action()
            } else {
                withAnimation { confirming = true }
            }
        } label: {
            Text(confirming ? "Tap again to end labour mode" : title)
                .font(.headline)
                .foregroundStyle(confirming ? Color.white : LabourTheme.primaryText)
                .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(confirming ? LabourTheme.urgent : LabourTheme.surface))
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private func endButton(_ title: String, action: @escaping @MainActor () -> Void) -> some View {
    EndButton(title: title, action: action)
}

/// A practice run just ends: no message to send, nothing kept.
private struct PracticeEnd: View {
    @Environment(AppModel.self) private var model

    var body: some View {
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
}

/// The one message he can send after the birth: when, then only what he chooses to say.
enum BirthOutcomeMessage {
    static func text(outcome: PregnancyOutcome, bornAt: Date, babyName: String, details: [String]) -> String {
        let opener = outcome.messageOpener(
            babyName: babyName, bornAt: bornAt.formatted(date: .omitted, time: .shortened))
        let rest = details.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            .map { $0.hasSuffix(".") ? $0 : "\($0)." }
        return ([opener] + rest).joined(separator: " ")
    }
}
