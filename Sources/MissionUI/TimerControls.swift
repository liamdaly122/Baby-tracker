import MissionCore
import SwiftUI

/// "Contraction started · Undo" for 10 seconds after any tap, because mis-taps happen in the dark.
/// The prototype's cream bar. Only "Undo" takes a tap: a tap anywhere else goes through.
public struct UndoBar: View {
    public var text: String
    public var action: () -> Void

    public init(text: String, action: @escaping () -> Void) {
        self.text = text
        self.action = action
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text(text)
                .font(MissionType.body(14).weight(.semibold))
                .foregroundStyle(LabourTheme.paperInk)
                .fixedSize(horizontal: false, vertical: true)
                .allowsHitTesting(false)
            Spacer(minLength: 0)
            Button(action: action) {
                Text("Undo")
                    .font(MissionType.body(14).weight(.semibold))
                    .foregroundStyle(LabourTheme.cream)
                    .padding(.horizontal, 16)
                    .frame(minHeight: LabourTheme.chipSize)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LabourTheme.paperInk))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Undo: \(text)")
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .frame(minHeight: LabourTheme.minimumControlSize)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LabourTheme.cream).allowsHitTesting(false)
        )
        .accessibilityElement(children: .contain)
    }
}

/// The three numbers under the trace, in the display face, split by thin rules.
public struct StatsStrip: View {
    public var items: [(value: String, label: String)]

    public init(_ items: [(value: String, label: String)]) {
        self.items = items
    }

    public var body: some View {
        // Three across, as in the prototype; one under another at big text sizes.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 0) {
                        if index > 0 {
                            Rectangle().fill(LabourTheme.cream.opacity(0.16)).frame(width: 1.5)
                                .padding(.trailing, 12)
                        }
                        column(item)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    column(item)
                }
            }
        }
    }

    private func column(_ item: (value: String, label: String)) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.value)
                .font(MissionType.display(34, relativeTo: .title))
                .monospacedDigit()
                .foregroundStyle(LabourTheme.cream)
                .lineLimit(1)
                .fixedSize()
                // The prototype sets these numbers at 0.9 line height; League Gothic's own is looser.
                .padding(.vertical, -4)
            Text(item.label.uppercased())
                .font(MissionType.mono())
                .foregroundStyle(LabourTheme.muted)
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.label): \(item.value)")
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
                .font(MissionType.mono())
                .foregroundStyle(LabourTheme.muted)
                .frame(minWidth: 40, alignment: .leading)
            Text(startText)
                .font(MissionType.body(16).monospacedDigit())
                .foregroundStyle(LabourTheme.cream)
            Spacer(minLength: 8)
            Text(durationText)
                .font(MissionType.body(16).weight(.semibold).monospacedDigit())
                .foregroundStyle(needsEdit ? LabourTheme.sun : LabourTheme.cream)
            if let intervalText {
                Text(intervalText)
                    .font(MissionType.body(14).monospacedDigit())
                    .foregroundStyle(LabourTheme.muted)
                    .frame(minWidth: 64, alignment: .trailing)
            }
            if needsEdit {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(LabourTheme.sun)
                    .accessibilityLabel("Needs fixing")
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
