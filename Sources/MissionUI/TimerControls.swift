import MissionCore
import SwiftUI

/// The giant start/stop control. One thumb, no precision needed.
public struct StartStopButton: View {
    public var isRunning: Bool
    /// Seconds into the current contraction, shown while running.
    public var elapsed: TimeInterval?
    public var action: () -> Void

    public init(isRunning: Bool, elapsed: TimeInterval?, action: @escaping () -> Void) {
        self.isRunning = isRunning
        self.elapsed = elapsed
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(isRunning ? "STOP" : "START")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.6)
                Text(isRunning ? "Contraction \(clockText(elapsed ?? 0))" : "Tap when a contraction starts")
                    .font(.headline.monospacedDigit())
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isRunning ? Color.black : LabourTheme.amber)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: LabourTheme.minimumControlSize * 2)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(isRunning ? LabourTheme.amber : LabourTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(LabourTheme.amber, lineWidth: 3)
            )
            .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRunning ? "Stop contraction" : "Start contraction")
        .accessibilityValue(isRunning ? "Running for \(clockText(elapsed ?? 0))" : "")
    }
}

/// "Undo" for 10 seconds after any tap, because mis-taps happen in the dark.
public struct UndoChip: View {
    public var label: String
    public var action: () -> Void

    public init(label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label("Undo \(label)", systemImage: "arrow.uturn.backward")
                .font(.headline)
                .foregroundStyle(LabourTheme.primaryText)
                .padding(.horizontal, 20)
                .frame(minHeight: LabourTheme.minimumControlSize)
                .background(Capsule().fill(LabourTheme.raisedSurface))
                .overlay(Capsule().strokeBorder(LabourTheme.secondaryText.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// A small labelled figure, e.g. "Every · 4 min".
public struct StatTile: View {
    public var label: String
    public var value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }

    public var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(LabourTheme.primaryText)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(LabourTheme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LabourTheme.surface))
        .accessibilityElement(children: .combine)
    }
}

/// One line of contraction history.
public struct ContractionRow: View {
    public var number: Int
    public var startText: String
    public var durationText: String
    public var intervalText: String?
    public var needsEdit: Bool

    public init(number: Int, startText: String, durationText: String, intervalText: String?, needsEdit: Bool) {
        self.number = number
        self.startText = startText
        self.durationText = durationText
        self.intervalText = intervalText
        self.needsEdit = needsEdit
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text("#\(number)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(LabourTheme.secondaryText)
                .frame(minWidth: 40, alignment: .leading)
            Text(startText)
                .font(.body.monospacedDigit())
                .foregroundStyle(LabourTheme.primaryText)
            Spacer(minLength: 8)
            Text(durationText)
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(needsEdit ? LabourTheme.urgent : LabourTheme.primaryText)
            if let intervalText {
                Text(intervalText)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(LabourTheme.secondaryText)
                    .frame(minWidth: 64, alignment: .trailing)
            }
            if needsEdit {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(LabourTheme.urgent)
                    .accessibilityLabel("Needs fixing")
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}
