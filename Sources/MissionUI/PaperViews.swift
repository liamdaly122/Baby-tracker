import SwiftUI

/// The set-up screens' look from the agreed prototype (v3): its cream paper sheets, with League
/// Gothic headings, small mono labels, pale boxes with a tan edge, and dark "solid" buttons. The
/// same screens open from Labour settings inside labour mode, where a bright page would break the
/// "dark at 3am" rule, so in dark mode every piece uses the prototype's night colours instead.
public struct PaperColors: Sendable {
    public var page: Color
    public var card: Color
    public var ink: Color
    public var muted: Color
    public var edge: Color
    public var good: Color
    public var warn: Color
    public var bad: Color
    public var solid: Color
    public var onSolid: Color

    public static let paper = PaperColors(
        page: LabourPalette.cream.color, card: LabourPalette.paperHi.color, ink: LabourPalette.ink.color,
        muted: LabourPalette.paperMuted.color, edge: LabourPalette.paperEdge.color, good: LabourPalette.okText.color,
        warn: LabourPalette.amberText.color, bad: LabourPalette.redInk.color, solid: LabourPalette.ink.color,
        onSolid: LabourPalette.cream.color)

    public static let night = PaperColors(
        page: LabourPalette.space.color, card: LabourPalette.levelChip.color, ink: LabourPalette.cream.color,
        muted: LabourPalette.muted.color, edge: LabourPalette.cream.color.opacity(0.25), good: LabourPalette.mint.color,
        warn: LabourPalette.sun.color, bad: LabourPalette.callAccent.color, solid: LabourPalette.cream.color,
        onSolid: LabourPalette.ink.color)

    public static func `for`(_ scheme: ColorScheme) -> PaperColors { scheme == .dark ? .night : .paper }
}

/// A set-up screen: a big heading and a small line under it, then its sections, on paper.
public struct PaperPage<Content: View>: View {
    public var title: String
    public var subtitle: String?
    public var content: Content
    @Environment(\.colorScheme) private var scheme

    public init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    public var body: some View {
        let colours = PaperColors.for(scheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(MissionType.display(40))
                        .tracking(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle.uppercased())
                            .font(MissionType.mono())
                            .tracking(1)
                            .foregroundStyle(colours.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                content
            }
            .foregroundStyle(colours.ink)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(colours.page.ignoresSafeArea())
        .tint(colours.ink)
    }
}

/// A section of a set-up screen: a heading in the display face, an optional line of help, then
/// what's in it.
public struct PaperSection<Content: View>: View {
    public var title: String
    public var note: String?
    public var content: Content

    public init(_ title: String, note: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.note = note
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(MissionType.display(26, relativeTo: .title2))
                .tracking(0.5)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let note {
                Text(note)
                    .font(MissionType.body(15))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .padding(.top, 6)
    }
}

/// The small capital label over a field.
public struct PaperLabel: View {
    public var text: String
    @Environment(\.colorScheme) private var scheme

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text.uppercased())
            .font(MissionType.mono())
            .tracking(1.1)
            .foregroundStyle(PaperColors.for(scheme).muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A labelled field: the label, then whatever input goes in the pale box.
public struct PaperField<Input: View>: View {
    public var label: String
    public var input: Input

    public init(_ label: String, @ViewBuilder input: () -> Input) {
        self.label = label
        self.input = input()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            PaperLabel(label)
                .accessibilityHidden(true)
            input.paperBox()
                .accessibilityLabel(label)
        }
    }
}

extension View {
    /// The prototype's input box: pale paper with a tan edge, at least the labour control size.
    public func paperBox() -> some View {
        modifier(PaperBox())
    }
}

private struct PaperBox: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let colours = PaperColors.for(scheme)
        content
            .font(MissionType.body(16))
            .foregroundStyle(colours.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colours.card))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(colours.edge, lineWidth: 2))
    }
}

/// A short note under a field: what a number will dial (green), a warning (brown-orange), or
/// what's wrong (red).
public struct PaperNote: View {
    public enum Tone: Sendable {
        case plain
        case good
        case warn
        case bad
    }

    public var text: String
    public var tone: Tone
    @Environment(\.colorScheme) private var scheme

    public init(_ text: String, tone: Tone = .plain) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        let colours = PaperColors.for(scheme)
        let colour: Color =
            switch tone {
            case .plain: colours.muted
            case .good: colours.good
            case .warn: colours.warn
            case .bad: colours.bad
            }
        Text(text)
            .font(tone == .plain ? MissionType.body(13, relativeTo: .footnote) : MissionType.mono())
            .fontWeight(tone == .bad ? .semibold : .regular)
            .lineSpacing(2)
            .foregroundStyle(colour)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The prototype's tick row: a square box, ticked or not, and what it means.
public struct PaperTick: View {
    public var title: String
    @Binding public var isOn: Bool
    @Environment(\.colorScheme) private var scheme

    public init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        _isOn = isOn
    }

    public var body: some View {
        let colours = PaperColors.for(scheme)
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isOn ? colours.solid : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(colours.solid, lineWidth: 2)
                    )
                    .overlay {
                        if isOn {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(colours.onSolid)
                        }
                    }
                    .frame(width: 22, height: 22)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 4 }
                Text(title)
                    .font(MissionType.body(15))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(minHeight: LabourTheme.chipSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? "On" : "Off")
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

/// The prototype's paper chips: pick one, or several. The picked ones are filled.
public struct PaperChips<Option: Hashable>: View {
    public var options: [Option]
    public var title: (Option) -> String
    public var isPicked: (Option) -> Bool
    public var pick: (Option) -> Void
    @Environment(\.colorScheme) private var scheme

    public init(
        _ options: [Option], title: @escaping (Option) -> String, isPicked: @escaping (Option) -> Bool,
        pick: @escaping (Option) -> Void
    ) {
        self.options = options
        self.title = title
        self.isPicked = isPicked
        self.pick = pick
    }

    public var body: some View {
        let colours = PaperColors.for(scheme)
        FlowLayout(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let picked = isPicked(option)
                Button {
                    pick(option)
                } label: {
                    Text(title(option))
                        .font(MissionType.body(13.5).weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(picked ? colours.onSolid : colours.ink)
                        .padding(.horizontal, 12)
                        .frame(minHeight: LabourTheme.chipSize)
                        .background(Capsule().fill(picked ? colours.solid : colours.card))
                        .overlay(Capsule().strokeBorder(picked ? colours.solid : colours.edge, lineWidth: 1.5))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(picked ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: options.filter(isPicked))
    }
}

/// A number with − and + beside it, for the journey time and the call thresholds.
public struct PaperStepper: View {
    public var label: String
    public var value: String
    public var canDecrease: Bool
    public var canIncrease: Bool
    public var decrease: () -> Void
    public var increase: () -> Void
    @Environment(\.colorScheme) private var scheme

    public init(
        _ label: String, value: String, canDecrease: Bool = true, canIncrease: Bool = true,
        decrease: @escaping () -> Void, increase: @escaping () -> Void
    ) {
        self.label = label
        self.value = value
        self.canDecrease = canDecrease
        self.canIncrease = canIncrease
        self.decrease = decrease
        self.increase = increase
    }

    public var body: some View {
        let colours = PaperColors.for(scheme)
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                PaperLabel(label)
                Text(value)
                    .font(MissionType.display(28, relativeTo: .title2))
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            stepButton("minus", enabled: canDecrease, colours: colours, action: decrease)
                .accessibilityLabel("Less")
            stepButton("plus", enabled: canIncrease, colours: colours, action: increase)
                .accessibilityLabel("More")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if canIncrease { increase() }
            case .decrement: if canDecrease { decrease() }
            @unknown default: break
            }
        }
    }

    private func stepButton(
        _ icon: String, enabled: Bool, colours: PaperColors, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(colours.ink)
                .frame(width: LabourTheme.chipSize, height: LabourTheme.chipSize)
                .background(Circle().fill(colours.card))
                .overlay(Circle().strokeBorder(colours.edge, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .sensoryFeedback(.selection, trigger: value)
    }
}

/// The prototype's buttons on paper: solid ink, an outline, or an outline in red for removing.
public struct PaperButtonStyle: ButtonStyle {
    public enum Kind: Sendable {
        case solid
        case ghost
        case danger
    }

    public var kind: Kind

    public init(_ kind: Kind) {
        self.kind = kind
    }

    public func makeBody(configuration: Configuration) -> some View {
        PaperButtonBody(kind: kind, label: configuration.label, isPressed: configuration.isPressed)
    }
}

private struct PaperButtonBody<Label: View>: View {
    var kind: PaperButtonStyle.Kind
    var label: Label
    var isPressed: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let colours = PaperColors.for(scheme)
        let ink: Color =
            switch kind {
            case .solid: colours.onSolid
            case .ghost: colours.ink
            case .danger: colours.bad
            }
        label
            .font(MissionType.body(15).weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(ink)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: LabourTheme.chipSize + 4)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(kind == .solid ? colours.solid : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(kind == .danger ? colours.bad : colours.solid, lineWidth: kind == .solid ? 0 : 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(isEnabled ? (isPressed ? 0.7 : 1) : 0.4)
    }
}

/// A pale card with a tan edge, for a person or a section of the plan.
public struct PaperCard<Content: View>: View {
    public var content: Content
    @Environment(\.colorScheme) private var scheme

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        let colours = PaperColors.for(scheme)
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(colours.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(colours.edge, lineWidth: 1.5))
    }
}

/// The hospital on the prototype's teal card: what kind of place, its name, where, the journey.
public struct PlaceCard<Accessory: View>: View {
    public var kind: String
    public var name: String
    public var detail: String?
    public var facts: [(value: String, label: String)]
    public var accessory: Accessory

    public init(
        kind: String, name: String, detail: String? = nil, facts: [(value: String, label: String)] = [],
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.kind = kind
        self.name = name
        self.detail = detail
        self.facts = facts
        self.accessory = accessory()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.uppercased())
                        .font(MissionType.mono())
                        .tracking(1.1)
                        .foregroundStyle(LabourTheme.cream.opacity(0.8))
                    Text(name)
                        .font(MissionType.display(32, relativeTo: .title))
                        .tracking(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail {
                        Text(detail)
                            .font(MissionType.body(14))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                accessory
            }
            if !facts.isEmpty {
                HStack(alignment: .top) {
                    ForEach(Array(facts.enumerated()), id: \.offset) { _, fact in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fact.value)
                                .font(MissionType.display(28, relativeTo: .title2))
                                .monospacedDigit()
                            Text(fact.label.uppercased())
                                .font(MissionType.mono())
                                .foregroundStyle(LabourTheme.cream.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.top, 10)
                .overlay(alignment: .top) { Rectangle().fill(LabourTheme.cream.opacity(0.25)).frame(height: 1.5) }
            }
        }
        .foregroundStyle(LabourTheme.cream)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LabourPalette.tealText.color))
    }
}

/// Lays chips out in rows, wrapping onto the next line when a row is full.
public struct FlowLayout: Layout {
    public var spacing: CGFloat

    public init(spacing: CGFloat = 6) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews, width: width)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        let used = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? used, height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var top = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var left = bounds.minX
            for index in row.items {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subviews[index].place(at: CGPoint(x: left, y: top), proposal: ProposedViewSize(size))
                left += size.width + spacing
            }
            top += row.height + spacing
        }
    }

    private struct Row {
        var items: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            let needed =
                rows[rows.count - 1].items.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].items.isEmpty {
                rows.append(Row())
            }
            let row = rows.count - 1
            rows[row].width = rows[row].items.isEmpty ? size.width : rows[row].width + spacing + size.width
            rows[row].height = max(rows[row].height, size.height)
            rows[row].items.append(index)
        }
        return rows
    }
}
