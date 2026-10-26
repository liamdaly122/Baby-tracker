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

extension EnvironmentValues {
    /// How much humour copy carries. The labour root forces `.off`.
    @Entry public var humourLevel: HumourLevel = .mild
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
