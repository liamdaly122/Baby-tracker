import Foundation

/// A state with the reasons behind it.
public struct Advice: Codable, Sendable, Hashable {
    public var state: LabourState
    public var reasons: [ReasonCode]

    public init(state: LabourState, reasons: [ReasonCode]) {
        self.state = state
        self.reasons = reasons
    }
}

/// The contraction-driven advice as currently shown, which only drops after a dwell.
public struct HeldAdvice: Codable, Sendable, Hashable {
    public var advice: Advice
    public var enteredAt: Date
    /// Set while contractions point to a lower state and the 15-minute dwell is running.
    public var pendingDrop: PendingDrop?
}

public struct PendingDrop: Codable, Sendable, Hashable {
    /// The highest lower state seen since contractions eased. The advice drops to this, not lower.
    public var target: Advice
    public var since: Date
}

/// Rises are immediate. A drop needs the lower state's conditions to hold for
/// `EngineConstants.demotionDwellSec`; meanwhile the UI shows "pattern easing".
enum Hysteresis {
    static func apply(raw: Advice, previous: HeldAdvice?, now: Date) -> HeldAdvice {
        guard let previous else {
            return HeldAdvice(advice: raw, enteredAt: now, pendingDrop: nil)
        }
        if raw.state > previous.advice.state {
            return HeldAdvice(advice: raw, enteredAt: now, pendingDrop: nil)
        }
        if raw.state == previous.advice.state {
            return HeldAdvice(advice: raw, enteredAt: previous.enteredAt, pendingDrop: nil)
        }

        var pending = previous.pendingDrop ?? PendingDrop(target: raw, since: now)
        if raw.state >= pending.target.state {
            pending.target = raw
        }
        guard now.timeIntervalSince(pending.since) >= EngineConstants.demotionDwellSec else {
            return HeldAdvice(advice: previous.advice, enteredAt: previous.enteredAt, pendingDrop: pending)
        }
        // The dwell is over. If contractions have eased further since, a fresh dwell starts now.
        let next = raw.state < pending.target.state ? PendingDrop(target: raw, since: now) : nil
        return HeldAdvice(advice: pending.target, enteredAt: now, pendingDrop: next)
    }
}
