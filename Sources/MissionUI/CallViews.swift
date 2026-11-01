import MissionCore
import SwiftUI

#if os(iOS)
    import UIKit
#endif

/// The Call tab's pieces, as the agreed prototype (v3) draws them on its oxblood "comms" panel:
/// plates for the unit and 999, small call buttons, the "If nobody answers" ladder, the notepad
/// script and plain sections with a rule above. Every call control dials through
/// `PhoneNumber.telURL`; in a practice run each shows the number and dials nothing.
public enum CallLook {
    /// The plate behind the unit: the prototype's #3A1310 with a red edge.
    public static let plate = LabourPalette.callSurface.color
    /// Labels on the comms panel: the prototype's #FF9C8A.
    public static let label = LabourPalette.callAccent.color
    /// The prototype's thin rules between rows.
    public static let rule = LabourTheme.cream.opacity(0.14)
}

/// A panel for the unit or for 999. 999's is red, with the darker red the cream text needs.
public struct CallPlate<Content: View>: View {
    public var isEmergency: Bool
    public var label: String
    public var title: String?
    public var content: Content

    public init(isEmergency: Bool = false, label: String, title: String? = nil, @ViewBuilder content: () -> Content) {
        self.isEmergency = isEmergency
        self.label = label
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(MissionType.mono())
                .tracking(MissionType.monoTracking())
                .foregroundStyle(isEmergency ? LabourTheme.cream : CallLook.label)
                .fixedSize(horizontal: false, vertical: true)
            if let title {
                Text(title)
                    .font(MissionType.display(30, relativeTo: .title))
                    .tracking(0.6)
                    .foregroundStyle(LabourTheme.cream)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isEmergency ? LabourTheme.hot : CallLook.plate)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isEmergency ? LabourTheme.hot : LabourTheme.signal.opacity(0.55), lineWidth: 1.5)
        )
        .accessibilityElement(children: .contain)
    }
}

/// A note on a plate, such as "Have her notes ready when they answer."
public struct PlateNote: View {
    public var text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(MissionType.body(13, relativeTo: .footnote))
            .lineSpacing(2)
            .foregroundStyle(LabourTheme.cream.opacity(0.75))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The big call button: dials in real labour, shows what it would ring in a practice run.
public struct BigDial: View {
    public var number: PhoneNumber
    public var title: String
    public var detail: String?
    /// `.warm` or `.hot`. A practice run always draws `.practice`.
    public var style: DialFace.Style
    @Environment(\.missionMode) private var mode

    public init(number: PhoneNumber, title: String, detail: String?, style: DialFace.Style = .hot) {
        self.number = number
        self.title = title
        self.detail = detail
        self.style = style
    }

    public var body: some View {
        if mode == .practice {
            DialFace(title: title, detail: "In a real labour this rings \(number.display)", style: .practice)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Practice. \(title). In a real labour this rings \(number.display).")
        } else if let url = number.telURL {
            Link(destination: url) {
                DialFace(title: title, detail: detail, style: style)
            }
            .accessibilityLabel("\(title), \(number.display)")
        }
    }
}

/// The prototype's small call button: a phone, and the number (or "Call" over the number) in the
/// display face on a faint cream fill.
public struct SmallDial: View {
    public var number: PhoneNumber
    /// "Call" above the number for a person; nil shows the number alone.
    public var title: String?
    public var accessibilityName: String?
    @Environment(\.missionMode) private var mode

    public init(number: PhoneNumber, title: String? = nil, accessibilityName: String? = nil) {
        self.number = number
        self.title = title
        self.accessibilityName = accessibilityName
    }

    public var body: some View {
        let name = accessibilityName.map { "Call \($0), \(number.display)" } ?? "Call \(number.display)"
        if mode == .practice {
            face(practice: true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Practice. In a real labour this rings \(number.display).")
        } else if let url = number.telURL {
            Link(destination: url) { face(practice: false) }
                .accessibilityLabel(name)
        }
    }

    private func face(practice: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: practice ? "phone" : "phone.fill")
                .font(.system(size: 15, weight: .semibold))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(title ?? number.display)
                    .font(MissionType.display(22, relativeTo: .title3))
                    .tracking(0.5)
                    .lineLimit(1)
                    .fixedSize()
                if title != nil {
                    Text(number.display)
                        .font(MissionType.mono())
                        .lineLimit(1)
                        .fixedSize()
                        .opacity(0.8)
                }
            }
        }
        .foregroundStyle(practice ? LabourTheme.simInk : LabourTheme.cream)
        .padding(.horizontal, 12)
        .frame(minHeight: LabourTheme.chipSize)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(practice ? LabourTheme.simDeep : LabourTheme.cream.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    practice ? LabourTheme.sim : LabourTheme.cream.opacity(0.3),
                    style: StrokeStyle(lineWidth: 1.5, dash: practice ? [5, 3] : []))
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#if os(iOS)
    /// The number as text with "Copy" beside it, under the big button, and what to press after
    /// connecting. Copying is extra: the button above dials.
    public struct NumberRow: View {
        public var number: PhoneNumber
        @State private var copied = false

        public init(number: PhoneNumber) {
            self.number = number
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(number.display)
                        .font(MissionType.mono(13, relativeTo: .footnote))
                        .foregroundStyle(LabourTheme.cream)
                        .textSelection(.enabled)
                    Button(copied ? "Copied" : "Copy") {
                        UIPasteboard.general.string = number.display
                        copied = true
                    }
                    .font(MissionType.body(13, relativeTo: .footnote).weight(.semibold))
                    .underline()
                    .foregroundStyle(Self.copyInk)
                    .frame(minWidth: LabourTheme.chipSize, minHeight: LabourTheme.chipSize)
                    .accessibilityLabel(copied ? "Copied \(number.display)" : "Copy \(number.display)")
                }
                if let after = number.afterConnecting {
                    Text(after)
                        .font(MissionType.mono())
                        .foregroundStyle(LabourTheme.cream.opacity(0.75))
                }
            }
            .task(id: copied) {
                guard copied else { return }
                try? await Task.sleep(for: .seconds(2))
                copied = false
            }
        }

        /// The prototype's #FFC4B8 for "Copy" on the plate.
        static let copyInk = PaletteColor(hex: 0xFFC4B8).color
    }
#endif

/// A section of the comms panel: a small red-orange heading under a thin rule.
public struct CommsSection<Content: View>: View {
    public var title: String
    public var content: Content

    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(MissionType.mono())
                .tracking(MissionType.monoTracking())
                .foregroundStyle(CallLook.label)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 2)
        .overlay(alignment: .top) { Rectangle().fill(CallLook.rule).frame(height: 1) }
    }
}

/// "If nobody answers": the numbered ladder to work down, each rung with its own call button.
public struct FallbackLadder: View {
    public var steps: [CallStep]
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(steps: [CallStep]) {
        self.steps = steps
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("IF NOBODY ANSWERS")
                .font(MissionType.mono())
                .tracking(MissionType.monoTracking())
                .foregroundStyle(CallLook.label)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element) { index, step in
                    rung(index + 1, step)
                }
            }
            Text("Source: \(CallFallback.source.title)".uppercased())
                .font(MissionType.mono())
                .foregroundStyle(LabourTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Can't get through? Work down this list.")
    }

    /// The words, with the call button beside them, or under them at the biggest text sizes.
    private func rung(_ number: Int, _ step: CallStep) -> some View {
        let words = HStack(alignment: .center, spacing: 10) {
            Text("\(number)")
                .font(MissionType.mono())
                .foregroundStyle(CallLook.label)
                .padding(4)
                .frame(minWidth: 24, minHeight: 24)
                .overlay(Circle().strokeBorder(LabourTheme.signal, lineWidth: 1.5))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(MissionType.body(14.5).weight(.semibold))
                    .foregroundStyle(LabourTheme.cream)
                Text(step.detail)
                    .font(MissionType.body(12.5, relativeTo: .footnote))
                    .foregroundStyle(LabourTheme.muted)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        return Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    words
                    if let phone = step.number {
                        SmallDial(number: phone, accessibilityName: step.title)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    words
                    if let phone = step.number {
                        SmallDial(number: phone, accessibilityName: step.title)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) { Rectangle().fill(CallLook.rule).frame(height: 1) }
    }
}

/// The call script on a ruled notepad, as the prototype draws it: what to say first, then each
/// thing they'll ask, with the urgent lines in red ink. Kept on paper (redesign rule 5): it's read
/// out loud, often with the light on.
public struct NotepadCard: View {
    public var opening: String
    public var lines: [TriageScript.Line]

    public init(opening: String, lines: [TriageScript.Line]) {
        self.opening = opening
        self.lines = lines
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SAY")
                .font(MissionType.mono())
                .tracking(MissionType.monoTracking())
                .foregroundStyle(LabourPalette.redInk.color)
            Text("“\(opening)”")
                .font(MissionType.display(25, relativeTo: .title2))
                .tracking(0.25)
                .foregroundStyle(LabourTheme.paperInk)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(lines, id: \.self) { line in
                VStack(alignment: .leading, spacing: 1) {
                    Text(line.label.uppercased())
                        .font(MissionType.mono().weight(line.isUrgent ? .semibold : .regular))
                        .foregroundStyle(line.isUrgent ? LabourPalette.redInk.color : LabourTheme.paperMuted)
                    Text(line.value)
                        .font(MissionType.body(15.5).weight(line.isUrgent ? .semibold : .regular))
                        .foregroundStyle(line.isUrgent ? LabourPalette.redInk.color : LabourTheme.paperInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 16)
        .padding(.leading, 30)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            let shape = UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 6, bottomLeading: 6, bottomTrailing: 20, topTrailing: 20))
            shape.fill(LabourTheme.cream)
                .overlay {
                    // The prototype's ruled lines, every 31 points.
                    Canvas { context, size in
                        var rules = Path()
                        for row in stride(from: CGFloat(30), to: size.height, by: 31) {
                            rules.move(to: CGPoint(x: 0, y: row))
                            rules.addLine(to: CGPoint(x: size.width, y: row))
                        }
                        context.stroke(rules, with: .color(LabourTheme.paperInk.opacity(0.1)), lineWidth: 1)
                    }
                }
                .overlay(alignment: .leading) {
                    Rectangle().fill(LabourTheme.signal.opacity(0.55)).frame(width: 1.5).padding(.leading, 18)
                }
                .clipShape(shape)
        }
        .accessibilityElement(children: .contain)
    }
}
