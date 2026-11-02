import SwiftUI

/// The app icon: the prototype's rocket lifting off at an angle, flame and all, under the dusk sky,
/// at any square size. Climbing across the corner, it's big enough to read on a home screen. The
/// icon pictures in the phone's and the watch's asset catalogs are drawn from this by the picture
/// tests (`AppIconTests`), so the icon and the home screen's rocket can't drift apart.
public struct AppIconArt: View {
    public init() {}

    public var body: some View {
        Canvas { context, size in
            Self.draw(in: &context, side: min(size.width, size.height))
        }
        .accessibilityHidden(true)
    }

    /// Draws the icon on a `side` × `side` square, laid out on a 1024-point grid.
    public static func draw(in context: inout GraphicsContext, side: Double) {
        let unit = side / 1024
        let palette = SkyPalette.dusk
        // The sky's bands, darkest at the top, down to the hills.
        let horizon = 800 * unit
        let band = horizon / Double(palette.sky.count)
        for (index, colour) in palette.sky.enumerated() {
            // The last band runs to the bottom, so no gap shows where the hills dip.
            let height = index == palette.sky.count - 1 ? side : band + 1
            context.fill(
                Path(CGRect(x: 0, y: Double(index) * band, width: side, height: height)), with: .color(hex(colour)))
        }
        var random = OrbitScene.Seeded(seed: 11)
        for _ in 0..<24 {
            let across = random.next() * side
            let down = random.next() * 330 * unit
            let radius = (2.5 + random.next() * 3.5) * unit
            context.fill(
                Path(ellipseIn: CGRect(x: across - radius, y: down - radius, width: radius * 2, height: radius * 2)),
                with: .color(Rocket.colours.glow.opacity(0.85)))
        }
        drawHills(in: &context, side: side, unit: unit, palette: palette)
        // The flying rocket and its flame, turned 35 degrees and centred, clear of the rounded corners. In the
        // rocket's own frame it runs from the nose at y 120 to the flame's tip at y 518.
        var rocket = context
        rocket.translateBy(x: side / 2, y: side / 2)
        rocket.rotate(by: .degrees(35))
        rocket.scaleBy(x: 2.6 * unit, y: 2.6 * unit)
        rocket.translateBy(x: -252, y: -319)
        drawFlame(in: &rocket)
        Rocket.draw(in: &rocket, parts: Rocket.flyingParts)
    }

    /// The lift-off's plume: sun yellow with a pale core, below the engines.
    private static func drawFlame(in context: inout GraphicsContext) {
        let length = 90.0
        var plume = Path()
        plume.move(to: CGPoint(x: 234, y: 426))
        plume.addQuadCurve(to: CGPoint(x: 252, y: 428 + length), control: CGPoint(x: 230, y: 428 + length * 0.6))
        plume.addQuadCurve(to: CGPoint(x: 270, y: 426), control: CGPoint(x: 274, y: 428 + length * 0.6))
        plume.closeSubpath()
        context.fill(plume, with: .color(Rocket.colours.sun))
        var core = Path()
        core.move(to: CGPoint(x: 243, y: 426))
        core.addQuadCurve(to: CGPoint(x: 252, y: 428 + length * 0.6), control: CGPoint(x: 241, y: 428 + length * 0.4))
        core.addQuadCurve(to: CGPoint(x: 261, y: 426), control: CGPoint(x: 263, y: 428 + length * 0.4))
        core.closeSubpath()
        context.fill(core, with: .color(hex(0xFFF1C9)))
    }

    private static func drawHills(in context: inout GraphicsContext, side: Double, unit: Double, palette: SkyPalette) {
        var far = Path()
        far.move(to: CGPoint(x: 0, y: 820 * unit))
        far.addCurve(
            to: CGPoint(x: side, y: 800 * unit), control1: CGPoint(x: side * 0.3, y: 770 * unit),
            control2: CGPoint(x: side * 0.7, y: 840 * unit))
        far.addLine(to: CGPoint(x: side, y: side))
        far.addLine(to: CGPoint(x: 0, y: side))
        far.closeSubpath()
        context.fill(far, with: .color(hex(palette.hills[0])))
        var near = Path()
        near.move(to: CGPoint(x: 0, y: 890 * unit))
        near.addCurve(
            to: CGPoint(x: side, y: 880 * unit), control1: CGPoint(x: side * 0.35, y: 860 * unit),
            control2: CGPoint(x: side * 0.65, y: 905 * unit))
        near.addLine(to: CGPoint(x: side, y: side))
        near.addLine(to: CGPoint(x: 0, y: side))
        near.closeSubpath()
        context.fill(near, with: .color(hex(palette.hills[1])))
        context.fill(
            Path(CGRect(x: 0, y: 940 * unit, width: side, height: side - 940 * unit)),
            with: .color(hex(palette.hills[2])))
    }

    private static func hex(_ value: Int) -> Color { PaletteColor(hex: value).color }
}
