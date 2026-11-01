import MissionCore
import MissionUI
import SwiftUI

/// The timer, as the agreed prototype (v3) lays it out over the orbit scene: the level strip, the
/// advice with its call button, the last hour as a line, three numbers, the flags, any question,
/// and the round button. Differences from the prototype, each for a redesign rule: the button is
/// pinned above the tab bar so nothing can push it off screen, the numbers give way first when
/// space runs out, and the contraction list for fixing taps is below the flags.
struct TimerTab: View {
    @Environment(AppModel.self) private var model
    @Environment(\.missionMode) private var mode
    @State private var showsAllFlags = false
    /// A lit flag he tapped: turning it off needs a second, deliberate tap.
    @State private var confirmingOff: RedFlag?
    @State private var expandedRow: UUID?
    /// The height of everything above the button, so the button can take what's left, as in the
    /// prototype: 132 to 212 points.
    @State private var upperHeight: CGFloat = 0
    /// Whether that height included the numbers row, and how tall the row is.
    @State private var measuredWithStats = true
    @State private var statsHeight: CGFloat = 50

    private var labour: LabourSessionModel { model.labour }

    var body: some View {
        GeometryReader { geometry in
            // The one clock in labour mode: everything time-based on the timer reads `now` from here.
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let now = labour.currentTime
                let burn = min(212, max(132, geometry.size.height - upperHeight - 20))
                // The numbers give way first when there isn't room for them and the smallest button.
                let withoutStats = upperHeight - (measuredWithStats ? statsHeight + 12 : 0)
                let roomForStats = geometry.size.height - withoutStats - 20 - (statsHeight + 12) >= 132
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            let showsStats = roomForStats && showsStats(now: now)
                            upper(now: now, showsStats: showsStats)
                                .padding(.top, 4)
                                .padding(.bottom, 4)
                                .onGeometryChange(for: CGFloat.self) {
                                    $0.size.height
                                } action: {
                                    upperHeight = $0
                                    measuredWithStats = showsStats
                                }
                            HistoryList(expandedRow: $expandedRow)
                                .padding(.top, 24)
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        // Above the button, not over it as in the prototype: over a small button
                        // it hid the clock. What it covers scrolls up from under it.
                        UndoArea(now: now)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 4)
                    }
                    dock(now: now, size: burn)
                }
            }
        }
    }

    /// Whether a question is up. Like the prototype, the trace and numbers step aside for it, so
    /// the question shows without pushing the button.
    private func isAsking(now: Date) -> Bool {
        labour.prompt != nil || labour.needsTermAnswer || (labour.justStopped.map { $0.until > now } ?? false)
    }

    /// The prototype hides the numbers at "Call now" and 999, and while a question is up.
    private func showsStats(now: Date) -> Bool {
        !AdviceBlock<EmptyView>.isHot(labour.output?.state ?? .early) && !isAsking(now: now)
    }

    private func upper(now: Date, showsStats: Bool) -> some View {
        let state = labour.output?.state
        let asking = isAsking(now: now)
        return VStack(alignment: .leading, spacing: 12) {
            if mode == .practice, let drill = model.drill {
                DrillGuideCard(drill: drill)
            }
            if let state {
                LevelStrip(state: state)
            }
            advice
            if !asking {
                telemetry(now: now, compact: (state ?? .early) >= .callTriage)
            }
            if showsStats {
                stats(now: now)
                    .onGeometryChange(for: CGFloat.self) {
                        $0.size.height
                    } action: {
                        statsHeight = $0
                    }
            }
            flags
            StrengthQuestion(now: now)
            LabourPrompts()
        }
    }

    @ViewBuilder private var advice: some View {
        if let output = labour.output {
            let thresholds = output.thresholds
            AdviceBlock(
                state: output.state,
                headline: StateCopy.headline(for: output, region: labour.region),
                reasonLines: output.reasons.filter { $0 != .noRecentTaps }.map {
                    StateCopy.reasonLine(
                        for: $0, metrics: output.metrics, thresholds: thresholds, now: output.evaluatedAt)
                } + contractionLine(output),
                detail: StateCopy.detail(for: output, region: labour.region, thresholds: thresholds),
                source: output.reasons.first.map { StateCopy.source(for: $0, region: labour.region).title }
            ) {
                if output.state >= .callTriage {
                    AdviceCall(state: output.state)
                }
            }
            .onChange(of: output.state) { _, _ in
                // Once per change of level, never on the every-second redraw.
                AccessibilityNotification.Announcement(
                    mode.spokenHeadline(StateCopy.headline(for: output, region: labour.region))
                ).post()
            }
        }
    }

    /// Under a red flag or the gestation rule, what the contractions alone say, so the pattern
    /// is never hidden by a flag.
    private func contractionLine(_ output: EngineOutput) -> [String] {
        let advice = output.contractionAdvice
        guard advice.state < output.state, let reason = advice.reasons.first(where: { $0 != .patternEasing }) else {
            return []
        }
        let line = StateCopy.reasonLine(
            for: reason, metrics: output.metrics, thresholds: output.thresholds, now: output.evaluatedAt)
        return ["Contractions: \(line)"]
    }

    /// "TELEMETRY · LAST 60 MIN", then the line. Shorter once it's time to call.
    private func telemetry(now: Date, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("TELEMETRY · LAST 60 MIN")
                Spacer(minLength: 8)
                Text("NOW")
            }
            .font(MissionType.mono())
            .tracking(MissionType.monoTracking())
            .lineLimit(1)
            .foregroundStyle(LabourTheme.muted)
            .accessibilityHidden(true)
            ContractionTrace(
                contractions: labour.log.contractions,
                missedTaps: labour.output?.metrics.missedTapGaps ?? [],
                now: now
            )
            .frame(height: compact ? 48 : 80)
        }
    }

    private func stats(now: Date) -> some View {
        let metrics = labour.output?.metrics
        let lastHour = labour.log.contractions.filter {
            $0.start >= now.addingTimeInterval(-3600) && $0.start <= now.addingTimeInterval(60)
        }.count
        return StatsStrip([
            (metrics.map { every($0, labour.thresholds) } ?? "–", "Every"),
            (metrics?.medianDurationSec.map { "\(Int($0.rounded()))s" } ?? "–", "Lasting"),
            ("\(lastHour)", "Last hour"),
        ])
    }

    /// Pinned under the scrolling area: the big button, with "They've stopped" in its corner.
    private func dock(now: Date, size: CGFloat) -> some View {
        let open = labour.openContraction
        let showsStopped =
            !labour.log.contractions.isEmpty && open == nil
            && labour.output?.reasons.contains(.contractionsStopped) != true
        return BurnButton(
            isRunning: open != nil,
            elapsed: open.map { now.timeIntervalSince($0.start) },
            urgentAfter: labour.thresholds.urgentSingleDurationSec,
            isCompact: AdviceBlock<EmptyView>.isHot(labour.output?.state ?? .early)
        ) {
            labour.tap()
        }
        .frame(width: size, height: size)
        .sensoryFeedback(trigger: open != nil) { _, running in
            running ? .impact(weight: .heavy) : .impact(weight: .light)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .overlay(alignment: .bottomTrailing) {
            if showsStopped {
                Button("They've stopped") { labour.markStopped() }
                    .font(MissionType.body(13).weight(.semibold))
                    // Cream, not the prototype's lilac: lilac over the Earth's blue is under 4.5:1.
                    .foregroundStyle(LabourTheme.cream)
                    .underline()
                    .frame(minHeight: LabourTheme.chipSize)
                    .padding(.trailing, 18)
                    .accessibilityHint("Tells the app the contractions have stopped. Undo is available.")
            }
        }
    }

    private var flags: some View {
        let active = labour.log.activeRedFlags
        let others = RedFlagLayout.others
        let othersOn = others.filter(active.contains).count
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(RedFlagLayout.pinned, id: \.self) { flag in
                    FlagToggle(flag: flag, isOn: active.contains(flag)) { toggle(flag, active: active) }
                }
                Button {
                    withAnimation { showsAllFlags.toggle() }
                } label: {
                    Text(showsAllFlags ? "Fewer" : (othersOn > 0 ? "More · \(othersOn) on" : "More"))
                        .font(MissionType.body(13.5).weight(.semibold))
                        .foregroundStyle(LabourTheme.cream)
                        .padding(.leading, 12)
                        .padding(.trailing, 10)
                        .frame(minHeight: LabourTheme.minimumControlSize)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(FlagToggle.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    othersOn > 0 ? LabourTheme.signal : LabourTheme.cream.opacity(0.3), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel(showsAllFlags ? "Fewer red flags" : "More red flags")
                .accessibilityValue(othersOn > 0 ? "\(othersOn) on" : "")
            }
            if showsAllFlags {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(others, id: \.self) { flag in
                        FlagToggle(flag: flag, isOn: active.contains(flag)) { toggle(flag, active: active) }
                    }
                }
            }
        }
        .confirmationDialog(
            "Turn off “\(confirmingOff?.label ?? "")”?",
            isPresented: Binding(get: { confirmingOff != nil }, set: { if !$0 { confirmingOff = nil } }),
            titleVisibility: .visible, presenting: confirmingOff
        ) { flag in
            Button("Turn it off", role: .destructive) { labour.setRedFlag(flag, isOn: false) }
            Button("Keep it on", role: .cancel) {}
        } message: { flag in
            Text(
                flag.state == .call999
                    ? "Only if it was tapped by mistake. 999 stays on screen for a minute in case."
                    : "Only if it was tapped by mistake. It stays in the call script either way."
            )
        }
    }

    /// On at once; off only after "Turn it off", so one stray tap can't lower the advice.
    private func toggle(_ flag: RedFlag, active: Set<RedFlag>) {
        if active.contains(flag) {
            confirmingOff = flag
        } else {
            confirmingOff = nil
            labour.setRedFlag(flag, isOn: true)
        }
    }
}

/// A red-flag switch, as in the prototype: the words, and a small switch that slides across when
/// it's on. On, it fills with the darker red so the cream words stay readable.
struct FlagToggle: View {
    var flag: RedFlag
    var isOn: Bool
    var action: () -> Void

    /// The prototype's rgba(14, 20, 51, 0.7) behind an unlit flag.
    static let surface = Color(red: 14 / 255, green: 20 / 255, blue: 51 / 255).opacity(0.7)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(flag.label)
                        .font(MissionType.body(13.5).weight(.semibold))
                    if let detail = flag.detail {
                        Text(detail)
                            .font(MissionType.body(12, relativeTo: .caption))
                            .opacity(isOn ? 1 : 0.85)
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Capsule()
                    .fill(isOn ? Color(red: 9 / 255, green: 13 / 255, blue: 36 / 255).opacity(0.45) : switchOff)
                    .frame(width: 30, height: 18)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle().fill(LabourTheme.cream).frame(width: 14, height: 14).padding(2)
                    }
                    .accessibilityHidden(true)
            }
            .foregroundStyle(LabourTheme.cream)
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(isOn ? LabourTheme.hot : Self.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isOn ? LabourTheme.hot : LabourTheme.signal.opacity(0.55), lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.warning, trigger: isOn) { _, turnedOn in turnedOn }
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint(isOn ? "Asks before turning it off" : "")
    }

    private var switchOff: Color { LabourTheme.cream.opacity(0.18) }
}

/// The call button inside the advice: the booked unit's triage line from "time to call", 999
/// at 999. Every one dials; in a practice run each shows the number and dials nothing.
private struct AdviceCall: View {
    @Environment(AppModel.self) private var model
    @Environment(\.missionMode) private var mode
    var state: LabourState

    var body: some View {
        let region = model.labour.region
        let style: DialFace.Style = mode == .practice ? .practice : (state >= .callNow ? .hot : .warm)
        if state == .call999 {
            let number = StateCopy.emergencyNumber(region)
            if mode == .practice {
                DialFace(title: "Call \(number)", detail: "In a real labour this rings \(number)", style: style)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Practice. Call \(number). In a real labour this rings \(number).")
            } else if let url = EmergencyDial.url(region) {
                Link(destination: url) {
                    DialFace(title: "Call \(number)", detail: "Then your maternity unit. Stay with her.", style: style)
                }
                .accessibilityLabel("Call \(number)")
            }
        } else if let place = model.bookedPlace, let number = place.triageNumber(region: region) {
            let name = place.displayName
            // "01632 960118 · then press 2", as the prototype writes it.
            let then = number.afterConnecting.map { $0.prefix(1).lowercased() + $0.dropFirst() }
            let detail = [number.display, then].compactMap { $0 }.joined(separator: " · ")
            if mode == .practice {
                DialFace(title: "Call \(name)", detail: "In a real labour this rings \(number.display)", style: style)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Practice. Call \(name). In a real labour this rings \(number.display).")
            } else if let url = number.telURL {
                Link(destination: url) {
                    DialFace(title: "Call \(name)", detail: detail, style: style)
                }
                .accessibilityLabel("Call \(name), \(number.display)")
            }
        } else {
            NoNumberCard()
        }
    }
}

/// Where the unit's button would be, with no triage number saved: the Call tab has 111 and 999.
private struct NoNumberCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No triage number saved")
                .font(MissionType.body(15).weight(.bold))
            Text("The Call tab has NHS 111, 999 and what to say.")
                .font(MissionType.body(13.5))
        }
        .foregroundStyle(LabourTheme.paperInk)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LabourTheme.cream))
        .accessibilityElement(children: .combine)
    }
}

/// The current rate, the same numbers the call rule uses: a range when the gaps are uneven, and
/// never rounded across the call point ("5:20", not "5 min").
private func every(_ metrics: ContractionMetrics, _ thresholds: ThresholdProfile) -> String {
    let limit = thresholds.adviceIntervalSec
    if StateCopy.isUneven(metrics, thresholds), let shortest = metrics.recentShortestIntervalSec,
        let longest = metrics.recentLongestIntervalSec
    {
        return StateCopy.clockRange(shortest, longest, threshold: limit)
    }
    return (metrics.recentMedianIntervalSec ?? metrics.medianIntervalSec).map {
        StateCopy.clock($0, threshold: limit)
    } ?? "–"
}

/// The undo bar for 10 seconds after any tap, or a short note such as "Ignored a double tap".
private struct UndoArea: View {
    @Environment(AppModel.self) private var model
    var now: Date

    var body: some View {
        Group {
            if let undoable = model.labour.undoable, undoable.expiresAt > now {
                UndoBar(text: Self.text(for: undoable.label)) { model.labour.undo() }
                    .transition(.opacity)
            } else if let notice = model.labour.notice, notice.until > now {
                Text(notice.text)
                    .font(MissionType.body(14).weight(.semibold))
                    .foregroundStyle(LabourTheme.paperInk)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LabourTheme.cream))
                    // A note takes no taps: they go through to the button.
                    .allowsHitTesting(false)
            }
        }
    }

    /// What was just done, in the prototype's words: "Contraction started".
    static func text(for label: String) -> String {
        switch label {
        case "start": "Contraction started"
        case "stop": "Contraction stopped"
        case "they've stopped": "Marked as stopped"
        case "flag": "Red flag on"
        case "flag off": "Red flag off"
        case "movement": "Movement logged"
        case "waters time": "Waters time saved"
        case "answer": "Answer saved"
        case "call": "Call logged"
        case "delete": "Contraction deleted"
        case "merge": "Contractions merged"
        default: "Contraction changed"
        }
    }
}

/// "How strong was that one?" for 20 seconds after a stop. Triage asks how strong they are.
private struct StrengthQuestion: View {
    @Environment(AppModel.self) private var model
    var now: Date

    var body: some View {
        if let stopped = model.labour.justStopped, stopped.until > now {
            NoticeAsk(
                title: "How strong was that one?",
                detail: "Triage will ask.",
                choices: ContractionStrength.allCases.map { strength in
                    (strength.label, { model.labour.rateLast(strength) })
                }
            )
            .transition(.opacity)
        }
    }
}
