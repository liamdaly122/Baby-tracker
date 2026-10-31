import MissionCore
import MissionUI
import SwiftUI
import UIKit

/// The timer: advice at the top, the big button at the bottom, history below (scroll up).
struct TimerTab: View {
    @Environment(AppModel.self) private var model
    @Environment(\.missionMode) private var mode
    @State private var bannerExpanded = false
    @State private var showsEmergency = false
    @State private var showsAllFlags = false
    /// A lit flag he tapped: turning it off needs a second, deliberate tap.
    @State private var confirmingOff: RedFlag?
    @State private var expandedRow: UUID?

    private var labour: LabourSessionModel { model.labour }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 14) {
                    controls(height: geometry.size.height)
                    HistoryList(expandedRow: $expandedRow)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(LabourTheme.background)
    }

    private func controls(height: CGFloat) -> some View {
        VStack(spacing: 14) {
            if mode == .practice, let drill = model.drill {
                DrillGuideCard(drill: drill)
            }
            banner
            if labour.output?.state == .call999 || showsEmergency {
                EmergencyCallButton(region: labour.region)
            }
            LabourPrompts()
            StatsRow()
            flags
            Spacer(minLength: 0)
            UndoArea()
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                StartStopButton(
                    isRunning: labour.openContraction != nil,
                    elapsed: labour.openContraction.map { labour.currentTime.timeIntervalSince($0.start) }
                ) {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    labour.tap()
                }
            }
            // A little shorter in a practice run, to make room for the drill's guide.
            .frame(height: mode == .practice ? max(150, height * 0.28) : max(180, height * 0.34))
            StrengthRow()
            HStack {
                Label("History below", systemImage: "chevron.compact.up")
                    .font(.footnote)
                    .foregroundStyle(LabourTheme.secondaryText)
                    .labelStyle(.titleAndIcon)
                Spacer()
                if !labour.log.contractions.isEmpty, labour.openContraction == nil,
                    labour.output?.reasons.contains(.contractionsStopped) != true
                {
                    Button("They've stopped") { labour.markStopped() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LabourTheme.secondaryText)
                        .underline()
                        .frame(minHeight: 44)
                        .accessibilityHint("Tells the app the contractions have stopped. Undo is available.")
                }
            }
        }
        .padding(.top, 8)
        .frame(minHeight: height - 8)
    }

    @ViewBuilder private var banner: some View {
        if let output = labour.output {
            let thresholds = output.thresholds
            StateBanner(
                state: output.state,
                headline: StateCopy.headline(for: output, region: labour.region),
                detail: StateCopy.detail(for: output, region: labour.region, thresholds: thresholds),
                reasonLines: output.reasons.filter { $0 != .noRecentTaps }.map {
                    StateCopy.reasonLine(
                        for: $0, metrics: output.metrics, thresholds: thresholds, now: output.evaluatedAt)
                } + contractionLine(output),
                source: output.reasons.first.map { StateCopy.source(for: $0, region: labour.region).title },
                isExpanded: bannerExpanded
            )
            .onTapGesture { withAnimation { bannerExpanded.toggle() } }
            .onLongPressGesture { withAnimation { showsEmergency = true } }
            .accessibilityHint("Tap for more detail. Long-press to show the emergency call button.")
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

    private var flags: some View {
        let active = labour.log.activeRedFlags
        let pinned: [RedFlag] = [.reducedMovements, .watersBroken]
        let others = RedFlag.allCases.filter { !pinned.contains($0) }
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(pinned, id: \.self) { flag in
                    FlagButton(flag: flag, isOn: active.contains(flag)) { toggle(flag, active: active) }
                }
            }
            HStack(spacing: 10) {
                Button {
                    labour.logMovement()
                } label: {
                    Label("Baby moved", systemImage: "hand.wave.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LabourTheme.surface))
                }
                .buttonStyle(.plain)
                .foregroundStyle(LabourTheme.primaryText)
                Button {
                    withAnimation { showsAllFlags.toggle() }
                } label: {
                    let otherOn = others.filter(active.contains).count
                    Label(
                        showsAllFlags ? "Fewer" : (otherOn > 0 ? "More (\(otherOn) on)" : "More red flags"),
                        systemImage: showsAllFlags ? "chevron.up" : "exclamationmark.triangle"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LabourTheme.surface))
                }
                .buttonStyle(.plain)
                .foregroundStyle(others.contains(where: active.contains) ? LabourTheme.urgent : LabourTheme.primaryText)
            }
            if showsAllFlags {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10
                ) {
                    ForEach(others, id: \.self) { flag in
                        FlagButton(flag: flag, isOn: active.contains(flag)) { toggle(flag, active: active) }
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

/// A red-flag toggle. Filled when on.
private struct FlagButton: View {
    var flag: RedFlag
    var isOn: Bool
    var action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(flag.label)
                        .font(.subheadline.weight(.semibold))
                    if let detail = flag.detail {
                        Text(detail)
                            .font(.caption)
                            .opacity(0.85)
                    }
                }
            } icon: {
                Image(systemName: isOn ? "checkmark.circle.fill" : flag.icon)
            }
            .multilineTextAlignment(.leading)
            .foregroundStyle(isOn ? Color.white : LabourTheme.primaryText)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isOn ? LabourTheme.color(for: flag.state) : LabourTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(LabourTheme.color(for: flag.state).opacity(isOn ? 0 : 0.6), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint(isOn ? "Asks before turning it off" : "")
    }
}

/// Since last, typical interval and length, and how many in the last hour.
private struct StatsRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let labour = model.labour
            let now = labour.currentTime
            let metrics = labour.output?.metrics
            let lastHour = labour.log.contractions.filter { now.timeIntervalSince($0.start) <= 3600 }.count
            HStack(spacing: 8) {
                StatTile(
                    label: "Since last",
                    value: metrics?.lastStart.map { clockText(now.timeIntervalSince($0)) } ?? "–"
                )
                StatTile(label: "Every", value: metrics.map { every($0, labour.thresholds) } ?? "–")
                StatTile(label: "Lasting", value: metrics?.medianDurationSec.map { "\(Int($0.rounded()))s" } ?? "–")
                StatTile(label: "Last hour", value: "\(lastHour)")
            }
        }
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

/// The undo chip for 10 seconds after any tap, or a short note such as "Ignored a double tap".
private struct UndoArea: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let now = model.labour.currentTime
            if let undoable = model.labour.undoable, undoable.expiresAt > now {
                UndoChip(label: undoable.label) { model.labour.undo() }
                    .transition(.opacity)
            } else if let notice = model.labour.notice, notice.until > now {
                Text(notice.text)
                    .font(.headline)
                    .foregroundStyle(LabourTheme.secondaryText)
                    .frame(minHeight: LabourTheme.minimumControlSize)
            } else {
                Color.clear.frame(height: LabourTheme.minimumControlSize)
            }
        }
    }
}

/// Contraction history, newest first. Tap a row to fix it in place.
private struct HistoryList: View {
    @Environment(AppModel.self) private var model
    @Binding var expandedRow: UUID?

    var body: some View {
        let contractions = model.labour.log.contractions
        let needsEdit = Set(model.labour.output?.metrics.needsEdit ?? [])
        VStack(alignment: .leading, spacing: 4) {
            Text(contractions.isEmpty ? "No contractions timed yet" : "History")
                .font(.headline)
                .foregroundStyle(LabourTheme.secondaryText)
                .padding(.vertical, 8)
            ForEach(Array(contractions.enumerated()).reversed(), id: \.element.id) { index, contraction in
                let previous = index > 0 ? contractions[index - 1] : nil
                VStack(spacing: 0) {
                    Button {
                        withAnimation { expandedRow = expandedRow == contraction.id ? nil : contraction.id }
                    } label: {
                        ContractionRow(
                            number: index + 1,
                            startText: contraction.start.formatted(date: .omitted, time: .shortened),
                            durationText: durationText(contraction, isLast: index == contractions.count - 1),
                            intervalText: previous.map {
                                "every \(clockText(contraction.start.timeIntervalSince($0.start)))"
                            },
                            needsEdit: needsEdit.contains(contraction.id)
                        )
                    }
                    .buttonStyle(.plain)
                    if expandedRow == contraction.id {
                        RowEditor(contraction: contraction, isLast: index == contractions.count - 1)
                    }
                }
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LabourTheme.surface))
            }
        }
    }

    private func durationText(_ contraction: Contraction, isLast: Bool) -> String {
        if let end = contraction.end {
            return end >= contraction.start ? clockText(end.timeIntervalSince(contraction.start)) : "check"
        }
        return isLast ? "timing" : "no stop"
    }
}

/// Inline fixes for one contraction: nudge the start or end by a minute, merge or delete.
private struct RowEditor: View {
    @Environment(AppModel.self) private var model
    var contraction: Contraction
    var isLast: Bool

    var body: some View {
        let labour = model.labour
        VStack(alignment: .leading, spacing: 10) {
            stepperRow(
                "Start",
                minus: { labour.moveStart(of: contraction, byMinutes: -1) },
                plus: { labour.moveStart(of: contraction, byMinutes: 1) }
            )
            if contraction.end != nil {
                stepperRow(
                    "End",
                    minus: { labour.moveEnd(of: contraction, byMinutes: -1) },
                    plus: { labour.moveEnd(of: contraction, byMinutes: 1) }
                )
            } else if !isLast {
                HStack(spacing: 8) {
                    Text("Lasted about").foregroundStyle(LabourTheme.secondaryText)
                    ForEach([30, 60, 90], id: \.self) { seconds in
                        editButton("\(seconds)s") { labour.close(contraction.id, afterSeconds: Double(seconds)) }
                    }
                }
            }
            HStack(spacing: 8) {
                if labour.canMergeWithPrevious(contraction) {
                    editButton("Merge with previous") { labour.mergeWithPrevious(contraction) }
                }
                editButton("Delete", role: .destructive) { labour.delete(contraction) }
            }
        }
        .padding(.vertical, 10)
    }

    private func stepperRow(_ title: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .foregroundStyle(LabourTheme.secondaryText)
                .frame(minWidth: 48, alignment: .leading)
            editButton("−1 min", action: minus)
            editButton("+1 min", action: plus)
        }
    }

    private func editButton(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(LabourTheme.raisedSurface))
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? LabourTheme.urgent : LabourTheme.primaryText)
    }
}

/// "How strong was that one?" for 20 seconds after a stop. Triage asks how strong they are.
private struct StrengthRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            if let stopped = model.labour.justStopped, stopped.until > model.labour.currentTime {
                HStack(spacing: 8) {
                    Text("How strong?")
                        .font(.subheadline)
                        .foregroundStyle(LabourTheme.secondaryText)
                    ForEach(ContractionStrength.allCases, id: \.self) { strength in
                        Button {
                            model.labour.rateLast(strength)
                        } label: {
                            Text(strength.label)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .frame(minHeight: 44)
                                .background(Capsule().fill(LabourTheme.surface))
                                .foregroundStyle(LabourTheme.primaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

extension ContractionStrength {
    var label: String {
        switch self {
        case .mild: "Mild"
        case .moderate: "Moderate"
        case .strong: "Strong"
        }
    }
}
