import Foundation

public struct RedFlagStatus: Codable, Sendable, Hashable {
    public var isOn: Bool
    public var changedAt: Date
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

    public init(
        contractions: [Contraction] = [],
        redFlags: [RedFlag: RedFlagStatus] = [:],
        lastMovementAt: Date? = nil,
        easedAt: Date? = nil,
        termAnswer: TermAnswer? = nil
    ) {
        self.contractions = contractions
        self.redFlags = redFlags
        self.lastMovementAt = lastMovementAt
        self.easedAt = easedAt
        self.termAnswer = termAnswer
    }

    public var activeRedFlags: Set<RedFlag> {
        Set(redFlags.filter(\.value.isOn).keys)
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
            case .redFlag, .movement, .eased, .termAnswer, .undo, .unknown:
                break
            }
        }

        return ReducedLog(
            contractions: contractions.sorted(by: ContractionMetrics.chronological),
            redFlags: notes.redFlags,
            lastMovementAt: notes.lastMovementAt,
            easedAt: notes.easedAt,
            termAnswer: notes.termAnswer
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

    /// Applies `event` if it's an annotation, and says whether it was.
    mutating func apply(_ event: TapEvent) -> Bool {
        switch event.kind {
        case .redFlag:
            if let flag = event.payload?.flag, let isOn = event.payload?.isOn {
                redFlags[flag] = RedFlagStatus(isOn: isOn, changedAt: event.at)
            }
        case .movement:
            lastMovementAt = max(lastMovementAt ?? event.at, event.at)
        case .eased:
            easedAt = max(easedAt ?? event.at, event.at)
        case .termAnswer:
            if let term = event.payload?.term {
                termAnswer = term
            }
        case .start, .stop, .editStart, .editStop, .delete, .merge, .undo, .unknown:
            return false
        }
        return true
    }
}
