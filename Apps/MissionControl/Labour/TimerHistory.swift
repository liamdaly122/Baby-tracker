import MissionCore
import MissionUI
import SwiftUI

/// Contraction history, newest first, with "Baby moved". Tap a row to fix it in place.
struct HistoryList: View {
    @Environment(AppModel.self) private var model
    @Binding var expandedRow: UUID?

    var body: some View {
        let contractions = model.labour.log.contractions
        let needsEdit = Set(model.labour.output?.metrics.needsEdit ?? [])
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(contractions.isEmpty ? "LOG" : "LOG · TAP ONE TO FIX IT")
                    .font(MissionType.mono())
                    .tracking(MissionType.monoTracking())
                    .foregroundStyle(LabourTheme.muted)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button {
                    model.labour.logMovement()
                } label: {
                    Label("Baby moved", systemImage: "hand.wave")
                        .font(MissionType.body(13.5).weight(.semibold))
                        .foregroundStyle(LabourTheme.cream)
                        .padding(.horizontal, 12)
                        .frame(minHeight: LabourTheme.chipSize)
                        .overlay(Capsule().strokeBorder(LabourTheme.cream.opacity(0.4), lineWidth: 1.5))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
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
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(FlagToggle.surface))
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
                    Text("Lasted about").foregroundStyle(LabourTheme.muted)
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
        .font(MissionType.body(15))
        .padding(.vertical, 10)
    }

    private func stepperRow(_ title: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .foregroundStyle(LabourTheme.muted)
                .frame(minWidth: 48, alignment: .leading)
            editButton("−1 min", action: minus)
            editButton("+1 min", action: plus)
        }
    }

    private func editButton(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Text(title)
                .font(MissionType.body(14).weight(.semibold))
                .padding(.horizontal, 14)
                .frame(minHeight: LabourTheme.chipSize)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(LabourTheme.levelChip))
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? LabourPalette.callAccent.color : LabourTheme.cream)
        .sensoryFeedback(.selection, trigger: contraction)
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
