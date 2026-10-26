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

    public var activeRedFlags: Set<RedFlag> {
        Set(redFlags.filter(\.value.isOn).keys)
    }

    /// The latest contraction that is still being timed, if any.
    public var openContraction: Contraction? {
        contractions.last { $0.end == nil }
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
        var redFlags: [RedFlag: RedFlagStatus] = [:]

        func resolve(_ id: UUID?) -> Int? {
            guard var id else { return nil }
            var hops = 0
            while let next = aliases[id], hops < 64 {
                id = next
                hops += 1
            }
            return contractions.firstIndex { $0.id == id }
        }

        for event in ordered where !cancelled.contains(event.id) {
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
            case .redFlag:
                if let flag = event.payload?.flag, let isOn = event.payload?.isOn {
                    redFlags[flag] = RedFlagStatus(isOn: isOn, changedAt: event.at)
                }
            case .undo:
                break
            }
        }

        return ReducedLog(contractions: contractions.sorted(by: ContractionMetrics.chronological), redFlags: redFlags)
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
