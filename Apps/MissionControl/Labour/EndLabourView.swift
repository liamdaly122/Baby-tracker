import MissionCore
import MissionUI
import SwiftUI

/// Ends labour mode, one of two ways: the baby's here (then "How is everyone?"), or it wasn't
/// labour after all. Plain words whatever the humour setting. A practice run just ends. In the
/// prototype's look: dark choices, then, only when everyone is well, its dawn and paper.
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
                switch exit {
                case nil:
                    chooser.padding(18)
                case .born:
                    BirthOutcomeFlow()
                case .notLabour:
                    NotLabourEnd().padding(18)
                }
            }
            .scrollIndicators(.hidden)
            .background(LabourTheme.space)
            .navigationTitle("End labour mode")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var chooser: some View {
        VStack(alignment: .leading, spacing: 12) {
            EndHeading(eyebrow: "End labour mode", title: "How is labour mode ending?")
            EndChoice(title: "Labour has ended", detail: "The baby's here, or something has happened") { exit = .born }
            EndChoice(title: "Not in labour after all", detail: "Back home. Nothing is kept running") {
                exit = .notLabour
            }
        }
    }
}

/// A small sun label and a big heading, as the labour tabs have.
struct EndHeading: View {
    var eyebrow: String
    var title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(eyebrow.uppercased())
                .font(MissionType.mono())
                .tracking(MissionType.monoTracking())
                .foregroundStyle(LabourTheme.sun)
            Text(title)
                .font(MissionType.display(38))
                .tracking(0.76)
                .foregroundStyle(LabourTheme.cream)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// One big, plain choice.
struct EndChoice: View {
    var title: String
    var detail: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(MissionType.body(17).weight(.bold))
                        .foregroundStyle(LabourTheme.cream)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(MissionType.body(14))
                            .foregroundStyle(LabourTheme.muted)
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(LabourTheme.muted)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(FlagToggle.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(LabourTheme.cream.opacity(0.3), lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// "How is everyone?", then the birth time and the message, or after a loss, only the way out.
/// Only "All well" gets the prototype's dawn: the other routes stay quiet.
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
                lossEnd.padding(18)
            } else if outcome == .allWell {
                VStack(spacing: 0) {
                    DawnScene()
                    birthEnd(outcome)
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 24)
                        .background(
                            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 28, topTrailing: 28))
                                .fill(LabourTheme.cream)
                        )
                        .padding(.top, -64)
                }
            } else {
                birthEnd(outcome)
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LabourTheme.cream))
                    .padding(18)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                EndHeading(eyebrow: "Labour has ended", title: "How is everyone?")
                ForEach(PregnancyOutcome.allCases, id: \.self) { choice in
                    EndChoice(title: choice.choice, detail: "") {
                        bornAt = model.labour.currentTime
                        wellbeing = choice.defaultWellbeing
                        visiting = choice == .allWell ? "We'll be in touch about visiting." : ""
                        outcome = choice
                    }
                }
            }
            .padding(18)
        }
    }

    /// After a loss: plain words, no display type, no colour, and only the way out.
    private var lossEnd: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("We're so sorry.")
                .font(MissionType.body(28, relativeTo: .title).weight(.semibold))
                .foregroundStyle(LabourTheme.cream)
                .accessibilityAddTraits(.isHeader)
            Text(
                "Ending labour mode turns off its alerts and the countdown. Support you can call is on the next "
                    + "screen, for when you want it."
            )
            .font(MissionType.body(16))
            .lineSpacing(3)
            .foregroundStyle(LabourTheme.muted)
            endButton("End labour mode") {
                model.recordOutcome(.loss, birthAt: nil, babyName: "")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The prototype's paper card: when, the details, the message and the way out.
    private func birthEnd(_ outcome: PregnancyOutcome) -> some View {
        let message = BirthOutcomeMessage.text(
            outcome: outcome, bornAt: bornAt, babyName: babyName, details: [weight, wellbeing, visiting])
        return VStack(alignment: .leading, spacing: 12) {
            if outcome == .allWell {
                Text("The baby's here.")
                    .font(MissionType.display(52))
                    .tracking(1)
                    .accessibilityAddTraits(.isHeader)
            }
            DatePicker("Born at", selection: $bornAt, in: ...model.labour.currentTime)
                .font(MissionType.body(16))
                .colorScheme(.light)
            field("Baby's name (optional)", text: $babyName)
            field("Weight (optional), e.g. 7 lb 2 oz", text: $weight)
            field(outcome == .allWell ? "How they're doing" : "How they're doing (optional)", text: $wellbeing)
            field("Visiting (optional)", text: $visiting)
            Text(
                outcome == .allWell
                    ? "One message to everyone. Nothing is sent unless you send it."
                    : "Only say as much as you want to. Nothing is sent unless you send it."
            )
            .font(MissionType.body(14))
            .foregroundStyle(LabourTheme.paperMuted)
            .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(MissionType.body(16))
                .lineSpacing(3)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LabourPalette.paperHi.color))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(LabourPalette.paperEdge.color, lineWidth: 2)
                )
            ShareLink(item: message) {
                Label("Send the message", systemImage: "paperplane.fill")
                    .font(MissionType.body(16).weight(.semibold))
                    .foregroundStyle(LabourTheme.cream)
                    .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LabourTheme.paperInk))
            }
            endButton("End labour mode", onPaper: true) {
                model.recordOutcome(outcome, birthAt: bornAt, babyName: babyName.trimmingCharacters(in: .whitespaces))
            }
        }
        .foregroundStyle(LabourTheme.paperInk)
    }

    /// The prototype's paper field: a small label over a pale box with a tan edge.
    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(MissionType.mono())
                .tracking(1.3)
                .foregroundStyle(LabourTheme.paperMuted)
            TextField("", text: text)
                .font(MissionType.body(16))
                .foregroundStyle(LabourTheme.paperInk)
                .padding(.horizontal, 12)
                .frame(minHeight: LabourTheme.minimumControlSize)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LabourPalette.paperHi.color))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(LabourPalette.paperEdge.color, lineWidth: 2)
                )
                .accessibilityLabel(title)
        }
    }
}

/// Not labour after all: nothing is recorded, and LAUNCH is there again on the home screen.
private struct NotLabourEnd: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            EndHeading(eyebrow: "End labour mode", title: "Not in labour after all?")
            Text("That's common. If anything changes, launch again: it works the same at any time.")
                .font(MissionType.body(16))
                .lineSpacing(3)
                .foregroundStyle(LabourTheme.muted)
            endButton("End labour mode") { model.labour.end() }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Ends on the second tap, so a stray tap can't end labour mode. The second tap is the darker
/// red, so its cream words stay readable (it was white on bright orange, 2.8:1).
private struct EndButton: View {
    var title: String
    var onPaper: Bool
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
                .font(MissionType.body(16).weight(.semibold))
                .foregroundStyle(confirming ? LabourTheme.cream : (onPaper ? LabourTheme.paperInk : LabourTheme.cream))
                .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(confirming ? LabourTheme.hot : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            confirming
                                ? LabourTheme.hot : (onPaper ? LabourTheme.paperInk : LabourTheme.cream.opacity(0.4)),
                            lineWidth: 1.5)
                )
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private func endButton(
    _ title: String, onPaper: Bool = false, action: @escaping @MainActor () -> Void
) -> some View {
    EndButton(title: title, onPaper: onPaper, action: action)
}

/// A practice run just ends: no message to send, nothing kept.
private struct PracticeEnd: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            SimCard(label: "Practice run", title: "End the practice run?") {
                Text("Nothing from the drill is kept. Real labour mode is one tap away whenever you need it.")
                    .font(MissionType.body(15))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                SimButton(title: "End the drill") { model.endDrill() }
            }
            .padding(18)
        }
        .background { OrbitScene(isPractice: true) }
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
