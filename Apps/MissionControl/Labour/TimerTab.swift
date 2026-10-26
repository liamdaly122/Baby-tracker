import MissionCore
import MissionUI
import SwiftUI
import UIKit

/// The timer: advice at the top, the big button at the bottom, history below (scroll up).
struct TimerTab: View {
    @Environment(AppModel.self) private var model
    @State private var bannerExpanded = false
    @State private var showsEmergency = false
    @State private var showsAllFlags = false
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
            banner
            if labour.output?.state == .call999 || showsEmergency {
                EmergencyCallButton(region: labour.region)
            }
            StatsRow()
            flags
            Spacer(minLength: 0)
            UndoArea()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                StartStopButton(
                    isRunning: labour.openContraction != nil,
                    elapsed: labour.openContraction.map { context.date.timeIntervalSince($0.start) }
                ) {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    labour.toggleContraction()
                }
            }
            .frame(height: max(180, height * 0.34))
            Label("History below", systemImage: "chevron.compact.up")
                .font(.footnote)
                .foregroundStyle(LabourTheme.secondaryText)
                .labelStyle(.titleAndIcon)
        }
        .padding(.top, 8)
        .frame(minHeight: height - 8)
    }

    @ViewBuilder private var banner: some View {
        if let output = labour.output {
            let thresholds = labour.thresholds
            StateBanner(
                state: output.state,
                headline: StateCopy.headline(for: output.state, region: labour.region),
                detail: StateCopy.detail(for: output.state, region: labour.region, thresholds: thresholds),
                reasonLines: output.reasons.map {
                    StateCopy.reasonLine(for: $0, metrics: output.metrics, thresholds: thresholds)
                },
                source: output.reasons.first.map { StateCopy.source(for: $0, region: labour.region).title },
                isExpanded: bannerExpanded
            )
            .onTapGesture { withAnimation { bannerExpanded.toggle() } }
            .onLongPressGesture { withAnimation { showsEmergency = true } }
            .accessibilityHint("Tap for more detail. Long-press to show the emergency call button.")
        }
    }

    private var flags: some View {
        let active = labour.log.activeRedFlags
        let pinned: [RedFlag] = [.reducedMovements, .watersBroken]
        let others = RedFlag.allCases.filter { !pinned.contains($0) }
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(pinned, id: \.self) { flag in
                    FlagButton(flag: flag, isOn: active.contains(flag)) {
                        labour.setRedFlag(flag, isOn: !active.contains(flag))
                    }
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
                        FlagButton(flag: flag, isOn: active.contains(flag)) {
                            labour.setRedFlag(flag, isOn: !active.contains(flag))
                        }
                    }
                }
            }
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
            Label(flag.label, systemImage: isOn ? "checkmark.circle.fill" : flag.icon)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)
                .foregroundStyle(isOn ? Color.white : LabourTheme.primaryText)
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
    }
}

/// Since last, typical interval and length, and how many in the last hour.
private struct StatsRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let labour = model.labour
            let metrics = labour.output?.metrics
            let lastHour = labour.log.contractions.filter { context.date.timeIntervalSince($0.start) <= 3600 }.count
            HStack(spacing: 8) {
                StatTile(
                    label: "Since last",
                    value: metrics?.lastStart.map { clockText(context.date.timeIntervalSince($0)) } ?? "–"
                )
                StatTile(label: "Every", value: metrics?.medianIntervalSec.map(clockText) ?? "–")
                StatTile(label: "Lasting", value: metrics?.medianDurationSec.map { "\(Int($0.rounded()))s" } ?? "–")
                StatTile(label: "Last hour", value: "\(lastHour)")
            }
        }
    }
}

/// The undo chip for 10 seconds after any tap.
private struct UndoArea: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let undoable = model.labour.undoable, undoable.expiresAt > context.date {
                UndoChip(label: undoable.label) { model.labour.undo() }
                    .transition(.opacity)
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
            stepperRow("Start", minus: { labour.moveStart(of: contraction, byMinutes: -1) }) {
                labour.moveStart(of: contraction, byMinutes: 1)
            }
            if contraction.end != nil {
                stepperRow("End", minus: { labour.moveEnd(of: contraction, byMinutes: -1) }) {
                    labour.moveEnd(of: contraction, byMinutes: 1)
                }
            } else if !isLast {
                HStack(spacing: 8) {
                    Text("Lasted about").foregroundStyle(LabourTheme.secondaryText)
                    ForEach([30, 60, 90], id: \.self) { seconds in
                        editButton("\(seconds)s") { labour.close(contraction, afterSeconds: Double(seconds)) }
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
