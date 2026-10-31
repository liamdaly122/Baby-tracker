import MissionCore
import SwiftUI

/// Labour-mode look: true black, high-contrast amber and white, controls big enough for one thumb
/// in a dark room. Bright fills are kept for the two states that need to shout.
public enum LabourTheme {
    public static let background = Color.black
    public static let surface = Color(white: 0.11)
    public static let raisedSurface = Color(white: 0.17)
    public static let primaryText = Color.white
    public static let secondaryText = Color(white: 0.68)
    public static let amber = Color(red: 1.0, green: 0.69, blue: 0.0)
    public static let urgent = Color(red: 1.0, green: 0.42, blue: 0.21)
    public static let emergency = Color(red: 0.89, green: 0.16, blue: 0.15)
    /// The practice run's colour: the prototype's pale blueprint blue, never a state colour.
    public static let blueprint = Color(red: 0.55, green: 0.72, blue: 0.91)
    public static let minimumControlSize: CGFloat = 56
    public static let cornerRadius: CGFloat = 20

    /// The accent for a state.
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
