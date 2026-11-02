import SwiftUI

/// A colour as sRGB numbers, so its contrast can be worked out and tested (WCAG 2.2, 1.4.3).
public struct PaletteColor: Sendable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init(white: Double) {
        self.init(red: white, green: white, blue: white)
    }

    /// From a hex number such as 0xF6C24A, as the prototype's stylesheet writes them.
    public init(hex: Int) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }

    /// This colour at an opacity over a background, as it ends up on screen.
    public func over(_ background: PaletteColor, opacity: Double) -> PaletteColor {
        PaletteColor(
            red: red * opacity + background.red * (1 - opacity),
            green: green * opacity + background.green * (1 - opacity),
            blue: blue * opacity + background.blue * (1 - opacity))
    }

    public var color: Color { Color(red: red, green: green, blue: blue) }

    /// Relative luminance, as WCAG defines it.
    public var luminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// The contrast ratio between two colours, from 1 to 21.
    public func contrast(with other: PaletteColor) -> Double {
        let lighter = max(luminance, other.luminance)
        let darker = min(luminance, other.luminance)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

/// Every colour labour mode uses, as numbers. `LabourTheme` and `LabourWorld` read from here, and
/// `LabourPaletteTests` checks each pair that carries text.
private enum PaperColorHex {
    static let good = PaletteColor(hex: 0x1F6B47)
    static let teal = PaletteColor(hex: 0x1F5E64)
}

public enum LabourPalette {
    public static let black = PaletteColor(white: 0)
    public static let white = PaletteColor(white: 1)
    public static let surface = PaletteColor(white: 0.11)
    public static let raisedSurface = PaletteColor(white: 0.17)
    public static let secondaryText = PaletteColor(white: 0.68)
    public static let amber = PaletteColor(red: 1.0, green: 0.69, blue: 0.0)
    /// Bright orange for strokes, icons and text on black. Never put white text on it (2.8:1).
    public static let urgent = PaletteColor(red: 1.0, green: 0.42, blue: 0.21)
    /// A deeper red-orange for "call now" panels and flags that carry white text.
    public static let urgentFill = PaletteColor(hex: 0xB3301C)
    public static let emergency = PaletteColor(red: 0.89, green: 0.16, blue: 0.15)
    public static let blueprint = PaletteColor(red: 0.55, green: 0.72, blue: 0.91)

    public static let callAccent = PaletteColor(red: 1.0, green: 0.61, blue: 0.54)
    /// The Call tab's plate, the prototype's #3A1310.
    public static let callSurface = PaletteColor(hex: 0x3A1310)
    /// The Call tab's background, top and bottom: the prototype's #2A0C09 to #12060A.
    public static let callTop = PaletteColor(hex: 0x2A0C09)
    public static let callBottom = PaletteColor(hex: 0x12060A)
    public static let coachAccent = PaletteColor(red: 0.5, green: 0.85, blue: 0.78)
    public static let coachSurface = PaletteColor(red: 0.09, green: 0.27, blue: 0.29)
    public static let decoderAccent = blueprint
    public static let decoderSurface = PaletteColor(red: 0.06, green: 0.11, blue: 0.24)
    /// The printed sheets: the birth plan and the call script.
    public static let paper = PaletteColor(red: 0.98, green: 0.96, blue: 0.89)
    public static let cream = PaletteColor(hex: 0xF4E8D0)
    /// The prototype's paper ink: text on cream.
    public static let ink = PaletteColor(hex: 0x1C2147)
    public static let redInk = PaletteColor(hex: 0xB3301C)

    // The orbit look from the agreed prototype (v3), for labour mode. Hex values from its stylesheet.
    /// The darkest band of the night sky.
    public static let space = PaletteColor(hex: 0x05060F)
    /// The lowest, lightest band of the sky, just above the Earth.
    public static let lowSky = PaletteColor(hex: 0x101737)
    /// The Earth's top edge, behind "They've stopped".
    public static let earth = PaletteColor(hex: 0x1D4B7A)
    public static let muted = PaletteColor(hex: 0xB3AFD2)
    public static let sun = PaletteColor(hex: 0xF6C24A)
    /// The prototype's signal red. Borders and strokes only: cream text on it is 3.3:1, so panels
    /// with text use `urgentFill`, the prototype's own darker "signal text" red.
    public static let signal = PaletteColor(hex: 0xE5482F)
    /// Dark navy text on sun.
    public static let navy = PaletteColor(hex: 0x141A3A)
    public static let paperMuted = PaletteColor(hex: 0x5B5A72)
    /// The level strip's unlit chips.
    public static let levelChip = PaletteColor(hex: 0x141A3D)
    /// The plan's sheet, its rules, and the brown-orange "not checked" stamp.
    public static let paperHi = PaletteColor(hex: 0xFBF4E4)
    public static let paperEdge = PaletteColor(hex: 0xE2D1AE)
    public static let amberText = PaletteColor(hex: 0x8A5200)
    /// The set-up sheets' green for "Dials 01632 960118", and the teal of the hospital's card.
    public static let okText = PaperColorHex.good
    public static let tealText = PaperColorHex.teal
    /// The tabs' backgrounds, top and bottom: the plan's desk, the coach's teal and the decoder's blueprint.
    public static let planTop = PaletteColor(hex: 0x221D15)
    public static let planBottom = PaletteColor(hex: 0x14110C)
    public static let coachTop = PaletteColor(hex: 0x0D3A3C)
    public static let coachBottom = PaletteColor(hex: 0x061C1E)
    public static let decoderBlue = PaletteColor(hex: 0x0A1430)
    /// The coach's cards: the prototype's teal at 28% over its background.
    public static let coachCard = PaletteColor(hex: 0x2E7C83).over(coachTop, opacity: 0.28)
    /// The coach's mint, and the paler mint of "Routine" in the decoder.
    public static let mint = PaletteColor(hex: 0x7FD8C8)
    public static let paleMint = PaletteColor(hex: 0x9FE3D6)

    /// The practice run's cyan, deep teal and pale ink.
    public static let sim = PaletteColor(hex: 0x7FD8E8)
    public static let simDeep = PaletteColor(hex: 0x0E2A3A)
    public static let simInk = PaletteColor(hex: 0xCFF4FA)

    /// A text colour on a background, and the contrast it needs.
    public struct Pair: Sendable {
        public var name: String
        public var text: PaletteColor
        public var background: PaletteColor
        /// 4.5 for body text, 3 for large text (18pt, or 14pt bold).
        public var minimum: Double
    }

    /// Every text-on-background pair the labour screens use.
    public static let textPairs: [Pair] = {
        let darks: [(String, PaletteColor)] = [
            ("black", black), ("surface", surface), ("raised surface", raisedSurface),
            ("call surface", callSurface), ("coach surface", coachSurface), ("decoder surface", decoderSurface),
        ]
        var pairs: [Pair] = []
        for (name, background) in darks {
            pairs.append(Pair(name: "white on \(name)", text: white, background: background, minimum: 4.5))
            pairs.append(
                Pair(name: "secondary on \(name)", text: secondaryText, background: background, minimum: 4.5))
        }
        for (name, background) in darks.prefix(3) {
            pairs += [
                Pair(name: "amber on \(name)", text: amber, background: background, minimum: 4.5),
                Pair(name: "urgent on \(name)", text: urgent, background: background, minimum: 4.5),
                Pair(name: "blueprint on \(name)", text: blueprint, background: background, minimum: 4.5),
            ]
        }
        pairs += [
            Pair(name: "call accent on call surface", text: callAccent, background: callSurface, minimum: 4.5),
            Pair(name: "coach accent on coach surface", text: coachAccent, background: coachSurface, minimum: 4.5),
            Pair(
                name: "decoder accent on decoder surface", text: decoderAccent, background: decoderSurface,
                minimum: 4.5),
            Pair(name: "black on amber", text: black, background: amber, minimum: 4.5),
            Pair(name: "black on blueprint", text: black, background: blueprint, minimum: 4.5),
            Pair(name: "white on urgent fill", text: white, background: urgentFill, minimum: 4.5),
            Pair(name: "white on emergency", text: white, background: emergency, minimum: 4.5),
            Pair(name: "ink on paper", text: ink, background: paper, minimum: 4.5),
            Pair(name: "red ink on paper", text: redInk, background: paper, minimum: 4.5),
            Pair(name: "ink on cream", text: ink, background: cream, minimum: 4.5),
            Pair(name: "red ink on cream", text: redInk, background: cream, minimum: 4.5),
            Pair(name: "paper on ink", text: paper, background: ink, minimum: 4.5),
        ]
        // The orbit timer.
        for (name, background) in [("space", space), ("low sky", lowSky)] {
            pairs += [
                Pair(name: "cream on \(name)", text: cream, background: background, minimum: 4.5),
                Pair(name: "muted on \(name)", text: muted, background: background, minimum: 4.5),
                Pair(name: "sun on \(name)", text: sun, background: background, minimum: 4.5),
                Pair(name: "sim on \(name)", text: sim, background: background, minimum: 4.5),
            ]
        }
        pairs += [
            Pair(name: "cream on earth", text: cream, background: earth, minimum: 4.5),
            Pair(name: "muted on level chip", text: muted, background: levelChip, minimum: 4.5),
            Pair(name: "cream on level chip", text: cream, background: levelChip, minimum: 4.5),
            Pair(name: "call accent on level chip", text: callAccent, background: levelChip, minimum: 4.5),
            Pair(name: "navy on sun", text: navy, background: sun, minimum: 4.5),
            Pair(
                name: "navy 70% on sun", text: navy.over(sun, opacity: 0.7), background: sun, minimum: 4.5),
            Pair(name: "cream on urgent fill", text: cream, background: urgentFill, minimum: 4.5),
            Pair(name: "paper muted on cream", text: paperMuted, background: cream, minimum: 4.5),
            Pair(name: "cream on ink", text: cream, background: ink, minimum: 4.5),
            Pair(name: "sim deep on sim", text: simDeep, background: sim, minimum: 4.5),
            Pair(name: "sim ink on sim deep", text: simInk, background: simDeep, minimum: 4.5),
            Pair(
                name: "cream on info card", text: cream, background: blueprint.over(space, opacity: 0.14),
                minimum: 4.5),
        ]
        // The Call tab.
        for (name, background) in [("call top", callTop), ("call bottom", callBottom), ("call plate", callSurface)] {
            pairs += [
                Pair(name: "cream on \(name)", text: cream, background: background, minimum: 4.5),
                Pair(name: "muted on \(name)", text: muted, background: background, minimum: 4.5),
                Pair(name: "call accent on \(name)", text: callAccent, background: background, minimum: 4.5),
                Pair(
                    name: "cream on a small call button on \(name)", text: cream,
                    background: cream.over(background, opacity: 0.1), minimum: 4.5),
            ]
        }
        pairs += [
            Pair(
                name: "cream 75% on call plate", text: cream.over(callSurface, opacity: 0.75), background: callSurface,
                minimum: 4.5),
            Pair(
                name: "copy ink on call plate", text: PaletteColor(hex: 0xFFC4B8), background: callSurface, minimum: 4.5
            ),
            Pair(name: "sim ink on sim deep, practice dial", text: simInk, background: simDeep, minimum: 4.5),
        ]
        // Plan, Coach and Decoder.
        let avoidBox = signal.over(coachCard, opacity: 0.12)
        pairs += [
            // The set-up sheets, on paper and (inside labour mode) at night.
            Pair(name: "ok green on paper", text: okText, background: cream, minimum: 4.5),
            Pair(name: "ok green on a paper box", text: okText, background: paperHi, minimum: 4.5),
            Pair(name: "amber text on paper", text: amberText, background: cream, minimum: 4.5),
            Pair(name: "paper ink on a paper box", text: ink, background: paperHi, minimum: 4.5),
            Pair(name: "cream on the teal card", text: cream, background: tealText, minimum: 4.5),
            Pair(
                name: "cream 80% on the teal card", text: cream.over(tealText, opacity: 0.8), background: tealText,
                minimum: 4.5),
            Pair(name: "mint on night", text: mint, background: space, minimum: 4.5),
            Pair(name: "mint on a night box", text: mint, background: levelChip, minimum: 4.5),
            Pair(name: "call accent on night", text: callAccent, background: space, minimum: 4.5),
            Pair(name: "sun on a night box", text: sun, background: levelChip, minimum: 4.5),
            Pair(name: "paper ink on cream, night solid button", text: ink, background: cream, minimum: 4.5),
            // The watch.
            Pair(
                name: "cream on the watch's quiet pill", text: cream, background: cream.over(space, opacity: 0.1),
                minimum: 4.5),
            Pair(
                name: "muted on a watch call row", text: muted, background: cream.over(callTop, opacity: 0.1),
                minimum: 4.5),
            Pair(name: "cream on sim deep", text: cream, background: simDeep, minimum: 4.5),
            Pair(name: "sim on sim deep", text: sim, background: simDeep, minimum: 4.5),
            Pair(
                name: "sim ink on the drill question box", text: simInk, background: sim.over(simDeep, opacity: 0.08),
                minimum: 4.5),
            Pair(name: "cream on the launch cover", text: cream, background: PaletteColor(hex: 0x1A2046), minimum: 4.5),
            Pair(name: "muted on the launch cover", text: muted, background: PaletteColor(hex: 0x1A2046), minimum: 4.5),
            Pair(name: "paper ink on the plan sheet", text: ink, background: paperHi, minimum: 4.5),
            Pair(name: "paper muted on the plan sheet", text: paperMuted, background: paperHi, minimum: 4.5),
            Pair(name: "red ink on the plan sheet", text: redInk, background: paperHi, minimum: 4.5),
            Pair(name: "amber text on the plan sheet", text: amberText, background: paperHi, minimum: 4.5),
            Pair(name: "signal numbers on the plan sheet (32pt)", text: signal, background: paperHi, minimum: 3),
            Pair(name: "sun on the plan desk", text: sun, background: planTop, minimum: 4.5),
            Pair(name: "cream on the plan desk", text: cream, background: planTop, minimum: 4.5),
            Pair(name: "muted on the plan desk", text: muted, background: planTop, minimum: 4.5),
            Pair(name: "cream on a coach card", text: cream, background: coachCard, minimum: 4.5),
            Pair(name: "muted on a coach card", text: muted, background: coachCard, minimum: 4.5),
            Pair(name: "cream on the coach top", text: cream, background: coachTop, minimum: 4.5),
            Pair(name: "muted on the coach top", text: muted, background: coachTop, minimum: 4.5),
            Pair(name: "mint on the coach top", text: mint, background: coachTop, minimum: 4.5),
            Pair(name: "call accent on the avoid box", text: callAccent, background: avoidBox, minimum: 4.5),
            Pair(name: "cream on the avoid box", text: cream, background: avoidBox, minimum: 4.5),
            Pair(
                name: "cream 82% on the decoder", text: cream.over(decoderBlue, opacity: 0.82), background: decoderBlue,
                minimum: 4.5),
            Pair(name: "cream on the decoder", text: cream, background: decoderBlue, minimum: 4.5),
            Pair(name: "blueprint on the decoder", text: blueprint, background: decoderBlue, minimum: 4.5),
            Pair(name: "muted on the decoder", text: muted, background: decoderBlue, minimum: 4.5),
            Pair(
                name: "routine badge", text: paleMint, background: mint.over(decoderBlue, opacity: 0.16),
                minimum: 4.5),
            Pair(
                name: "worth asking badge", text: blueprint, background: blueprint.over(decoderBlue, opacity: 0.16),
                minimum: 4.5),
            Pair(
                name: "watch closely badge", text: sun, background: sun.over(decoderBlue, opacity: 0.18), minimum: 4.5),
            Pair(
                name: "serious badge", text: callAccent, background: signal.over(decoderBlue, opacity: 0.22),
                minimum: 4.5),
        ]
        return pairs
    }()
}
