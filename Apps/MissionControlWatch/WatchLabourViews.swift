import MissionCore
import MissionUI
import SwiftUI
import WatchKit

private let shortState: [LabourState: String] = [
    .early: "No pattern", .establishing: "Keep timing", .callTriage: "Time to call", .callNow: "Call now",
    .call999: "Call 999",
]

/// The main page, as the prototype's watch: the advice in a small pill, any question the app needs
/// answered, the call button from "time to call", the round button, and how often and how many.
struct WatchTimerPage: View {
    @Environment(WatchLabourModel.self) private var model

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ScrollView {
                VStack(spacing: 8) {
                    header
                    WatchQuestions()
                    if let output = model.output, output.state >= .callTriage {
                        WatchCallButton(state: output.state, compact: true)
                    }
                    burn(now: context.date)
                    footer(now: context.date)
                }
            }
        }
        .containerBackground(LabourTheme.space, for: .tabView)
    }

    private var header: some View {
        WatchStatePill(text: pillText(model.output?.state ?? .early), state: model.output?.state ?? .early)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                model.output.map { StateCopy.headline(for: $0, region: model.core?.start.profile.region ?? .uk) }
                    ?? "")
    }

    /// After a logged call: "Called" while it covers the advice, "Call back" once something changes.
    private func pillText(_ state: LabourState) -> String {
        switch model.output?.call {
        case .acknowledged: "Called"
        case .callBack: "Call back"
        case nil: shortState[state] ?? ""
        }
    }

    private func burn(now: Date) -> some View {
        let open = model.openContraction
        return WatchBurnButton(isRunning: open != nil, elapsed: open.map { now.timeIntervalSince($0.start) } ?? 0) {
            WKHaptics.tap(start: open == nil)
            model.tap()
        }
    }

    private func footer(now: Date) -> some View {
        VStack(spacing: 4) {
            if let notice = model.notice, notice.until > now {
                Text(notice.text)
                    .font(MissionType.body(13, relativeTo: .footnote))
                    .foregroundStyle(LabourTheme.muted)
            } else if let undoable = model.undoable, undoable.until > now {
                Button {
                    model.undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .font(MissionType.body(14).weight(.semibold))
                        .foregroundStyle(LabourTheme.paperInk)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Capsule().fill(LabourTheme.cream))
                }
                .buttonStyle(.plain)
            }
            WatchStatsLine(every: every, lastHour: lastHour(now: now))
        }
    }

    private var every: String {
        guard let output = model.output, let median = output.metrics.recentMedianIntervalSec else { return "–" }
        return "\(StateCopy.clock(median, threshold: output.thresholds.adviceIntervalSec)) apart"
    }

    private func lastHour(now: Date) -> Int {
        model.log.contractions.filter { now.timeIntervalSince($0.start) <= 3600 && $0.start <= now }.count
    }
}

/// The app asks instead of guessing: forgotten stops, the 37-week question, a quiet log.
private struct WatchQuestions: View {
    @Environment(WatchLabourModel.self) private var model

    var body: some View {
        switch model.prompt {
        case .endedOrNew(let elapsed):
            ask(
                "Going \(clockText(elapsed)). Did it just end?",
                [("Just ended", model.endedJustNow), ("New one", model.newOneStarted)])
        case .fixForgotten(let id, let elapsed):
            ask(
                "How long did the last one last?",
                TapPolicy.forgottenStopFixesSec(elapsed: elapsed).map { seconds in
                    (
                        seconds == elapsed.rounded() ? "All \(clockText(seconds))" : "\(Int(seconds))s",
                        { model.close(id, afterSeconds: seconds) }
                    )
                })
        case nil:
            if model.needsTermAnswer {
                ask(
                    "Is she 37 weeks or more?",
                    [
                        ("Yes", { model.answerTerm(.term) }), ("No", { model.answerTerm(.preterm) }),
                        ("Not sure", { model.answerTerm(.notSure) }),
                    ])
            } else if let output = model.output, output.reasons.contains(.noRecentTaps),
                let last = output.metrics.lastStart, model.quietAcknowledgedFor != last
            {
                ask(
                    "Are they still coming?",
                    [("Still coming", model.acknowledgeQuiet), ("Stopped", model.markStopped)])
            }
        }
    }

    private func ask(_ question: String, _ answers: [(String, () -> Void)]) -> some View {
        WatchAskCard(question: question, answers: answers)
    }
}

/// Ring the unit (or 999) from the wrist: the prototype's watch call button, sun at "time to
/// call", the darker red from "call now".
struct WatchCallButton: View {
    @Environment(WatchLabourModel.self) private var model
    var state: LabourState
    var compact = false

    var body: some View {
        let is999 = state == .call999
        let number = is999 ? PhoneNumber.shortCode("999") : model.brief?.triage
        let warm = state == .callTriage
        if let number, let url = number.telURL {
            Link(destination: url) {
                WatchCallFace(title: is999 ? "Call 999" : "Call \(unitName)", warm: warm, compact: compact)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(is999 ? "Call 999" : "Call \(unitName), \(number.display)")
        } else if !is999 {
            Text("No unit number on iPhone. Call 111.")
                .font(MissionType.body(13, relativeTo: .footnote))
                .foregroundStyle(LabourTheme.muted)
        }
    }

    private var unitName: String {
        let name = model.brief?.unitName ?? ""
        return name.isEmpty ? "the unit" : name
    }
}

/// Who to call, in order, with "Can't get through?" built in.
struct WatchCallPage: View {
    @Environment(WatchLabourModel.self) private var model

    var body: some View {
        let region = model.core?.start.profile.region ?? .uk
        let steps = CallFallback.steps(region: region, unit: model.brief?.triage, labourWard: model.brief?.labourWard)
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("COMMS")
                    .font(MissionType.mono())
                    .tracking(1.3)
                    .foregroundStyle(CallLook.label)
                WatchCallButton(state: .callNow)
                if let after = model.brief?.triage?.afterConnecting {
                    Text(after)
                        .font(MissionType.mono())
                        .foregroundStyle(LabourTheme.cream.opacity(0.75))
                }
                Text("IF NOBODY ANSWERS")
                    .font(MissionType.mono())
                    .tracking(1.3)
                    .foregroundStyle(CallLook.label)
                    .padding(.top, 4)
                ForEach(steps, id: \.self) { step in
                    if let number = step.number, let url = number.telURL {
                        Link(destination: url) {
                            WatchCallRow(title: step.title, number: number.display)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .containerBackground(LabourPalette.callTop.color, for: .tabView)
    }
}

/// Red flags: each one forces at least "call now" and stays on until he turns it off.
struct WatchFlagsPage: View {
    @Environment(WatchLabourModel.self) private var model
    /// A lit flag he tapped: turning it off asks first, so a brush of the wrist can't lower the advice.
    @State private var confirmingOff: RedFlag?

    var body: some View {
        let active = model.log.activeRedFlags
        List {
            ForEach(RedFlag.allCases, id: \.self) { flag in
                Toggle(
                    flag.label,
                    isOn: Binding(
                        get: { active.contains(flag) },
                        set: { isOn in
                            if isOn { model.setRedFlag(flag, isOn: true) } else { confirmingOff = flag }
                        })
                )
                .font(MissionType.body(14).weight(.semibold))
                .tint(LabourTheme.hot)
            }
            if !model.log.contractions.isEmpty {
                Button("They've stopped") { model.markStopped() }
                    .font(MissionType.body(14))
            }
        }
        .navigationTitle("Red flags")
        .containerBackground(LabourTheme.space, for: .tabView)
        .confirmationDialog(
            "Turn off \(confirmingOff?.label ?? "")?",
            isPresented: Binding(get: { confirmingOff != nil }, set: { if !$0 { confirmingOff = nil } })
        ) {
            Button("Turn it off", role: .destructive) {
                if let flag = confirmingOff { model.setRedFlag(flag, isOn: false) }
                confirmingOff = nil
            }
            Button("Keep it on", role: .cancel) { confirmingOff = nil }
        } message: {
            Text("Only if it was tapped by mistake.")
        }
    }
}

/// Distinct taps for start and stop, so he can tell which he pressed without looking.
enum WKHaptics {
    static func tap(start: Bool) {
        WKInterfaceDevice.current().play(start ? .start : .stop)
    }

    static func success() {
        WKInterfaceDevice.current().play(.success)
    }
}
