import Foundation

/// Combines event logs from the phone and the watch.
public enum EventMerger {
    /// Union of both logs, deduplicated by ID, in the agreed order.
    public static func merge(_ local: [TapEvent], _ remote: [TapEvent]) -> [TapEvent] {
        ordered(local + remote)
    }

    /// Deduplicated by ID (first copy wins) and sorted by `TapEvent.precedes`.
    public static func ordered(_ events: [TapEvent]) -> [TapEvent] {
        var seen: Set<UUID> = []
        return events.filter { seen.insert($0.id).inserted }.sorted(by: TapEvent.precedes)
    }

    /// The highest Lamport value seen from each device. A device's own events have strictly
    /// increasing Lamport values, so this tells a peer exactly which events it's missing.
    public static func highWaterMarks(_ events: [TapEvent]) -> [String: UInt64] {
        events.reduce(into: [:]) { marks, event in
            marks[event.deviceID] = max(marks[event.deviceID] ?? 0, event.lamport)
        }
    }

    /// The events a peer hasn't seen yet, given the high-water marks it reported.
    public static func events(_ events: [TapEvent], newerThan marks: [String: UInt64]) -> [TapEvent] {
        ordered(events.filter { $0.lamport > marks[$0.deviceID] ?? 0 })
    }
}
