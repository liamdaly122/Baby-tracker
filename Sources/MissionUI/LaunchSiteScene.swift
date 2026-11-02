import SwiftUI

/// The sky over the launch site, which changes as the weeks go by, as in the agreed prototype.
public enum SkyPalette: String, Sendable, CaseIterable {
    case dawn
    case day
    case overcast
    case dusk
    case night

    /// The prototype shows dawn early on and night from 37 weeks. Unknown weeks get dusk.
    public static func forWeek(_ week: Int?) -> SkyPalette {
        guard let week else { return .dusk }
        switch week {
        case ..<20: return .dawn
        case ..<28: return .day
        case ..<32: return .overcast
        case ..<37: return .dusk
        default: return .night
        }
    }

    var sky: [Int] {
        switch self {
        case .dawn: [0x2B2F6B, 0x3F3F80, 0x615394, 0x8E6AA0, 0xC4869F, 0xEDAE9B, 0xFFD8AE]
        case .day: [0x123D6B, 0x1C4D7C, 0x2A5F8C, 0x3F739B, 0x5B89A9, 0x7DA3BC, 0xA9C9D6]
        case .overcast: [0x232C49, 0x2F3858, 0x3D4767, 0x4F5977, 0x646D88, 0x7C8499, 0x969CAE]
        case .dusk: [0x1B2050, 0x2E2B66, 0x533B7A, 0x8E4C7E, 0xC95E6F, 0xEA8460, 0xF5AE68]
        case .night: [0x0F1438, 0x1A1D4A, 0x2B275A, 0x47346A, 0x6E4470, 0x9C5870, 0xC9706A]
        }
    }

    var hills: [Int] {
        switch self {
        case .dawn: [0x4A3C72, 0x2A2452, 0x1D1A40]
        case .day: [0x2F6475, 0x1F4A5C, 0x173A4A]
        case .overcast: [0x3A4260, 0x272D4C, 0x1C2140]
        case .dusk: [0x3A2C66, 0x1F1C48, 0x161638]
        case .night: [0x2A2252, 0x18173E, 0x100F2C]
        }
    }

    var hangar: Int {
        switch self {
        case .dawn: 0x6A5A92
        case .day: 0x4C8696
        case .overcast: 0x56607E
        case .dusk: 0x54447F
        case .night: 0x3C3470
        }
    }

    /// The flat ground along the bottom of the scene, for anything laid out below it.
    public var ground: Color { PaletteColor(hex: hills[2]).color }

    var stars: Int {
        switch self {
        case .dawn: 10
        case .day, .overcast: 0
        case .dusk: 26
        case .night: 44
        }
    }
}

/// The home screen's launch site from the agreed prototype: the week's sky, the hills, the hangar,
/// the red gantry tower and the rocket on its pad, with the two of them looking up at it. Drawn
/// once on the prototype's 390 × 470 frame, scaled to the width. Still: the prototype's drifting
/// clouds, searchlights and blinking beacons don't move. The rocket is drawn whole; building it
/// stage by stage from the checklists comes with the home screen's checklists (Phase 6).
public struct LaunchSiteScene: View {
    public var palette: SkyPalette

    public init(palette: SkyPalette) {
        self.palette = palette
    }

    public static let frame = CGSize(width: 390, height: 470)

    public var body: some View {
        Canvas { context, size in
            let scale = size.width / Self.frame.width
            context.scaleBy(x: scale, y: scale)
            drawSky(in: &context)
            drawGround(in: &context)
            Rocket.drawTower(in: &context, colour: Rocket.colours.tower, width: 3)
            context.fill(Path(CGRect(x: 190, y: 430, width: 160, height: 10)), with: .color(hex(0x151838)))
            context.fill(Path(CGRect(x: 214, y: 426, width: 76, height: 4)), with: .color(hex(0x2A2E5C)))
            Rocket.draw(in: &context, parts: Rocket.Part.allCases)
            context.fill(circle(328, 98, 4), with: .color(hex(0xFF5A45)))
            drawCommander(in: &context, at: CGPoint(x: 132, y: 440))
            drawFlightDirector(in: &context, at: CGPoint(x: 162, y: 440))
            if palette == .night {
                for across in [214.0, 290, 252] {
                    context.fill(circle(across, 438, 2), with: .color(hex(0xFFE2A3)))
                }
            }
        }
        .aspectRatio(Self.frame.width / Self.frame.height, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("The launch site, with the rocket on its pad.")
    }

    private func drawSky(in context: inout GraphicsContext) {
        for (index, colour) in palette.sky.enumerated() {
            let top = (430 * Double(index) / Double(palette.sky.count)).rounded()
            var band = Path()
            band.move(to: CGPoint(x: 0, y: top))
            band.addQuadCurve(to: CGPoint(x: 390, y: top), control: CGPoint(x: 195, y: top - 12))
            band.addLine(to: CGPoint(x: 390, y: 470))
            band.addLine(to: CGPoint(x: 0, y: 470))
            band.closeSubpath()
            context.fill(band, with: .color(hex(colour)))
        }
        if palette.stars > 0 {
            drawStars(in: &context, count: palette.stars)
        }
        drawCelestial(in: &context)
    }

    /// The prototype's seeded stars, as on the orbit scene, over the top 190 points.
    private func drawStars(in context: inout GraphicsContext, count: Int) {
        let star = hex(0xFFE2A3)
        var random = OrbitScene.Seeded(seed: 7)
        for _ in 0..<count {
            let across = (random.next() * 390).rounded()
            let down = (random.next() * 190).rounded()
            let radius = ((0.6 + random.next() * 1.1) * 10).rounded() / 10
            _ = random.next()
            context.fill(circle(across, down, radius), with: .color(star))
        }
    }

    private func drawCelestial(in context: inout GraphicsContext) {
        switch palette {
        case .dawn:
            context.fill(circle(96, 430, 74), with: .color(hex(0xFFE7B0).opacity(0.35)))
            context.fill(circle(96, 430, 50), with: .color(hex(0xFFF0CF)))
            cloud(in: &context, 70, 300, 90, hex(0xFFD2B4).opacity(0.5))
            cloud(in: &context, 180, 352, 60, hex(0xFFD2B4).opacity(0.4))
        case .day:
            context.fill(circle(356, 150, 34), with: .color(hex(0xFFF3C9).opacity(0.22)))
            context.fill(circle(356, 150, 20), with: .color(hex(0xFFF0C2)))
            cloud(in: &context, 84, 300, 110, hex(0xEAF2F6).opacity(0.55))
            cloud(in: &context, 196, 360, 80, hex(0xEAF2F6).opacity(0.45))
            cloud(in: &context, 330, 250, 70, hex(0xEAF2F6).opacity(0.4))
        case .overcast:
            cloud(in: &context, 70, 190, 170, hex(0xA3AABD).opacity(0.45))
            cloud(in: &context, 300, 150, 200, hex(0xA3AABD).opacity(0.4))
            cloud(in: &context, 150, 330, 150, hex(0xB3B9C9).opacity(0.4))
            cloud(in: &context, 330, 300, 130, hex(0x8F97AD).opacity(0.45))
            cloud(in: &context, 40, 250, 110, hex(0x8F97AD).opacity(0.35))
        case .dusk:
            moon(in: &context)
            context.fill(circle(104, 448, 78), with: .color(hex(0xF6C27A).opacity(0.45)))
            context.fill(circle(104, 448, 58), with: .color(hex(0xFFD9A0)))
            cloud(in: &context, 70, 312, 88, hex(0xF7B98A).opacity(0.5))
            cloud(in: &context, 150, 352, 60, hex(0xF7B98A).opacity(0.4))
        case .night:
            moon(in: &context)
            // The prototype's two searchlights, held at a soft glow.
            var beams = Path()
            beams.addLines([
                CGPoint(x: 58, y: 440), CGPoint(x: 222, y: 120), CGPoint(x: 246, y: 126), CGPoint(x: 76, y: 440),
            ])
            beams.closeSubpath()
            beams.addLines([
                CGPoint(x: 384, y: 440), CGPoint(x: 276, y: 126), CGPoint(x: 298, y: 120), CGPoint(x: 392, y: 440),
            ])
            beams.closeSubpath()
            context.fill(beams, with: .color(hex(0xFFE2A3).opacity(0.08)))
        }
    }

    /// The prototype's crescent moon, top left of the tower.
    private func moon(in context: inout GraphicsContext) {
        let crescent = circle(229, 62, 14).subtracting(circle(236, 57, 11.5))
        context.fill(crescent, with: .color(hex(0xFFE2A3)))
    }

    private func drawGround(in context: inout GraphicsContext) {
        var far = Path()
        far.move(to: CGPoint(x: 0, y: 404))
        far.addCurve(to: CGPoint(x: 180, y: 390), control1: CGPoint(x: 60, y: 386), control2: CGPoint(x: 120, y: 398))
        far.addCurve(to: CGPoint(x: 390, y: 388), control1: CGPoint(x: 240, y: 382), control2: CGPoint(x: 300, y: 398))
        far.addLine(to: CGPoint(x: 390, y: 470))
        far.addLine(to: CGPoint(x: 0, y: 470))
        far.closeSubpath()
        context.fill(far, with: .color(hex(palette.hills[0])))
        drawHangar(in: &context)
        var near = Path()
        near.move(to: CGPoint(x: 0, y: 432))
        near.addCurve(to: CGPoint(x: 230, y: 428), control1: CGPoint(x: 90, y: 420), control2: CGPoint(x: 150, y: 434))
        near.addCurve(to: CGPoint(x: 390, y: 430), control1: CGPoint(x: 300, y: 422), control2: CGPoint(x: 340, y: 436))
        near.addLine(to: CGPoint(x: 390, y: 470))
        near.addLine(to: CGPoint(x: 0, y: 470))
        near.closeSubpath()
        context.fill(near, with: .color(hex(palette.hills[1])))
        context.fill(Path(CGRect(x: 0, y: 440, width: 390, height: 30)), with: .color(hex(palette.hills[2])))
    }

    private func drawHangar(in context: inout GraphicsContext) {
        let colour = hex(palette.hangar)
        var shed = Path()
        shed.move(to: CGPoint(x: 22, y: 414))
        shed.addLine(to: CGPoint(x: 22, y: 402))
        shed.addCurve(to: CGPoint(x: 52, y: 382), control1: CGPoint(x: 22, y: 390), control2: CGPoint(x: 36, y: 382))
        shed.addCurve(to: CGPoint(x: 82, y: 402), control1: CGPoint(x: 68, y: 382), control2: CGPoint(x: 82, y: 390))
        shed.addLine(to: CGPoint(x: 82, y: 414))
        shed.closeSubpath()
        context.fill(shed, with: .color(colour))
        var ribs = Path()
        for (across, top) in [(37.0, 386.5), (52, 382), (67, 386.5)] {
            ribs.move(to: CGPoint(x: across, y: top))
            ribs.addLine(to: CGPoint(x: across, y: 414))
        }
        context.stroke(ribs, with: .color(hex(0x090D24).opacity(0.25)), lineWidth: 1)
        context.fill(Path(CGRect(x: 42, y: 399, width: 20, height: 15)), with: .color(hex(0xFFE2A3).opacity(0.9)))
        var slats = Path()
        for down in [403.0, 407, 411] {
            slats.move(to: CGPoint(x: 42, y: down))
            slats.addLine(to: CGPoint(x: 62, y: down))
        }
        context.stroke(slats, with: .color(colour), lineWidth: 1)
        context.fill(Path(CGRect(x: 49, y: 377, width: 1.4, height: 6)), with: .color(colour))
        context.fill(circle(49.7, 376.6, 1.8), with: .color(hex(0xFF5A45)))
    }

    /// Her, side-on, a hand on the bump.
    private func drawCommander(in context: inout GraphicsContext, at ground: CGPoint) {
        var figure = context
        figure.translateBy(x: ground.x, y: ground.y)
        figure.scaleBy(x: 1.3, y: 1.3)
        let cream = LabourTheme.cream
        figure.fill(circle(0, -26, 4), with: .color(cream))
        figure.fill(circle(-3.6, -28, 2.4), with: .color(cream))
        var body = Path()
        body.move(to: CGPoint(x: -3, y: -21))
        body.addCurve(to: CGPoint(x: -6, y: -4), control1: CGPoint(x: -4.5, y: -14), control2: CGPoint(x: -5.5, y: -8))
        body.addLine(to: CGPoint(x: 5, y: -4))
        body.addCurve(to: CGPoint(x: 8.1, y: -14), control1: CGPoint(x: 6, y: -7), control2: CGPoint(x: 8.6, y: -10))
        body.addCurve(to: CGPoint(x: 3, y: -21), control1: CGPoint(x: 7.5, y: -18), control2: CGPoint(x: 4, y: -20))
        body.closeSubpath()
        figure.fill(body, with: .color(cream))
        figure.fill(Path(CGRect(x: -3.4, y: -4.5, width: 2.2, height: 4.5)), with: .color(cream))
        figure.fill(Path(CGRect(x: 1.2, y: -4.5, width: 2.2, height: 4.5)), with: .color(cream))
        var arm = Path()
        arm.move(to: CGPoint(x: 1.5, y: -19))
        arm.addCurve(
            to: CGPoint(x: 6.6, y: -12.6), control1: CGPoint(x: 3.6, y: -15.5), control2: CGPoint(x: 5.6, y: -13.4))
        figure.stroke(arm, with: .color(LabourTheme.navy), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
    }

    /// Him, headset on, clipboard out.
    private func drawFlightDirector(in context: inout GraphicsContext, at ground: CGPoint) {
        var figure = context
        figure.translateBy(x: ground.x, y: ground.y)
        figure.scaleBy(x: 1.3, y: 1.3)
        let cream = LabourTheme.cream
        let ink = LabourTheme.navy
        figure.fill(circle(0, -27.5, 4.2), with: .color(cream))
        var headset = Path()
        headset.addArc(
            center: CGPoint(x: 0, y: -27.2), radius: 4.8, startAngle: .degrees(195), endAngle: .degrees(345),
            clockwise: false)
        headset.move(to: CGPoint(x: -4.4, y: -27))
        headset.addQuadCurve(to: CGPoint(x: -1.6, y: -23.6), control: CGPoint(x: -4.6, y: -24))
        figure.stroke(headset, with: .color(ink), lineWidth: 1.1)
        figure.fill(
            Path(roundedRect: CGRect(x: -4.2, y: -22.5, width: 8.4, height: 12), cornerRadius: 2.6), with: .color(cream)
        )
        figure.fill(Path(CGRect(x: -3.6, y: -11, width: 2.6, height: 11)), with: .color(cream))
        figure.fill(Path(CGRect(x: 1, y: -11, width: 2.6, height: 11)), with: .color(cream))
        figure.fill(
            Path(roundedRect: CGRect(x: -9.6, y: -20.5, width: 5.4, height: 7), cornerRadius: 0.8),
            with: .color(LabourTheme.sun))
        var lines = Path()
        for (down, length) in [(-18.0, 3.4), (-16.4, 3.4), (-14.8, 2.4)] {
            lines.move(to: CGPoint(x: -8.6, y: down))
            lines.addLine(to: CGPoint(x: -8.6 + length, y: down))
        }
        figure.stroke(lines, with: .color(ink), lineWidth: 0.6)
    }

    private func cloud(
        in context: inout GraphicsContext, _ centreX: Double, _ centreY: Double, _ width: Double, _ colour: Color
    ) {
        var puffs = Path()
        puffs.addEllipse(
            in: CGRect(x: centreX - width / 2, y: centreY - width / 9, width: width, height: width * 2 / 9))
        puffs.addEllipse(
            in: CGRect(
                x: centreX - width * 0.34, y: centreY - width * 0.19, width: width * 0.4, height: width * 0.24))
        puffs.addEllipse(
            in: CGRect(x: centreX - width * 0.04, y: centreY - width * 0.19, width: width * 0.32, height: width * 0.2))
        context.fill(puffs, with: .color(colour))
    }

    private func hex(_ value: Int) -> Color { PaletteColor(hex: value).color }

    private func circle(_ centreX: Double, _ centreY: Double, _ radius: Double) -> Path {
        Path(ellipseIn: CGRect(x: centreX - radius, y: centreY - radius, width: radius * 2, height: radius * 2))
    }
}

/// The prototype's rocket, part by part, on the launch site's 390 × 470 frame: the home scene draws
/// it whole on its pad, and the lift-off flies stages 1 to 4.
public enum Rocket {
    public enum Part: CaseIterable, Sendable {
        case pad
        case engines
        case fins
        case tankLower
        case tankUpper
        case cargo
        case training
        case avionics
        case shield
        case comms
        case capsule
        case nose
    }

    /// The parts that fly: everything above the pad.
    public static let flyingParts: [Part] = Part.allCases.filter { $0 != .pad }

    struct Colours {
        let cream = PaletteColor(hex: 0xF4E8D0).color
        let red = PaletteColor(hex: 0xE5482F).color
        let ink = PaletteColor(hex: 0x232850).color
        let teal = PaletteColor(hex: 0x2E7C83).color
        let sun = PaletteColor(hex: 0xF6C24A).color
        let metal = PaletteColor(hex: 0x3B3F66).color
        let metalLight = PaletteColor(hex: 0x6B6F98).color
        let glow = PaletteColor(hex: 0xFFE2A3).color
        let tower = PaletteColor(hex: 0xD9452F).color
    }

    static let colours = Colours()

    /// Draws the parts given, in the frame's coordinates.
    public static func draw(in context: inout GraphicsContext, parts: [Part]) {
        for part in parts {
            draw(part, in: &context)
        }
    }

    // A long switch is the clearest way to keep each part beside its coordinates.
    // swiftlint:disable:next function_body_length
    private static func draw(_ part: Part, in context: inout GraphicsContext) {
        let palette = colours
        func rect(_ left: Double, _ top: Double, _ width: Double, _ height: Double, _ colour: Color) {
            context.fill(Path(CGRect(x: left, y: top, width: width, height: height)), with: .color(colour))
        }
        func shape(_ points: [(Double, Double)], _ colour: Color) {
            var path = Path()
            path.addLines(points.map { CGPoint(x: $0.0, y: $0.1) })
            path.closeSubpath()
            context.fill(path, with: .color(colour))
        }
        func dot(_ centreX: Double, _ centreY: Double, _ radius: Double, _ colour: Color) {
            context.fill(
                Path(
                    ellipseIn: CGRect(x: centreX - radius, y: centreY - radius, width: radius * 2, height: radius * 2)),
                with: .color(colour))
        }
        switch part {
        case .nose:
            var nose = Path()
            nose.move(to: CGPoint(x: 252, y: 120))
            nose.addCurve(
                to: CGPoint(x: 280, y: 170), control1: CGPoint(x: 262, y: 130), control2: CGPoint(x: 276, y: 150))
            nose.addLine(to: CGPoint(x: 224, y: 170))
            nose.addCurve(
                to: CGPoint(x: 252, y: 120), control1: CGPoint(x: 228, y: 150), control2: CGPoint(x: 242, y: 130))
            context.fill(nose, with: .color(palette.red))
            var tip = Path()
            tip.move(to: CGPoint(x: 252, y: 120))
            tip.addCurve(
                to: CGPoint(x: 261, y: 132), control1: CGPoint(x: 255, y: 123), control2: CGPoint(x: 258, y: 127))
            tip.addLine(to: CGPoint(x: 243, y: 132))
            tip.addCurve(
                to: CGPoint(x: 252, y: 120), control1: CGPoint(x: 246, y: 127), control2: CGPoint(x: 249, y: 123))
            context.fill(tip, with: .color(palette.cream.opacity(0.3)))
            context.fill(
                Path(roundedRect: CGRect(x: 238, y: 156, width: 28, height: 5), cornerRadius: 2),
                with: .color(palette.cream.opacity(0.55)))
        case .capsule:
            rect(224, 170, 56, 44, palette.cream)
            dot(252, 190, 10, palette.ink)
            dot(252, 190, 7, palette.teal)
            dot(249, 187, 2.4, palette.glow)
        case .shield:
            context.fill(
                Path(roundedRect: CGRect(x: 220, y: 214, width: 64, height: 10), cornerRadius: 2),
                with: .color(palette.ink))
        case .comms:
            rect(224, 224, 56, 16, palette.teal)
            var aerials = Path()
            aerials.move(to: CGPoint(x: 224, y: 230))
            aerials.addLine(to: CGPoint(x: 209, y: 230))
            aerials.move(to: CGPoint(x: 280, y: 230))
            aerials.addLine(to: CGPoint(x: 295, y: 230))
            context.stroke(aerials, with: .color(palette.cream), lineWidth: 2)
            dot(207, 230, 3, palette.sun)
            dot(297, 230, 3, palette.sun)
        case .avionics:
            rect(224, 240, 56, 26, palette.cream)
            rect(224, 246, 56, 3, palette.red)
            rect(224, 258, 56, 3, palette.red)
        case .training:
            rect(224, 266, 56, 14, palette.cream)
            rect(224, 266, 14, 14, palette.ink)
            rect(252, 266, 14, 14, palette.ink)
        case .cargo:
            rect(224, 280, 56, 38, palette.cream)
            context.stroke(
                Path(roundedRect: CGRect(x: 236, y: 287, width: 32, height: 24), cornerRadius: 3),
                with: .color(palette.ink), lineWidth: 1.6)
            for (centreX, centreY) in [(240.0, 291.0), (264, 291), (240, 307), (264, 307)] {
                dot(centreX, centreY, 1.3, palette.ink)
            }
        case .tankUpper:
            rect(224, 318, 56, 44, palette.red)
            context.draw(
                Text("MC·1").font(.custom(MissionType.displayFamily, fixedSize: 22)).tracking(1)
                    .foregroundStyle(palette.cream),
                at: CGPoint(x: 252, y: 349), anchor: UnitPoint(x: 0.5, y: 0.78))
        case .tankLower:
            rect(224, 362, 56, 42, palette.cream)
            rect(224, 362, 14, 21, palette.ink)
            rect(266, 383, 14, 21, palette.ink)
        case .fins:
            shape([(224, 372), (205, 402), (205, 416), (224, 404)], palette.red)
            shape([(280, 372), (299, 402), (299, 416), (280, 404)], palette.red)
        case .engines:
            shape([(244, 404), (260, 404), (264, 428), (240, 428)], palette.metal)
            shape([(227, 404), (239, 404), (241, 424), (223, 424)], palette.metal)
            shape([(265, 404), (277, 404), (281, 424), (263, 424)], palette.metal)
            shape([(247, 404), (250, 404), (249, 428), (245, 428)], palette.metalLight)
        case .pad:
            rect(206, 428, 92, 6, palette.metal)
            for left in stride(from: 210.0, through: 290, by: 16) {
                shape([(left, 428), (left + 8, 428), (left + 4, 434), (left - 4, 434)], palette.sun)
            }
        }
    }

    /// The red gantry tower beside the rocket.
    static func drawTower(in context: inout GraphicsContext, colour: Color, width: Double) {
        var frame = Path()
        frame.move(to: CGPoint(x: 316, y: 104))
        frame.addLine(to: CGPoint(x: 316, y: 440))
        frame.move(to: CGPoint(x: 340, y: 104))
        frame.addLine(to: CGPoint(x: 340, y: 440))
        frame.move(to: CGPoint(x: 316, y: 104))
        frame.addLine(to: CGPoint(x: 340, y: 104))
        for (start, end) in [
            ((316.0, 196.0), (286.0, 196.0)), ((316, 300), (286, 300)), ((316, 210), (300, 196)),
            ((316, 314), (300, 300)),
        ] {
            frame.move(to: CGPoint(x: start.0, y: start.1))
            frame.addLine(to: CGPoint(x: end.0, y: end.1))
        }
        context.stroke(frame, with: .color(colour), style: StrokeStyle(lineWidth: width, lineCap: .square))
        var braces = Path()
        for top in stride(from: 104.0, to: 440, by: 24) {
            let bottom = min(top + 24, 440)
            braces.move(to: CGPoint(x: 316, y: top))
            braces.addLine(to: CGPoint(x: 340, y: bottom))
            braces.move(to: CGPoint(x: 340, y: top))
            braces.addLine(to: CGPoint(x: 316, y: bottom))
        }
        context.stroke(braces, with: .color(colour), style: StrokeStyle(lineWidth: width * 0.55, lineCap: .square))
    }
}
