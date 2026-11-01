import MissionCore
import SwiftUI

/// The advice at the top of the timer, as the agreed prototype lays it out: a big headline, the
/// reasons behind it, what to do, the call button and the source. No box until "Call now"; from
/// there it's a red panel. The prototype's bright red fails contrast under cream text, so the panel
/// uses its darker "signal text" red (`LabourTheme.hot`), and the small text on it is solid cream.
public struct AdviceBlock<Call: View>: View {
    public var state: LabourState
    public var headline: String
    public var reasonLines: [String]
    public var detail: String
    public var source: String?
    public var call: Call
    @Environment(\.missionMode) private var mode

    public init(
        state: LabourState, headline: String, reasonLines: [String], detail: String, source: String? = nil,
        @ViewBuilder call: () -> Call
    ) {
        self.state = state
        self.headline = headline
        self.reasonLines = reasonLines
        self.detail = detail
        self.source = source
        self.call = call()
    }

    /// "Call now" and 999 are a red panel.
    public static func isHot(_ state: LabourState) -> Bool { state >= .callNow }

    private var hot: Bool { Self.isHot(state) }
    private var headlineColour: Color {
        hot ? LabourTheme.cream : (mode == .practice ? LabourTheme.sim : LabourTheme.sun)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text(mode.headline(headline))
                    .font(MissionType.display(40))
                    .tracking(0.8)
                    .foregroundStyle(headlineColour)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(mode.spokenHeadline(headline))
                    .accessibilityAddTraits(.isHeader)
                ForEach(reasonLines, id: \.self) { line in
                    Text(line)
                        .font(MissionType.body(16.5))
                        .lineSpacing(3)
                        .foregroundStyle(LabourTheme.cream)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(detail)
                    .font(MissionType.body(14, relativeTo: .callout))
                    .lineSpacing(2)
                    .foregroundStyle(hot ? LabourTheme.cream : LabourTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            call
            if let source {
                Text("Source: \(source)".uppercased())
                    .font(MissionType.mono())
                    .tracking(MissionType.minimumSize * 0.06)
                    .foregroundStyle(hot ? LabourTheme.cream : LabourTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(hot ? 16 : 0)
        .background {
            if hot {
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(LabourTheme.hot)
            }
        }
    }
}

/// The face of a call button, the prototype's "dial": a phone, the name in the display face, and
/// the number in small mono. The caller wraps it in the link that dials. Sun at "time to call",
/// cream with red ink inside the red panel, and dashed cyan in a practice run, where nothing dials.
public struct DialFace: View {
    public enum Style: Sendable {
        case warm
        case hot
        case practice
    }

    public var title: String
    public var detail: String?
    public var style: Style

    public init(title: String, detail: String?, style: Style) {
        self.title = title
        self.detail = detail
        self.style = style
    }

    private var fill: Color {
        switch style {
        case .warm: LabourTheme.sun
        case .hot: LabourTheme.cream
        case .practice: LabourTheme.simDeep
        }
    }

    private var ink: Color {
        switch style {
        case .warm: LabourTheme.navy
        case .hot: LabourTheme.hot
        case .practice: LabourTheme.simInk
        }
    }

    private var smallInk: Color {
        switch style {
        case .warm: LabourTheme.navy.opacity(0.7)
        case .hot: LabourTheme.paperMuted
        case .practice: LabourTheme.simInk
        }
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: style == .practice ? "phone" : "phone.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ink)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(MissionType.display(26, relativeTo: .title2))
                    .tracking(0.8)
                    .foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(MissionType.mono())
                        .foregroundStyle(smallInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
        .overlay {
            if style == .practice {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(LabourTheme.sim, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
