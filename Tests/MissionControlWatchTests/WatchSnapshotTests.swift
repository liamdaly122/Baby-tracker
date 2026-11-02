import MissionCore
import MissionUI
import SwiftUI
import Testing

@testable import MissionControlWatch

/// Picture tests for the redesigned watch (redesign rule 9): the advice pill at every level, the
/// main screen at the levels that change it, a contraction running, the question card, a call row
/// and LAUNCH, at the smallest, normal and largest text sizes, on a 49 mm screen's width. The watch
/// has no practice run, so there's no practice version.
@MainActor
@Suite("Watch pictures")
struct WatchSnapshotTests {
    static let sizes: [(name: String, size: DynamicTypeSize)] = [
        ("xs", .xSmall), ("l", .large), ("ax3", .accessibility3),
    ]
    /// The Apple Watch Ultra 2's screen, in points.
    static let width: CGFloat = 205

    private static func check(_ view: some View, named name: String, background: Color = LabourTheme.space) {
        for (sizeName, size) in sizes {
            Snapshot.check(
                Snapshot.image(view, width: width, size: size, mode: .live, background: background, inset: 6),
                named: "watch-\(name)-\(sizeName)")
        }
    }

    private static let pillText: [LabourState: String] = [
        .early: "No pattern", .establishing: "Keep timing", .callTriage: "Time to call", .callNow: "Call now",
        .call999: "Call 999",
    ]

    @Test("The advice pill at every level", arguments: LabourState.allCases)
    func pill(state: LabourState) {
        Self.check(WatchStatePill(text: Self.pillText[state] ?? "", state: state), named: "pill-\(state.rawValue)")
    }

    /// One moment on the main screen: the level, and how long a contraction has been running.
    struct Moment: Sendable {
        var name: String
        var state: LabourState
        var running: TimeInterval?
    }

    @Test("The main screen: no pattern, time to call, call now while one runs, and 999")
    func screen() {
        let moments = [
            Moment(name: "early", state: .early), Moment(name: "call", state: .callTriage),
            Moment(name: "callnow-running", state: .callNow, running: 47), Moment(name: "999", state: .call999),
        ]
        for moment in moments {
            let view = VStack(spacing: 8) {
                WatchStatePill(text: Self.pillText[moment.state] ?? "", state: moment.state)
                if moment.state >= .callTriage {
                    WatchCallFace(
                        title: moment.state == .call999 ? "Call 999" : "Call Northgate General",
                        warm: moment.state == .callTriage, compact: true)
                }
                WatchBurnButton(isRunning: moment.running != nil, elapsed: moment.running ?? 0) {}
                WatchStatsLine(every: moment.state == .early ? "–" : "4 min apart", lastHour: 14)
            }
            Self.check(view, named: "screen-\(moment.name)")
        }
    }

    @Test("A question, a call row and LAUNCH")
    func pieces() {
        Self.check(
            WatchAskCard(question: "Going 3:10. Did it just end?", answers: [("Just ended", {}), ("New one", {})]),
            named: "ask")
        Self.check(
            WatchCallRow(title: "Call the labour ward", number: "01632 960245"), named: "call-row",
            background: LabourPalette.callTop.color)
        Self.check(WatchLaunchKey(progress: 0), named: "launch")
        Self.check(WatchLaunchKey(progress: 0.6), named: "launch-holding")
    }
}
