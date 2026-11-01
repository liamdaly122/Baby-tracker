import SwiftUI

/// Labour mode's backdrop from the agreed prototype: night sky in bands, stars, the moon, and the
/// Earth's curve along the bottom with city lights. Drawn once from the prototype's own numbers,
/// on its 390 × 844 frame scaled to the screen width and pinned to the bottom. Nothing moves: the
/// prototype's twinkling stars and passing satellite are left out (redesign rule 7). A practice
/// run lays the prototype's cyan blueprint grid over it.
public struct OrbitScene: View {
    public var isPractice: Bool

    public init(isPractice: Bool = false) {
        self.isPractice = isPractice
    }

    public var body: some View {
        Canvas { context, size in
            let scale = size.width / Self.frame.width
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Self.hex(0x05060F)))
            context.translateBy(x: 0, y: size.height - Self.frame.height * scale)
            context.scaleBy(x: scale, y: scale)
            Self.drawSky(in: &context)
            Self.drawEarth(in: &context)
            if isPractice {
                Self.drawGrid(in: &context, top: -(size.height / scale - Self.frame.height))
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    static let frame = CGSize(width: 390, height: 844)

    /// The prototype's seeded random numbers, so the stars land where they do there.
    struct Seeded {
        var seed: Int

        mutating func next() -> Double {
            seed = (seed * 16807) % 2_147_483_647
            return Double(seed - 1) / 2_147_483_646
        }
    }

    private static func hex(_ value: Int) -> Color { PaletteColor(hex: value).color }

    private static func drawSky(in context: inout GraphicsContext) {
        let bands = [0x05060F, 0x070A1A, 0x090D22, 0x0B1029, 0x0D1330, 0x101737]
        for (index, colour) in bands.enumerated() {
            let top = (620 * Double(index) / Double(bands.count)).rounded()
            var band = Path()
            band.move(to: CGPoint(x: 0, y: top))
            band.addQuadCurve(to: CGPoint(x: 390, y: top), control: CGPoint(x: 195, y: top - 12))
            band.addLine(to: CGPoint(x: 390, y: 844))
            band.addLine(to: CGPoint(x: 0, y: 844))
            band.closeSubpath()
            context.fill(band, with: .color(hex(colour)))
        }
        let star = hex(0xFFE2A3)
        var random = Seeded(seed: 31)
        for _ in 0..<80 {
            let across = (random.next() * 390).rounded()
            let down = (random.next() * 600).rounded()
            let radius = ((0.6 + random.next() * 1.1) * 10).rounded() / 10
            _ = random.next()  // the prototype's twinkle delay
            context.fill(circle(across, down, radius), with: .color(star))
        }
        for _ in 0..<4 {
            let across = (random.next() * 390).rounded()
            let down = (random.next() * 600 * 0.8).rounded()
            _ = random.next()
            var sparkle = Path()
            let points: [(Double, Double)] = [
                (0, -5), (1.2, -1.2), (5, 0), (1.2, 1.2), (0, 5), (-1.2, 1.2), (-5, 0), (-1.2, -1.2),
            ]
            sparkle.addLines(points.map { CGPoint(x: across + $0.0, y: down + $0.1) })
            sparkle.closeSubpath()
            context.fill(sparkle, with: .color(star))
        }
        // The moon.
        context.fill(circle(342, 150, 13), with: .color(hex(0x2A2F55)))
        context.fill(circle(338, 146, 3), with: .color(hex(0x20244A)))
        context.fill(circle(347, 155, 2), with: .color(hex(0x20244A)))
    }

    private static func drawEarth(in context: inout GraphicsContext) {
        let centre = CGPoint(x: 195, y: 1530)
        let atmosphere = hex(0x5FB4E8)
        context.stroke(circle(centre.x, centre.y, 924), with: .color(atmosphere.opacity(0.08)), lineWidth: 16)
        context.stroke(circle(centre.x, centre.y, 918), with: .color(atmosphere.opacity(0.22)), lineWidth: 6)
        let earth = circle(centre.x, centre.y, 914)
        context.fill(
            earth,
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: hex(0x1D4B7A), location: 0), .init(color: hex(0x123562), location: 0.5),
                    .init(color: hex(0x0A1A3C), location: 1),
                ]),
                center: CGPoint(x: 195, y: 616), startRadius: 0, endRadius: 0.7 * 1828))
        context.stroke(earth, with: .color(hex(0x9FD6F5).opacity(0.75)), lineWidth: 1.6)

        var west = Path()
        west.move(to: CGPoint(x: 40, y: 650))
        west.addCurve(to: CGPoint(x: 140, y: 640), control1: CGPoint(x: 70, y: 630), control2: CGPoint(x: 110, y: 628))
        west.addCurve(to: CGPoint(x: 120, y: 676), control1: CGPoint(x: 160, y: 650), control2: CGPoint(x: 150, y: 670))
        west.addCurve(to: CGPoint(x: 40, y: 650), control1: CGPoint(x: 90, y: 684), control2: CGPoint(x: 54, y: 678))
        west.closeSubpath()
        var east = Path()
        east.move(to: CGPoint(x: 250, y: 628))
        east.addCurve(to: CGPoint(x: 352, y: 640), control1: CGPoint(x: 290, y: 618), control2: CGPoint(x: 330, y: 626))
        east.addCurve(to: CGPoint(x: 306, y: 664), control1: CGPoint(x: 366, y: 652), control2: CGPoint(x: 340, y: 664))
        east.addCurve(to: CGPoint(x: 250, y: 628), control1: CGPoint(x: 276, y: 664), control2: CGPoint(x: 246, y: 650))
        east.closeSubpath()
        let land = hex(0x1B5A6E).opacity(0.75)
        context.fill(west, with: .color(land))
        context.fill(east, with: .color(land))

        let light = hex(0xFFD27A)
        var random = Seeded(seed: 57)
        for _ in 0..<46 {
            let across = 20 + random.next() * 350
            let down = 640 + random.next() * 120
            let radius = 0.6 + random.next() * 0.9
            let opacity = 0.35 + random.next() * 0.45
            context.fill(circle(across, down, radius), with: .color(light.opacity(opacity)))
        }
    }

    /// The practice run's blueprint grid, every 26 points, from the top of the screen.
    private static func drawGrid(in context: inout GraphicsContext, top: CGFloat) {
        var grid = Path()
        for column in stride(from: CGFloat(0), through: 390, by: 26) {
            grid.move(to: CGPoint(x: column, y: top))
            grid.addLine(to: CGPoint(x: column, y: 844))
        }
        for row in stride(from: (top / 26).rounded(.down) * 26, through: 844, by: 26) {
            grid.move(to: CGPoint(x: 0, y: row))
            grid.addLine(to: CGPoint(x: 390, y: row))
        }
        context.stroke(grid, with: .color(LabourTheme.sim.opacity(0.22)), lineWidth: 1)
    }

    private static func circle(_ centreX: Double, _ centreY: Double, _ radius: Double) -> Path {
        Path(ellipseIn: CGRect(x: centreX - radius, y: centreY - radius, width: radius * 2, height: radius * 2))
    }
}
