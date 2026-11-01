import MissionCore
import MissionUI
import SwiftUI

/// The questions the app asks instead of guessing, and the notes it owes him. Shown above the
/// timer, newest worry first.
struct LabourPrompts: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let labour = model.labour
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            VStack(spacing: 8) {
                switch labour.prompt {
                case .endedOrNew(let elapsed):
                    NoticeAsk(
                        title: "This one has been going \(clockText(elapsed)).",
                        detail: "Did it just end, or is this a new one?",
                        choices: [("It just ended", labour.endedJustNow), ("This is a new one", labour.newOneStarted)]
                    )
                case .fixForgotten(let id, let elapsed):
                    NoticeAsk(
                        title: "How long did that last one last?",
                        detail: "You started a new one without stopping it.",
                        choices: TapPolicy.forgottenStopFixesSec(elapsed: elapsed).map { seconds in
                            (
                                seconds == elapsed.rounded() ? "All \(clockText(seconds))" : "\(Int(seconds)) sec",
                                { labour.close(id, afterSeconds: seconds) }
                            )
                        }
                    )
                case .watersWhen:
                    WatersTimeCard()
                case nil:
                    EmptyView()
                }
                if labour.needsTermAnswer {
                    NoticeAsk(
                        title: "Is she 37 weeks pregnant or more?",
                        detail: "There's no due date saved. Until you know, the advice is to call now.",
                        choices: [
                            ("Yes, 37 or more", { labour.answerTerm(.term) }),
                            ("No, under 37", { labour.answerTerm(.preterm) }),
                            ("Not sure", { labour.answerTerm(.notSure) }),
                        ]
                    )
                }
                if let output = labour.output {
                    notes(output, labour: labour, now: labour.currentTime)
                }
            }
        }
    }

    @ViewBuilder
    private func notes(_ output: EngineOutput, labour: LabourSessionModel, now: Date) -> some View {
        let metrics = output.metrics
        if output.reasons.contains(.noRecentTaps), let lastStart = metrics.lastStart,
            labour.quietAcknowledgedFor != lastStart
        {
            NoticeAsk(
                title: "Nothing logged for \(Int(now.timeIntervalSince(lastStart) / 60)) min.",
                detail: "Are they still coming?",
                choices: [("Still coming", labour.acknowledgeQuiet), ("They've stopped", labour.markStopped)]
            )
        }
        let missed = metrics.missedTapGaps.reduce(0) { $0 + $1.estimatedMissed }
        if missed > 0 {
            NoticeInfo(
                title: missed == 1 ? "Looks like 1 wasn't logged." : "Looks like \(missed) weren't logged.",
                detail: "They're counted, so the pattern isn't lost. The call script says so too."
            )
        }
        if output.reasons.contains(.contractionsStopped) {
            NoticeInfo(
                title: "You said they've stopped.",
                detail: "Tap Start if they come back. If the next one comes on rhythm, the app treats it as a pause."
            )
        }
    }
}

/// "When did her waters go?" Triage asks, and induction is usually offered about 24 hours after.
private struct WatersTimeCard: View {
    @Environment(AppModel.self) private var model
    @State private var picking = false
    @State private var time = Date()

    var body: some View {
        let labour = model.labour
        VStack(alignment: .leading, spacing: 6) {
            Text("When did her waters go?")
                .font(MissionType.body(15).weight(.bold))
            Text("Triage will ask. Use a pad, not a tampon, so the colour can be checked.")
                .font(MissionType.body(13.5))
            if picking {
                DatePicker(
                    "Waters went at", selection: $time,
                    in: labour.currentTime.addingTimeInterval(-48 * 3600)...labour.currentTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .colorScheme(.light)
                Button("Save that time") { labour.setWatersTime(time) }
                    .buttonStyle(.borderedProminent)
                    .tint(LabourTheme.paperInk)
            } else {
                if let before = labour.earlierWaters {
                    // Turned off and on again: the earlier time is probably still right. Say whether
                    // he gave it or it was only when the flag was tapped.
                    let clock = before.onAt.formatted(date: .omitted, time: .shortened)
                    choice(before.timeGiven ? "Same as before (\(clock))" : "When you tapped it before (\(clock))") {
                        labour.setWatersTime(before.onAt)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    choice("Just now") { labour.setWatersTime(secondsAgo: 0) }
                    choice("30 min ago") { labour.setWatersTime(secondsAgo: 1800) }
                    choice("1 hour ago") { labour.setWatersTime(secondsAgo: 3600) }
                    choice("Another time") {
                        time = labour.earlierWaters?.onAt ?? labour.currentTime
                        picking = true
                    }
                }
            }
        }
        .foregroundStyle(LabourTheme.paperInk)
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LabourTheme.cream))
    }

    private func choice(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(MissionType.body(13.5).weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: LabourTheme.chipSize)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(LabourTheme.paperInk, lineWidth: 1.5)
                )
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// A question with its answers: the prototype's cream "ask" card, first answer filled.
struct NoticeAsk: View {
    var title: String
    var detail: String
    var choices: [(String, () -> Void)]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(MissionType.body(15).weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(MissionType.body(13.5))
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { buttons }
                VStack(spacing: 6) { buttons }
            }
            .padding(.top, 4)
        }
        .foregroundStyle(LabourTheme.paperInk)
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LabourTheme.cream))
        .accessibilityElement(children: .contain)
    }

    private var buttons: some View {
        ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
            Button(action: choice.1) {
                Text(choice.0)
                    .font(MissionType.body(13.5).weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: LabourTheme.chipSize)
                    .foregroundStyle(index == 0 ? LabourTheme.cream : LabourTheme.paperInk)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(index == 0 ? LabourTheme.paperInk : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(LabourTheme.paperInk, lineWidth: 1.5)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

/// Something worth knowing that needs no answer: the prototype's pale-blue "info" card.
struct NoticeInfo: View {
    var title: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(MissionType.body(15).weight(.bold))
            Text(detail).font(MissionType.body(13.5))
        }
        .foregroundStyle(LabourTheme.cream)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LabourTheme.blueprint.opacity(0.14)))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(LabourTheme.blueprint.opacity(0.35), lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
    }
}
