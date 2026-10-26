import Foundation

/// Picks which variant of a piece of copy to show. Labour mode and the Flight Surgeon always get
/// the plain version, whatever the user's setting.
public struct HumourResolver: Sendable, Hashable {
    public var preferred: HumourLevel
    public var isLabourMode: Bool

    public init(preferred: HumourLevel, isLabourMode: Bool = false) {
        self.preferred = preferred
        self.isLabourMode = isLabourMode
    }

    public var effectiveLevel: HumourLevel {
        isLabourMode ? .off : preferred
    }

    public func text(_ copy: LocalizedCopy, speaker: Speaker? = nil) -> String {
        speaker == .flightSurgeon ? copy.off : copy.text(for: effectiveLevel)
    }

    public func title(of briefing: Briefing) -> String {
        text(briefing.title, speaker: briefing.speaker)
    }

    public func body(of briefing: Briefing) -> String {
        text(briefing.body, speaker: briefing.speaker)
    }

    public func title(of item: ChecklistItem) -> String {
        text(item.title)
    }

    public func why(of item: ChecklistItem) -> String {
        text(item.why)
    }
}
