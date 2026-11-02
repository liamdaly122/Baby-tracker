import SwiftUI

/// The prototype's lift-off, shortened: a count of 3, 2, 1, ignition, the rocket climbing as the
/// sky turns to space, then "Labour mode". Labour mode is already running underneath (the session
/// starts the moment LAUNCH is tapped), and a tap anywhere skips this, so a contraction is never
/// missed. About 4 seconds rather than the prototype's 7.7, and never shown under Reduce Motion or
/// Low Power Mode, or before 37 weeks (the prototype goes straight to the call card then).
public struct LiftOffView: View {
    public var start: Date
    public var onFinish: () -> Void

    public init(start: Date, onFinish: @escaping () -> Void) {
        self.start = start
        self.onFinish = onFinish
    }

    /// The moments, in seconds from the tap.
    public static let countdownEnd = 1.5
    public static let ignitionEnd = 2.0
    public static let duration = 4.2

    public var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                Self.drawFrame(in: &context, size: size, time: min(time, Self.duration))
            }
            .ignoresSafeArea()
            .onChange(of: time >= Self.duration) { _, done in
                if done { onFinish() }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onFinish)
        .accessibilityElement()
        .accessibilityLabel("Lift-off. Labour mode is starting.")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to skip")
        .accessibilityAction(.default, onFinish)
    }

    // MARK: Drawing

    private static let sky = [0x0F1438, 0x1A1D4A, 0x2B275A, 0x47346A, 0x6E4470, 0x9C5870, 0xC9706A]
    private static let space = 0x05060F

    /// How far the rocket has climbed, in points at the prototype's scale.
    static func rise(_ time: Double) -> Double {
        let flying = max(0, time - ignitionEnd)
        return 0.5 * 520 * flying * flying
    }

    /// One frame, `time` seconds after the tap. Public for the picture tests.
    public static func drawFrame(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let scale = size.width / 390
        let ground = size.height * 0.83
        let climbed = rise(time) * scale
        // The camera follows once the rocket is a quarter of the way up the screen. Then, as
        // "Labour mode" comes in, she pulls away off the top, as in the prototype.
        let late = max(0, time - 3.0)
        let onScreen = min(climbed, size.height * 0.25 + late * late * 1700 * scale)
        let camera = climbed - onScreen
        // A little shake at ignition, easing off as she climbs. Steady, not random.
        let shake = time > countdownEnd ? max(0, 3 * (1 - (time - countdownEnd) / 2)) * sin(time * 90) : 0
        context.translateBy(x: shake, y: 0)
        drawSky(in: &context, size: size, ground: ground, camera: camera)
        // The big lettering sits behind the rocket, as the prototype's, so she climbs past it.
        drawBigCaptions(in: &context, size: size, scale: scale, time: time)
        drawGround(in: &context, size: size, ground: ground + camera, scale: scale)
        drawSmoke(in: &context, size: size, ground: ground + camera, scale: scale, time: time)
        drawRocket(in: &context, size: size, base: ground + camera - climbed, scale: scale, time: time)
        drawCaptions(in: &context, size: size, scale: scale, time: time)
        if time > duration - 0.6 {
            let fade = min(1, (time - (duration - 0.6)) / 0.6)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(hex(space).opacity(fade)))
        }
    }

    private static func drawSky(in context: inout GraphicsContext, size: CGSize, ground: Double, camera: Double) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(hex(space)))
        let band = ground / Double(sky.count)
        // The night sky, and bands above it fading into space, sliding down as the camera climbs.
        let parallax = camera * 0.42
        for index in 0..<7 {
            let colour = mix(sky[0], space, Double(7 - index) / 7)
            let top = -Double(7 - index) * band + parallax
            context.fill(Path(CGRect(x: 0, y: top, width: size.width, height: band + 1)), with: .color(colour))
        }
        for (index, colour) in sky.enumerated() {
            context.fill(
                Path(CGRect(x: 0, y: Double(index) * band + parallax, width: size.width, height: band + 1)),
                with: .color(hex(colour)))
        }
        var random = OrbitScene.Seeded(seed: 99)
        for _ in 0..<130 {
            let across = random.next() * size.width
            let down = random.next() * size.height
            let radius = 0.5 + random.next() * 1.3
            let height = (down + camera * 0.2).truncatingRemainder(dividingBy: size.height)
            context.fill(
                Path(ellipseIn: CGRect(x: across - radius, y: height - radius, width: radius * 2, height: radius * 2)),
                with: .color(hex(0xFFE2A3).opacity(min(1, camera / size.height + 0.15))))
        }
    }

    private static func drawGround(in context: inout GraphicsContext, size: CGSize, ground: Double, scale: Double) {
        guard ground < size.height + 20 else { return }
        var hills = Path()
        hills.move(to: CGPoint(x: 0, y: ground - 20 * scale))
        hills.addCurve(
            to: CGPoint(x: size.width, y: ground - 24 * scale),
            control1: CGPoint(x: size.width * 0.3, y: ground - 44 * scale),
            control2: CGPoint(x: size.width * 0.7, y: ground - 4 * scale))
        hills.addLine(to: CGPoint(x: size.width, y: size.height + 40))
        hills.addLine(to: CGPoint(x: 0, y: size.height + 40))
        hills.closeSubpath()
        context.fill(hills, with: .color(hex(0x18173E)))
        context.fill(Path(CGRect(x: 0, y: ground, width: size.width, height: size.height)), with: .color(hex(0x100F2C)))
        var tower = context
        tower.translateBy(x: size.width / 2 - 252 * scale * 1.45 + 30 * scale, y: ground - 440 * scale * 1.45)
        tower.scaleBy(x: scale * 1.45, y: scale * 1.45)
        Rocket.drawTower(in: &tower, colour: Rocket.colours.tower, width: 3)
        tower.fill(Path(CGRect(x: 190, y: 430, width: 160, height: 10)), with: .color(hex(0x151838)))
    }

    /// Soft clouds of smoke from ignition, spreading along the ground. Flat circles, no blur.
    private static func drawSmoke(
        in context: inout GraphicsContext, size: CGSize, ground: Double, scale: Double, time: Double
    ) {
        guard time > countdownEnd, ground < size.height + 120 else { return }
        var random = OrbitScene.Seeded(seed: 41)
        for index in 0..<46 {
            let born = countdownEnd + Double(index) * 0.045
            let side = random.next() - 0.5
            let lift = random.next()
            guard time > born else { continue }
            let age = time - born
            let centreX = size.width / 2 + side * (60 + age * 260) * scale
            let centreY = ground - (8 + lift * 30 + age * 18) * scale
            let radius = (14 + age * 26) * scale
            context.fill(
                Path(
                    ellipseIn: CGRect(x: centreX - radius, y: centreY - radius, width: radius * 2, height: radius * 2)),
                with: .color(LabourTheme.cream.opacity(max(0, 0.32 - age * 0.08))))
        }
    }

    private static func drawRocket(
        in context: inout GraphicsContext, size: CGSize, base: Double, scale: Double, time: Double
    ) {
        let rocketScale = scale * 1.45
        var rocket = context
        rocket.translateBy(x: size.width / 2 - 252 * rocketScale, y: base - 428 * rocketScale)
        rocket.scaleBy(x: rocketScale, y: rocketScale)
        if time > countdownEnd {
            // The flame: a sun-coloured plume with a pale core, flickering steadily.
            let length = (time < ignitionEnd ? 30 : 70) + 8 * sin(time * 40)
            var plume = Path()
            plume.move(to: CGPoint(x: 236, y: 428))
            plume.addQuadCurve(to: CGPoint(x: 252, y: 428 + length), control: CGPoint(x: 232, y: 428 + length * 0.6))
            plume.addQuadCurve(to: CGPoint(x: 268, y: 428), control: CGPoint(x: 272, y: 428 + length * 0.6))
            plume.closeSubpath()
            rocket.fill(plume, with: .color(LabourTheme.sun))
            var core = Path()
            core.move(to: CGPoint(x: 244, y: 428))
            core.addQuadCurve(
                to: CGPoint(x: 252, y: 428 + length * 0.6), control: CGPoint(x: 242, y: 428 + length * 0.4))
            core.addQuadCurve(to: CGPoint(x: 260, y: 428), control: CGPoint(x: 262, y: 428 + length * 0.4))
            core.closeSubpath()
            rocket.fill(core, with: .color(PaletteColor(hex: 0xFFF1C9).color))
        }
        Rocket.draw(in: &rocket, parts: Rocket.flyingParts)
    }

    private static func drawBigCaptions(in context: inout GraphicsContext, size: CGSize, scale: Double, time: Double) {
        let centre = CGPoint(x: size.width / 2, y: size.height * 0.225)
        if time < countdownEnd {
            let step = time / 0.5
            let fraction = step - step.rounded(.down)
            context.draw(
                display("\(3 - Int(step))", size: 180 * scale, opacity: 1 - fraction * fraction),
                at: CGPoint(x: centre.x + 40 * scale, y: centre.y))
        } else if time >= ignitionEnd, time < 3.2 {
            context.draw(display("LIFT-OFF", size: 100 * scale, opacity: min(1, (3.2 - time) / 0.3)), at: centre)
        }
    }

    private static func drawCaptions(in context: inout GraphicsContext, size: CGSize, scale: Double, time: Double) {
        let top = CGPoint(x: size.width / 2, y: 76 * scale + 20)
        func label(_ text: String, opacity: Double) {
            context.draw(
                Text(text).font(MissionType.mono(12)).tracking(2).foregroundStyle(hex(0xFFE2A3).opacity(opacity)),
                at: top)
        }
        if time < countdownEnd {
            label("T-MINUS", opacity: min(1, time / 0.3))
        } else if time < ignitionEnd {
            label("IGNITION", opacity: 1)
        } else if time < 3.2 {
            label("WE HAVE LIFT-OFF", opacity: 1)
        } else {
            let fade = min(1, (time - 3.2) / 0.4)
            label("ENTERING ORBIT", opacity: fade)
            context.draw(
                display("Labour mode", size: 46 * scale, opacity: fade),
                at: CGPoint(x: size.width / 2, y: size.height * 0.48))
            context.draw(
                Text("Timer, when to call, her plan and the decoder.")
                    .font(MissionType.body(14))
                    .foregroundStyle(LabourTheme.muted.opacity(fade * 0.85)),
                at: CGPoint(x: size.width / 2, y: size.height * 0.48 + 34 * scale))
        }
    }

    private static func display(_ text: String, size points: Double, opacity: Double) -> Text {
        Text(text)
            .font(.custom(MissionType.displayFamily, fixedSize: points))
            .foregroundStyle(LabourTheme.cream.opacity(opacity))
    }

    private static func hex(_ value: Int) -> Color { PaletteColor(hex: value).color }

    private static func mix(_ start: Int, _ end: Int, _ share: Double) -> Color {
        PaletteColor(hex: end).over(PaletteColor(hex: start), opacity: share).color
    }
}
