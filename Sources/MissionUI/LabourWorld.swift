import SwiftUI

/// Each labour tab is its own place, so he knows where he is at a glance in a dark room: the Call
/// tab is an oxblood comms panel, the plan is a printed sheet on a desk, the coach is teal, and
/// the decoder is a blueprint. The timer stays true black.
public enum LabourWorld: Sendable {
    case call
    case plan
    case coach
    case decoder

    /// The colour of the tab's labels and markers.
    public var accent: Color {
        switch self {
        case .call: LabourPalette.callAccent.color
        case .plan: LabourTheme.sun
        case .coach: LabourPalette.coachAccent.color
        case .decoder: LabourPalette.decoderAccent.color
        }
    }

    /// A tinted surface for cards in this world.
    public var surface: Color {
        switch self {
        case .call: LabourPalette.callSurface.color
        case .plan: LabourPalette.paper.color
        case .coach: LabourPalette.coachSurface.color
        case .decoder: LabourPalette.decoderSurface.color
        }
    }

    private var top: Color {
        switch self {
        case .call: LabourPalette.callTop.color
        case .plan: Color(red: 0.13, green: 0.11, blue: 0.08)
        case .coach: Color(red: 0.05, green: 0.23, blue: 0.24)
        case .decoder: Color(red: 0.04, green: 0.08, blue: 0.19)
        }
    }

    private var bottom: Color {
        switch self {
        case .call: LabourPalette.callBottom.color
        case .plan: Color(red: 0.08, green: 0.07, blue: 0.05)
        case .coach: Color(red: 0.02, green: 0.11, blue: 0.12)
        case .decoder: Color(red: 0.04, green: 0.08, blue: 0.19)
        }
    }

    /// The full-screen background, with a blueprint grid for the decoder.
    public var background: some View {
        ZStack {
            // The prototype's gradient settles at 70% of the way down.
            LinearGradient(
                stops: [.init(color: top, location: 0), .init(color: bottom, location: 0.7)], startPoint: .top,
                endPoint: .bottom)
            if self == .decoder {
                Canvas { context, size in
                    var grid = Path()
                    let step: CGFloat = 22
                    for column in stride(from: 0, through: size.width, by: step) {
                        grid.move(to: CGPoint(x: column, y: 0))
                        grid.addLine(to: CGPoint(x: column, y: size.height))
                    }
                    for row in stride(from: 0, through: size.height, by: step) {
                        grid.move(to: CGPoint(x: 0, y: row))
                        grid.addLine(to: CGPoint(x: size.width, y: row))
                    }
                    context.stroke(grid, with: .color(accent.opacity(0.09)), lineWidth: 1)
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// The header at the top of a labour tab, as the prototype sets it: a small coloured label, a big
/// title in the display face, and one line on what the tab is for.
public struct LabourTabHeader: View {
    public var world: LabourWorld
    public var eyebrow: String
    public var title: String
    public var subtitle: String?

    public init(world: LabourWorld, eyebrow: String, title: String, subtitle: String? = nil) {
        self.world = world
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(eyebrow.uppercased())
                .font(MissionType.mono())
                .tracking(MissionType.monoTracking())
                .foregroundStyle(world.accent)
            Text(title)
                .font(MissionType.display(38))
                .tracking(0.76)
                .foregroundStyle(LabourTheme.cream)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(MissionType.body(13.5, relativeTo: .subheadline))
                    .foregroundStyle(LabourTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
