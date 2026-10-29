import Foundation

/// Decoding is tolerant: a kind this build doesn't know (from a newer peer) becomes `unknown`, which
/// the log ignores, instead of failing the whole batch.
public enum TapEventKind: String, Codable, Sendable, CaseIterable {
    /// A contraction starts at `at`. The contraction's ID is this event's ID.
    case start
    /// Ends `target` (or the latest open contraction if there's no target) at `at`.
    case stop
    /// Moves the start of `target` to `payload.time`.
    case editStart
    /// Moves (or sets) the end of `target` to `payload.time`.
    case editStop
    /// Removes `target`.
    case delete
    /// Folds `target` into the contraction before it, for a stop pressed mid-contraction.
    case merge
    /// Cancels the event whose ID is `target`. Undoing an undo restores the original.
    case undo
    /// Turns `payload.flag` on or off.
    case redFlag
    /// She felt the baby move at `at`. Triage asks about movements in the last 24 hours.
    case movement
    /// He said the contractions have stopped, at `at`. A later start within 3× the pace cancels it as
    /// a mis-tap; otherwise the next contraction starts a new run.
    case eased
    /// The answer to "Is she 37 weeks or more?" in `payload.term`, when there's no due date.
    case termAnswer
    /// He called the maternity unit, and what they said, in `payload.call`.
    case called
    /// How strong contraction `target` felt, in `payload.strength`.
    case strength
    /// A kind from a newer build. Kept so the event isn't lost, and ignored.
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TapEventKind(rawValue: raw) ?? .unknown
    }
}

public struct TapPayload: Codable, Sendable, Hashable {
    /// For an edit, the new time. For a red flag turned on, when it actually happened (her waters
    /// went 40 minutes ago), if that isn't the tap time.
    public var time: Date?
    public var flag: RedFlag?
    public var isOn: Bool?
    public var term: TermAnswer?
    public var call: CallNote?
    public var strength: ContractionStrength?

    public init(
        time: Date? = nil,
        flag: RedFlag? = nil,
        isOn: Bool? = nil,
        term: TermAnswer? = nil,
        call: CallNote? = nil,
        strength: ContractionStrength? = nil
    ) {
        self.time = time
        self.flag = flag
        self.isOn = isOn
        self.term = term
        self.call = call
        self.strength = strength
    }

    /// Values this build doesn't know (from a newer peer) decode as nil rather than failing.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        time = try container.decodeIfPresent(Date.self, forKey: .time)
        flag = try? container.decodeIfPresent(RedFlag.self, forKey: .flag)
        isOn = try container.decodeIfPresent(Bool.self, forKey: .isOn)
        term = try? container.decodeIfPresent(TermAnswer.self, forKey: .term)
        call = try? container.decodeIfPresent(CallNote.self, forKey: .call)
        strength = try? container.decodeIfPresent(ContractionStrength.self, forKey: .strength)
    }
}

/// What the maternity unit said on the phone.
public enum CallOutcome: String, Codable, Sendable, CaseIterable {
    case comeIn
    case stayHome
    case other
}

/// A call to the unit, and the advice he called about. Anything new after it (a higher level, a new
/// reason, contractions reaching the call point under a flag) means calling back.
public struct CallNote: Codable, Sendable, Hashable {
    public var outcome: CallOutcome
    /// The level showing when he called.
    public var state: LabourState
    /// What the contractions alone said when he called.
    public var contractionState: LabourState
    /// Every reason showing, and the contraction reasons under any flag.
    public var reasons: [ReasonCode]
    /// The rule in use when he called. If the midwife changes it afterwards, what the call
    /// covered is worked out again under the new rule. Nil from a build that didn't record it.
    public var thresholds: ThresholdProfile?

    public init(
        outcome: CallOutcome, state: LabourState, contractionState: LabourState, reasons: [ReasonCode],
        thresholds: ThresholdProfile? = nil
    ) {
        self.outcome = outcome
        self.state = state
        self.contractionState = contractionState
        self.reasons = reasons
        self.thresholds = thresholds
    }

    /// A reason this build doesn't know is dropped rather than losing the whole call.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outcome = (try? container.decode(CallOutcome.self, forKey: .outcome)) ?? .other
        state = try container.decode(LabourState.self, forKey: .state)
        contractionState = try container.decode(LabourState.self, forKey: .contractionState)
        reasons = try container.decode([String].self, forKey: .reasons).compactMap(ReasonCode.init(rawValue:))
        thresholds = try? container.decodeIfPresent(ThresholdProfile.self, forKey: .thresholds)
    }
}

/// How strong a contraction felt, as she or he would put it. Triage asks.
public enum ContractionStrength: String, Codable, Sendable, CaseIterable {
    case mild
    case moderate
    case strong
}

/// One tap on either device. Append-only: contractions are always derived from these, so the
/// phone and the watch never conflict over a contraction, only over event order.
public struct TapEvent: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var sessionID: UUID
    public var kind: TapEventKind
    /// When the tap happened, by the tapping device's clock.
    public var at: Date
    public var deviceID: String
    public var lamport: UInt64
    /// A contraction ID (stop, edits, delete, merge) or an event ID (undo).
    public var target: UUID?
    public var payload: TapPayload?

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        kind: TapEventKind,
        at: Date,
        deviceID: String,
        lamport: UInt64,
        target: UUID? = nil,
        payload: TapPayload? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.kind = kind
        self.at = at
        self.deviceID = deviceID
        self.lamport = lamport
        self.target = target
        self.payload = payload
    }

    /// The total order every device agrees on: Lamport time, then wall time, then device, then ID.
    public static func precedes(_ lhs: TapEvent, _ rhs: TapEvent) -> Bool {
        if lhs.lamport != rhs.lamport { return lhs.lamport < rhs.lamport }
        if lhs.at != rhs.at { return lhs.at < rhs.at }
        if lhs.deviceID != rhs.deviceID { return lhs.deviceID < rhs.deviceID }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

/// A Lamport clock per device. Tick before recording a local event; observe every received event.
public struct LamportClock: Codable, Sendable, Hashable {
    public private(set) var value: UInt64

    public init(value: UInt64 = 0) {
        self.value = value
    }

    public mutating func tick() -> UInt64 {
        value += 1
        return value
    }

    public mutating func observe(_ remote: UInt64) {
        value = max(value, remote)
    }
}
