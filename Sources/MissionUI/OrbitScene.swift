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

/// The prototype's "splashdown" dawn, for the end of labour when everyone is well: sky bands from
/// violet to gold, a low sun on the sea, and the capsule under its three parachutes. Drawn once on
/// its 390 × 470 frame, scaled to the width. Still: the prototype's falling capsule and ripples
/// are left out. Never shown after a loss or when the baby needs extra care.
public struct DawnScene: View {
    public init() {}

    public static let frame = CGSize(width: 390, height: 470)

    public var body: some View {
        Canvas { context, size in
            let scale = size.width / Self.frame.width
            context.scaleBy(x: scale, y: scale)
            Self.drawSky(in: &context)
            Self.drawSea(in: &context)
            Self.drawCapsule(in: &context)
        }
        .aspectRatio(Self.frame.width / Self.frame.height, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private static func hex(_ value: Int) -> Color { PaletteColor(hex: value).color }

    private static func drawSky(in context: inout GraphicsContext) {
        let bands = [0x3C3A78, 0x7B4F86, 0xC8677D, 0xEE8E6F, 0xF6B47A, 0xF9D49B]
        for (index, colour) in bands.enumerated() {
            let top = (330 * Double(index) / Double(bands.count)).rounded()
            var band = Path()
            band.move(to: CGPoint(x: 0, y: top))
            band.addQuadCurve(to: CGPoint(x: 390, y: top), control: CGPoint(x: 195, y: top - 12))
            band.addLine(to: CGPoint(x: 390, y: 470))
            band.addLine(to: CGPoint(x: 0, y: 470))
            band.closeSubpath()
            context.fill(band, with: .color(hex(colour)))
        }
        let star = hex(0xFFE2A3)
        var random = OrbitScene.Seeded(seed: 5)
        for _ in 0..<10 {
            let across = (random.next() * 390).rounded()
            let down = (random.next() * 90).rounded()
            let radius = ((0.6 + random.next() * 1.1) * 10).rounded() / 10
            _ = random.next()
            context.fill(circle(across, down, radius), with: .color(star))
        }
        context.fill(circle(196, 330, 70), with: .color(hex(0xFFE7B0).opacity(0.5)))
        context.fill(circle(196, 330, 50), with: .color(hex(0xFFF1C9)))
    }

    private static func drawSea(in context: inout GraphicsContext) {
        for (index, colour) in [0x2F6B83, 0x275A72, 0x1F4860, 0x183A51].enumerated() {
            let top = 330 + Double(index) * 36
            context.fill(Path(CGRect(x: 0, y: top, width: 390, height: 470 - top)), with: .color(hex(colour)))
        }
        let foam = LabourTheme.cream
        var random = OrbitScene.Seeded(seed: 23)
        var waves = Path()
        for _ in 0..<26 {
            let across = (random.next() * 380).rounded()
            let down = (340 + random.next() * 120).rounded()
            waves.move(to: CGPoint(x: across, y: down))
            waves.addQuadCurve(to: CGPoint(x: across + 12, y: down), control: CGPoint(x: across + 6, y: down - 4))
        }
        context.stroke(waves, with: .color(foam.opacity(0.35)), lineWidth: 1.4)
        context.stroke(
            Path(ellipseIn: CGRect(x: 156, y: 345, width: 80, height: 14)), with: .color(foam), lineWidth: 2)
    }

    private static func drawCapsule(in context: inout GraphicsContext) {
        let canopies: [(top: CGPoint, colour: Int)] = [
            (CGPoint(x: 150, y: 120), 0xE5482F), (CGPoint(x: 196, y: 104), 0xF4E8D0),
            (CGPoint(x: 242, y: 120), 0xE5482F),
        ]
        for (top, colour) in canopies {
            let centreX = top.x
            let centreY = top.y
            let stripe = colour == 0xE5482F ? 0xF4E8D0 : 0xE5482F
            var canopy = Path()
            canopy.move(to: CGPoint(x: centreX - 34, y: centreY))
            canopy.addQuadCurve(
                to: CGPoint(x: centreX + 34, y: centreY), control: CGPoint(x: centreX, y: centreY - 46))
            canopy.closeSubpath()
            context.fill(canopy, with: .color(hex(colour)))
            var band = Path()
            band.move(to: CGPoint(x: centreX - 11, y: centreY - 1))
            band.addQuadCurve(
                to: CGPoint(x: centreX + 11, y: centreY - 1), control: CGPoint(x: centreX, y: centreY - 42))
            band.closeSubpath()
            context.fill(band, with: .color(hex(stripe)))
            var lines = Path()
            lines.move(to: CGPoint(x: centreX - 34, y: centreY))
            lines.addLine(to: CGPoint(x: 190, y: 290))
            lines.move(to: CGPoint(x: centreX + 34, y: centreY))
            lines.addLine(to: CGPoint(x: 202, y: 290))
            context.stroke(lines, with: .color(LabourTheme.cream.opacity(0.75)), lineWidth: 1)
        }
        var nose = Path()
        nose.addLines([CGPoint(x: 182, y: 312), CGPoint(x: 196, y: 286), CGPoint(x: 210, y: 312)])
        nose.closeSubpath()
        context.fill(nose, with: .color(LabourTheme.cream))
        context.fill(
            Path(roundedRect: CGRect(x: 180, y: 312, width: 32, height: 34), cornerRadius: 4),
            with: .color(LabourTheme.cream))
        context.fill(
            Path(roundedRect: CGRect(x: 178, y: 340, width: 36, height: 8), cornerRadius: 2),
            with: .color(hex(0x232850)))
        context.fill(circle(196, 326, 6), with: .color(hex(0x2E7C83)))
        context.stroke(circle(196, 326, 6), with: .color(hex(0x232850)), lineWidth: 2)
    }

    private static func circle(_ centreX: Double, _ centreY: Double, _ radius: Double) -> Path {
        Path(ellipseIn: CGRect(x: centreX - radius, y: centreY - radius, width: radius * 2, height: radius * 2))
    }
}
