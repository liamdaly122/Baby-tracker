import Foundation

/// What a tap on the big contraction button does. Shared by the phone and the watch so a tap means
/// the same thing on both.
public enum TapAction: Sendable, Hashable {
    /// Start a new contraction.
    case start
    /// Stop the open contraction at `at` (never before its start, if the other device's clock is ahead).
    case stop(UUID, at: Date)
    /// The open contraction has run past the forgot-to-stop limit. Ask before recording anything:
    /// "It just ended" stops it now, and a real contraction that long is exactly what the unit needs
    /// to hear about; "This is a new one" starts the next contraction and leaves this one flagged to
    /// fix, so a forgotten stop doesn't become a false 10-minute contraction.
    case askIfEndedOrNew(UUID, elapsedSec: TimeInterval)
    /// A second tap straight after a start, not a 1-second contraction. Ignore it.
    case ignoreDoubleTap
}

public enum TapPolicy {
    public static func action(open: Contraction?, now: Date) -> TapAction {
        // A start stamped well in the future is a bad timestamp, not something to stop.
        guard let open, open.start <= now.addingTimeInterval(EngineConstants.futureToleranceSec) else {
            return .start
        }
        let elapsed = now.timeIntervalSince(open.start)
        if abs(elapsed) < EngineConstants.doubleTapSec {
            return .ignoreDoubleTap
        }
        if elapsed > EngineConstants.forgotStopSec {
            return .askIfEndedOrNew(open.id, elapsedSec: elapsed)
        }
        return .stop(open.id, at: max(now, open.start))
    }

    /// Quick fixes for a forgotten stop: "It lasted about 30s / 60s / 90s", and "It really lasted
    /// all of it" so a genuinely long contraction isn't fixed away.
    public static func forgottenStopFixesSec(elapsed: TimeInterval) -> [TimeInterval] {
        Array(Set([30, 60, 90, elapsed.rounded()])).sorted()
    }
}
