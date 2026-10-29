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
        case .call: Color(red: 1.0, green: 0.61, blue: 0.54)
        case .plan: LabourTheme.amber
        case .coach: Color(red: 0.5, green: 0.85, blue: 0.78)
        case .decoder: Color(red: 0.55, green: 0.72, blue: 0.91)
        }
    }

    /// A tinted surface for cards in this world.
    public var surface: Color {
        switch self {
        case .call: Color(red: 0.23, green: 0.07, blue: 0.06)
        case .plan: Color(red: 0.98, green: 0.96, blue: 0.89)
        case .coach: Color(red: 0.09, green: 0.27, blue: 0.29)
        case .decoder: Color(red: 0.06, green: 0.11, blue: 0.24)
        }
    }

    private var top: Color {
        switch self {
        case .call: Color(red: 0.16, green: 0.05, blue: 0.04)
        case .plan: Color(red: 0.13, green: 0.11, blue: 0.08)
        case .coach: Color(red: 0.05, green: 0.23, blue: 0.24)
        case .decoder: Color(red: 0.04, green: 0.08, blue: 0.19)
        }
    }

    private var bottom: Color {
        switch self {
        case .call: Color(red: 0.07, green: 0.02, blue: 0.04)
        case .plan: Color(red: 0.08, green: 0.07, blue: 0.05)
        case .coach: Color(red: 0.02, green: 0.11, blue: 0.12)
        case .decoder: Color(red: 0.04, green: 0.08, blue: 0.19)
        }
    }

    /// The full-screen background, with a blueprint grid for the decoder.
    public var background: some View {
        ZStack {
            LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
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

/// The header at the top of a labour tab: a small label, a big title, and one line on what it's for.
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
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold).monospaced())
                .tracking(1.2)
                .foregroundStyle(world.accent)
            Text(title)
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(LabourTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(LabourTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
