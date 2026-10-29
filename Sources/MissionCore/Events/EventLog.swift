import Foundation

public struct RedFlagStatus: Codable, Sendable, Hashable {
    public var isOn: Bool
    /// When it was last switched: the tap.
    public var changedAt: Date
    /// When it last went on, by what he said (her waters went 40 minutes ago), or the tap time if
    /// he didn't say. Kept after it's turned off, so the call script can mention it.
    public var happenedAt: Date?
    /// He said when it happened, so `happenedAt` isn't just the tap.
    public var timeGiven: Bool
    /// Earlier times it was on and then turned off, oldest first, so the call script keeps them
    /// when it goes on again.
    public var earlier: [FlagEpisode]

    public init(
        isOn: Bool, changedAt: Date, happenedAt: Date? = nil, timeGiven: Bool = false, earlier: [FlagEpisode] = []
    ) {
        self.isOn = isOn
        self.changedAt = changedAt
        self.happenedAt = happenedAt
        self.timeGiven = timeGiven
        self.earlier = earlier
    }
}

/// A time a red flag was on: when it happened, and when he turned it off.
public struct FlagEpisode: Codable, Sendable, Hashable {
    public var onAt: Date
    public var offAt: Date
    /// He said when it happened, so `onAt` isn't just the tap.
    public var timeGiven: Bool

    public init(onAt: Date, offAt: Date, timeGiven: Bool = false) {
        self.onAt = onAt
        self.offAt = offAt
        self.timeGiven = timeGiven
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        onAt = try container.decode(Date.self, forKey: .onAt)
        offAt = try container.decode(Date.self, forKey: .offAt)
        timeGiven = try container.decodeIfPresent(Bool.self, forKey: .timeGiven) ?? false
    }
}

/// A call to the unit as logged.
public struct LoggedCall: Sendable, Hashable {
    public var at: Date
    public var note: CallNote

    public init(at: Date, note: CallNote) {
        self.at = at
        self.note = note
    }
}

/// The state derived from a session's tap events.
public struct ReducedLog: Sendable, Hashable {
    /// Live contractions in start order.
    public var contractions: [Contraction]
    public var redFlags: [RedFlag: RedFlagStatus]
    /// The latest time she felt the baby move, if it was logged.
    public var lastMovementAt: Date?
    /// The latest time he said the contractions have stopped. A later start within 3× the pace cancels
    /// it as a mis-tap; otherwise the next contraction starts a new run.
    public var easedAt: Date?
    /// The latest answer to "Is she 37 weeks or more?".
    public var termAnswer: TermAnswer?
    /// The latest call to the unit he logged.
    public var lastCall: LoggedCall?
    /// How strong contractions felt, by contraction ID, where he said.
    public var strengths: [UUID: ContractionStrength]

    public init(
        contractions: [Contraction] = [],
        redFlags: [RedFlag: RedFlagStatus] = [:],
        lastMovementAt: Date? = nil,
        easedAt: Date? = nil,
        termAnswer: TermAnswer? = nil,
        lastCall: LoggedCall? = nil,
        strengths: [UUID: ContractionStrength] = [:]
    ) {
        self.contractions = contractions
        self.redFlags = redFlags
        self.lastMovementAt = lastMovementAt
        self.easedAt = easedAt
        self.termAnswer = termAnswer
        self.lastCall = lastCall
        self.strengths = strengths
    }

    public var activeRedFlags: Set<RedFlag> {
        Set(redFlags.filter(\.value.isOn).keys)
    }

    /// Flags that were on and have been turned off, with when they were turned off.
    public var clearedRedFlags: [RedFlag: Date] {
        redFlags.filter { !$0.value.isOn && $0.value.happenedAt != nil }.mapValues(\.changedAt)
    }

    /// The latest contraction, if it's still being timed. An earlier one without an end is a
    /// forgotten stop to fix, never what the next tap stops.
    public var openContraction: Contraction? {
        contractions.last.flatMap { $0.end == nil ? $0 : nil }
    }
}

public enum EventLog {
    /// Two starts from different devices this close together, with no stop between, are one contraction.
    public static let coalesceWindowSec: TimeInterval = 20

    /// Rebuilds contractions and red flags from events. Deterministic and idempotent: duplicates are
    /// dropped and events are put in their agreed order first, so any arrival order gives the same
    /// result. Edits and deletes are last-writer-wins by that order.
    public static func reduce(_ events: [TapEvent]) -> ReducedLog {
        let ordered = EventMerger.ordered(events)
        let cancelled = cancelledEventIDs(ordered)

        var contractions: [Contraction] = []
        var startDevice: [UUID: String] = [:]
        var aliases: [UUID: UUID] = [:]
        var notes = Annotations()
        var strengths: [UUID: ContractionStrength] = [:]

        func resolve(_ id: UUID?) -> Int? {
            guard var id else { return nil }
            var hops = 0
            while let next = aliases[id], hops < 64 {
                id = next
                hops += 1
            }
            return contractions.firstIndex { $0.id == id }
        }

        for event in ordered where !cancelled.contains(event.id) && !notes.apply(event) {
            switch event.kind {
            case .start:
                if let open = latestOpenIndex(contractions),
                    startDevice[contractions[open].id] != event.deviceID,
                    abs(contractions[open].start.timeIntervalSince(event.at)) <= coalesceWindowSec
                {
                    // Phone and watch both pressed start for the same contraction.
                    aliases[event.id] = contractions[open].id
                    contractions[open].start = min(contractions[open].start, event.at)
                } else {
                    contractions.append(Contraction(id: event.id, start: event.at, end: nil))
                    startDevice[event.id] = event.deviceID
                }
            case .stop:
                let index = event.target == nil ? latestOpenIndex(contractions) : resolve(event.target)
                if let index, contractions[index].end == nil {
                    contractions[index].end = event.at
                }
            case .editStart:
                if let index = resolve(event.target), let time = event.payload?.time {
                    contractions[index].start = time
                }
            case .editStop:
                if let index = resolve(event.target), let time = event.payload?.time {
                    contractions[index].end = time
                }
            case .delete:
                if let index = resolve(event.target) {
                    contractions.remove(at: index)
                }
            case .merge:
                guard let index = resolve(event.target) else { break }
                let merged = contractions[index]
                guard
                    let previous = contractions.indices
                        .filter({ ContractionMetrics.chronological(contractions[$0], merged) })
                        .max(by: { ContractionMetrics.chronological(contractions[$0], contractions[$1]) })
                else { break }
                if let mergedEnd = merged.end {
                    contractions[previous].end = max(mergedEnd, contractions[previous].end ?? mergedEnd)
                } else {
                    contractions[previous].end = nil
                }
                aliases[merged.id] = contractions[previous].id
                contractions.remove(at: index)
            case .strength:
                if let index = resolve(event.target), let strength = event.payload?.strength {
                    strengths[contractions[index].id] = strength
                }
            case .redFlag, .movement, .eased, .termAnswer, .called, .undo, .unknown:
                break
            }
        }

        return ReducedLog(
            contractions: contractions.sorted(by: ContractionMetrics.chronological),
            redFlags: notes.redFlags,
            lastMovementAt: notes.lastMovementAt,
            easedAt: notes.easedAt,
            termAnswer: notes.termAnswer,
            lastCall: notes.lastCall,
            strengths: strengths.filter { id, _ in contractions.contains { $0.id == id } }
        )
    }

    /// IDs cancelled by undo events. Later undos are applied first, so undoing an undo restores
    /// the original event.
    static func cancelledEventIDs(_ ordered: [TapEvent]) -> Set<UUID> {
        var cancelled: Set<UUID> = []
        for event in ordered.reversed() where event.kind == .undo && !cancelled.contains(event.id) {
            if let target = event.target {
                cancelled.insert(target)
            }
        }
        return cancelled
    }

    private static func latestOpenIndex(_ contractions: [Contraction]) -> Int? {
        contractions.indices
            .filter { contractions[$0].end == nil }
            .max { ContractionMetrics.chronological(contractions[$0], contractions[$1]) }
    }
}

/// Everything in the log that isn't a contraction: red flags, movements and his answers.
private struct Annotations {
    var redFlags: [RedFlag: RedFlagStatus] = [:]
    var lastMovementAt: Date?
    var easedAt: Date?
    var termAnswer: TermAnswer?
    var lastCall: LoggedCall?

    /// Applies `event` if it's an annotation, and says whether it was.
    mutating func apply(_ event: TapEvent) -> Bool {
        switch event.kind {
        case .redFlag:
            if let flag = event.payload?.flag {
                applyFlag(flag, event)
            }
        case .called:
            if let note = event.payload?.call, lastCall.map({ event.at >= $0.at }) ?? true {
                lastCall = LoggedCall(at: event.at, note: note)
            }
        case .movement:
            lastMovementAt = max(lastMovementAt ?? event.at, event.at)
        case .eased:
            easedAt = max(easedAt ?? event.at, event.at)
        case .termAnswer:
            if let term = event.payload?.term {
                termAnswer = term
            }
        case .start, .stop, .editStart, .editStop, .delete, .merge, .strength, .undo, .unknown:
            return false
        }
        return true
    }

    /// On, off, or a time on its own. A second "on" for the same episode (from the other device)
    /// can only move it earlier, to the first tap, whichever sorts first: it can't have happened
    /// after anyone tapped it. Only a time he gave marks it as given. A time on its own never turns
    /// a flag back on that was turned off meanwhile. Turning a flag on again after it was off is a
    /// new tap with a new time; the earlier episode is kept.
    private mutating func applyFlag(_ flag: RedFlag, _ event: TapEvent) {
        let previous = redFlags[flag]
        let time = event.payload?.time.map { min($0, event.at) }
        let wasOn = previous?.isOn ?? false
        switch (event.payload?.isOn, wasOn) {
        case (nil, _), (true?, true):
            guard var status = previous, status.isOn else { break }
            if event.payload?.isOn == true, event.at > (status.earlier.last?.offAt ?? .distantPast) {
                status.changedAt = min(status.changedAt, event.at)
                status.happenedAt = min(status.happenedAt ?? event.at, event.at)
            }
            if let time {
                status.happenedAt = min(time, status.changedAt)
                status.timeGiven = true
            }
            redFlags[flag] = status
        case (true?, false):
            var earlier = previous?.earlier ?? []
            if let previous, let onAt = previous.happenedAt {
                earlier.append(FlagEpisode(onAt: onAt, offAt: previous.changedAt, timeGiven: previous.timeGiven))
            }
            redFlags[flag] = RedFlagStatus(
                isOn: true, changedAt: event.at, happenedAt: time ?? event.at, timeGiven: time != nil,
                earlier: earlier)
        case (false?, true):
            if var status = previous {
                status.isOn = false
                status.changedAt = event.at
                redFlags[flag] = status
            }
        case (false?, false):
            break  // Already off.
        }
    }
}
