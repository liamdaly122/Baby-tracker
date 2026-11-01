import MissionCore
import SwiftUI

/// Labour-mode look: true black, high-contrast amber and white, controls big enough for one thumb
/// in a dark room. Bright fills are kept for the two states that need to shout. Colours come from
/// `LabourPalette`, where their contrast is tested; the redesign rules are in docs/redesign-rules.md.
public enum LabourTheme {
    public static let background = LabourPalette.black.color
    public static let surface = LabourPalette.surface.color
    public static let raisedSurface = LabourPalette.raisedSurface.color
    public static let primaryText = LabourPalette.white.color
    public static let secondaryText = LabourPalette.secondaryText.color
    public static let amber = LabourPalette.amber.color
    /// Bright orange for strokes, icons and text on black. Panels with text use `fill(for:)`.
    public static let urgent = LabourPalette.urgent.color
    public static let emergency = LabourPalette.emergency.color
    /// The practice run's colour: the prototype's pale blueprint blue, never a state colour.
    public static let blueprint = LabourPalette.blueprint.color
    /// Every control in labour mode is at least this tall.
    public static let minimumControlSize: CGFloat = 56
    /// The tap area of a small choice chip, such as "Mild" or "+1 min".
    public static let chipSize: CGFloat = 44
    public static let cornerRadius: CGFloat = 20

    /// The accent for a state: strokes, icons and text on black.
    public static func color(for state: LabourState) -> Color {
        switch state {
        case .early: secondaryText
        case .establishing: amber.opacity(0.8)
        case .callTriage: amber
        case .callNow: urgent
        case .call999: emergency
        }
    }

    /// Whether the banner for a state is a solid fill rather than an outline.
    public static func isFilled(_ state: LabourState) -> Bool {
        state >= .callNow
    }

    /// A solid panel for a state, dark enough to carry `textOnFill(for:)`.
    public static func fill(for state: LabourState) -> Color {
        fillPalette(for: state).color
    }

    /// The text colour on `fill(for:)`.
    public static func textOnFill(for state: LabourState) -> Color {
        textOnFillPalette(for: state).color
    }

    public static func fillPalette(for state: LabourState) -> PaletteColor {
        switch state {
        case .early, .establishing: LabourPalette.raisedSurface
        case .callTriage: LabourPalette.amber
        case .callNow: LabourPalette.urgentFill
        case .call999: LabourPalette.emergency
        }
    }

    public static func textOnFillPalette(for state: LabourState) -> PaletteColor {
        state == .callTriage ? LabourPalette.black : LabourPalette.white
    }
}

/// Which red flags the timer shows first, and the rest. Built from every flag, so a new one can't
/// be left off the screen.
public enum RedFlagLayout {
    /// Always on the timer.
    public static let pinned: [RedFlag] = [.reducedMovements, .watersBroken]
    /// One tap away, in the order `RedFlag` lists them.
    public static var others: [RedFlag] { RedFlag.allCases.filter { !pinned.contains($0) } }
}

extension RedFlag {
    /// What the toggle says, short enough for the watch.
    public var label: String {
        switch self {
        case .reducedMovements: "Baby moving less"
        case .watersBroken: "Waters broke"
        case .watersColoured: "Waters green, brown or smelly"
        case .bleeding: "Bleeding"
        case .heavyBleeding: "Heavy bleeding"
        case .urgeToPush: "Strong urge to push"
        case .cordVisible: "Cord felt or seen"
        case .seizureCollapse: "Seizure or collapse"
        case .severePain: "Constant or severe pain"
        case .preEclampsiaSigns: "Bad headache or vision changes"
        case .headVisible: "Baby's head visible"
        }
    }

    /// What the flag means, where the label alone isn't enough. NHS wording.
    public var detail: String? {
        switch self {
        case .bleeding: "More than a small pink-tinged show"
        case .heavyBleeding: "Soaks a pad soon after, or with severe pain, faintness or dizziness"
        case .severePain: "No break between contractions"
        case .preEclampsiaSigns: "Or pain below the ribs, sudden swelling, feeling very unwell"
        case .watersBroken, .watersColoured, .reducedMovements, .urgeToPush, .cordVisible, .seizureCollapse,
            .headVisible:
            nil
        }
    }

    public var icon: String {
        switch self {
        case .reducedMovements: "heart.text.square"
        case .watersBroken, .watersColoured: "drop.fill"
        case .bleeding, .heavyBleeding: "drop.triangle.fill"
        case .urgeToPush: "arrow.down.to.line"
        case .cordVisible: "exclamationmark.octagon.fill"
        case .seizureCollapse: "bolt.heart.fill"
        case .severePain: "bolt.fill"
        case .preEclampsiaSigns: "eye.trianglebadge.exclamationmark"
        case .headVisible: "exclamationmark.triangle.fill"
        }
    }
}

/// A real labour, or a practice run. A practice run is labelled SIMULATION on every screen, its
/// headlines start "SIM:", and nothing in it dials.
public enum MissionMode: Sendable {
    case live
    case practice

    /// "SIM: Time to call your maternity unit" in a practice run.
    public func headline(_ text: String) -> String {
        self == .practice ? "SIM: \(text)" : text
    }

    /// What VoiceOver reads for a headline: "Practice." first in a practice run.
    public func spokenHeadline(_ text: String) -> String {
        self == .practice ? "Practice. \(text)" : text
    }
}

extension EnvironmentValues {
    /// How much humour copy carries. The labour root forces `.off`.
    @Entry public var humourLevel: HumourLevel = .mild
    @Entry public var missionMode: MissionMode = .live
}

/// "4:05" or "1:02:10".
public func clockText(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded(.down)))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60
    let paddedSeconds = secs < 10 ? "0\(secs)" : "\(secs)"
    if hours > 0 {
        let paddedMinutes = minutes < 10 ? "0\(minutes)" : "\(minutes)"
        return "\(hours):\(paddedMinutes):\(paddedSeconds)"
    }
    return "\(minutes):\(paddedSeconds)"
}
