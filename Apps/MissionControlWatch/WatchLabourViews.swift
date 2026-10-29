import MissionCore
import MissionUI
import SwiftUI
import WatchKit

private let shortState: [LabourState: String] = [
    .early: "No pattern", .establishing: "Keep timing", .callTriage: "Time to call", .callNow: "Call now",
    .call999: "Call 999",
]

/// The main page: the advice in a pill, any question the app needs answered, and the big button.
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
        .containerBackground(stateTint.gradient, for: .tabView)
    }

    private var header: some View {
        let state = model.output?.state ?? .early
        return HStack {
            Text(pillText(state))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(state >= .callTriage ? Color.black : LabourTheme.primaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(state >= .callNow ? LabourTheme.urgent : LabourTheme.color(for: state)))
            Spacer()
        }
        .accessibilityLabel(
            model.output.map { StateCopy.headline(for: $0, region: model.core?.start.profile.region ?? .uk) } ?? "")
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
        let elapsed = open.map { now.timeIntervalSince($0.start) } ?? 0
        return Button {
            WKHaptics.tap(start: open == nil)
            model.tap()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.6))
                Circle()
                    .strokeBorder(LabourTheme.amber, lineWidth: open == nil ? 3 : 6)
                VStack(spacing: 0) {
                    Text(open == nil ? "Start" : clockText(elapsed))
                        .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                        .minimumScaleFactor(0.6)
                    Text(open == nil ? "Contraction" : "Tap to stop")
                        .font(.caption2)
                        .foregroundStyle(LabourTheme.secondaryText)
                }
                .foregroundStyle(LabourTheme.primaryText)
            }
            .frame(width: 112, height: 112)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(open == nil ? "Start contraction" : "Stop contraction, running \(clockText(elapsed))")
    }

    private func footer(now: Date) -> some View {
        VStack(spacing: 4) {
            if let notice = model.notice, notice.until > now {
                Text(notice.text).font(.caption2).foregroundStyle(LabourTheme.secondaryText)
            } else if let undoable = model.undoable, undoable.until > now {
                Button("Undo", systemImage: "arrow.uturn.backward") { model.undo() }
                    .font(.caption)
            }
            HStack {
                Text(every)
                Spacer()
                Text("\(lastHour(now: now)) in hour")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(LabourTheme.secondaryText)
        }
    }

    private var every: String {
        guard let output = model.output, let median = output.metrics.recentMedianIntervalSec else { return "–" }
        return "\(StateCopy.clock(median, threshold: output.thresholds.adviceIntervalSec)) apart"
    }

    private func lastHour(now: Date) -> Int {
        model.log.contractions.filter { now.timeIntervalSince($0.start) <= 3600 && $0.start <= now }.count
    }

    private var stateTint: Color {
        switch model.output?.state ?? .early {
        case .callNow, .call999: LabourTheme.emergency.opacity(0.55)
        case .callTriage: LabourTheme.amber.opacity(0.35)
        default: Color.black
        }
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
        VStack(alignment: .leading, spacing: 6) {
            Text(question)
                .font(.footnote.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(answers.enumerated()), id: \.offset) { index, answer in
                Button(answer.0, action: answer.1)
                    .font(.footnote.weight(.semibold))
                    .tint(index == 0 ? LabourTheme.amber : LabourTheme.raisedSurface)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LabourTheme.surface))
    }
}

/// Ring the unit (or 999) from the wrist.
struct WatchCallButton: View {
    @Environment(WatchLabourModel.self) private var model
    var state: LabourState
    var compact = false

    var body: some View {
        let is999 = state == .call999
        let number = is999 ? PhoneNumber.shortCode("999") : model.brief?.triage
        if let number, let url = number.telURL {
            Link(destination: url) {
                HStack(spacing: 8) {
                    Image(systemName: "phone.fill")
                    VStack(alignment: .leading, spacing: 0) {
                        Text(is999 ? "Call 999" : "Call the unit")
                            .font(.footnote.weight(.bold))
                        if !is999 {
                            Text(unitName)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: compact ? 40 : 46)
                .foregroundStyle(state == .callTriage ? Color.black : Color.white)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(state == .callTriage ? LabourTheme.amber : LabourTheme.emergency))
            }
            .buttonStyle(.plain)
        } else if !is999 {
            Text("No unit number on iPhone. Call 111.")
                .font(.caption2)
                .foregroundStyle(LabourTheme.secondaryText)
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
                Text("Call")
                    .font(.headline)
                WatchCallButton(state: .callNow)
                if let after = model.brief?.triage?.afterConnecting {
                    Text(after).font(.caption2).foregroundStyle(LabourTheme.secondaryText)
                }
                Text("Can't get through?")
                    .font(.footnote.weight(.semibold))
                    .padding(.top, 4)
                ForEach(steps, id: \.self) { step in
                    if let number = step.number, let url = number.telURL {
                        Link(destination: url) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(step.title).font(.footnote.weight(.semibold))
                                Text(number.display).font(.caption2.monospacedDigit())
                                    .foregroundStyle(LabourTheme.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
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
                .font(.footnote)
                .tint(LabourTheme.color(for: flag.state))
            }
            if !model.log.contractions.isEmpty {
                Button("They've stopped") { model.markStopped() }
                    .font(.footnote)
            }
        }
        .navigationTitle("Red flags")
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
