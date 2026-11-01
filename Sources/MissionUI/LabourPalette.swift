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
    public static let urgentFill = PaletteColor(red: 0.70, green: 0.19, blue: 0.11)
    public static let emergency = PaletteColor(red: 0.89, green: 0.16, blue: 0.15)
    public static let blueprint = PaletteColor(red: 0.55, green: 0.72, blue: 0.91)

    public static let callAccent = PaletteColor(red: 1.0, green: 0.61, blue: 0.54)
    public static let callSurface = PaletteColor(red: 0.23, green: 0.07, blue: 0.06)
    public static let coachAccent = PaletteColor(red: 0.5, green: 0.85, blue: 0.78)
    public static let coachSurface = PaletteColor(red: 0.09, green: 0.27, blue: 0.29)
    public static let decoderAccent = blueprint
    public static let decoderSurface = PaletteColor(red: 0.06, green: 0.11, blue: 0.24)
    /// The printed sheets: the birth plan and the call script.
    public static let paper = PaletteColor(red: 0.98, green: 0.96, blue: 0.89)
    public static let cream = PaletteColor(red: 0.96, green: 0.91, blue: 0.82)
    public static let ink = PaletteColor(red: 0.11, green: 0.13, blue: 0.28)
    public static let redInk = PaletteColor(red: 0.7, green: 0.19, blue: 0.11)

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
        return pairs
    }()
}
