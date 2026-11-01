import MissionCore
import MissionUI
import SwiftUI
import Testing

/// Picture tests for the redesigned timer (docs/redesign-rules.md, rule 9): each piece of the
/// agreed prototype's layout, live and in practice, at the smallest, normal and largest labour
/// text sizes.
@MainActor
@Suite("Labour pictures")
struct SnapshotTests {
    static let sizes: [(name: String, size: DynamicTypeSize)] = [
        ("xs", .xSmall), ("l", .large), ("ax3", .accessibility3),
    ]

    /// The advice block at a level, with the call button it carries from "time to call" up.
    private static func advice(_ state: LabourState, mode: MissionModeOption) -> some View {
        let output = sampleOutput(state)
        let style: DialFace.Style = mode == .practice ? .practice : (state >= .callNow ? .hot : .warm)
        return AdviceBlock(
            state: state,
            headline: StateCopy.headline(for: state, region: .uk),
            reasonLines: ["Regular, every 4 min, lasting about 50 sec, for 60 min."],
            detail: StateCopy.detail(for: output, region: .uk, thresholds: output.thresholds),
            source: "NHS: Signs that labour has begun"
        ) {
            if state == .call999 {
                DialFace(title: "Call 999", detail: "Then your maternity unit. Stay with her.", style: style)
            } else if state >= .callTriage {
                DialFace(title: "Call Northgate General", detail: "01632 960118 · then press 2", style: style)
            }
        }
    }

    /// An engine output at a state, for the detail line.
    private static func sampleOutput(_ state: LabourState) -> EngineOutput {
        let thresholds = ThresholdTable.builtIn(for: .uk).defaults
        let flags: Set<RedFlag> =
            switch state {
            case .call999: [.urgeToPush]
            case .callNow: [.watersBroken]
            default: []
            }
        let (contractions, now) = sampleContractions(
            count: state >= .callTriage ? 15 : (state == .establishing ? 6 : 2))
        return GoNoGoEngine.evaluate(
            EngineInput(
                contractions: contractions, redFlags: flags,
                profile: LabourProfile(region: .uk, gestationalAgeDays: 273), thresholds: thresholds,
                previous: nil, easedAt: nil, now: now))
    }

    /// Contractions every 4 minutes, lasting 50 seconds, and the moment after the last.
    private static func sampleContractions(count: Int) -> ([Contraction], Date) {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let contractions = (0..<count).map { index in
            let begin = start.addingTimeInterval(Double(index) * 240)
            return Contraction(start: begin, end: begin.addingTimeInterval(50))
        }
        return (contractions, start.addingTimeInterval(Double(count) * 240))
    }

    @Test("The advice at every level", arguments: LabourState.allCases)
    func adviceBlocks(state: LabourState) {
        for mode in MissionModeOption.allCases {
            for (name, size) in Self.sizes {
                Snapshot.check(
                    Snapshot.image(Self.advice(state, mode: mode), size: size, mode: mode),
                    named: "advice-\(state.rawValue)-\(mode.rawValue)-\(name)")
            }
        }
    }

    @Test("The level strip at every level", arguments: LabourState.allCases)
    func levels(state: LabourState) {
        for mode in MissionModeOption.allCases {
            for (name, size) in Self.sizes {
                Snapshot.check(
                    Snapshot.image(LevelStrip(state: state), size: size, mode: mode),
                    named: "levels-\(state.rawValue)-\(mode.rawValue)-\(name)")
            }
        }
    }

    /// A moment for the big button: how long it's been running, and how big it is.
    struct BurnCase: Sendable {
        var name: String
        var elapsed: TimeInterval?
        var side: CGFloat
    }

    @Test("The big button: waiting, running, over 2 minutes, and small")
    func burnButton() {
        let cases = [
            BurnCase(name: "idle", side: 212), BurnCase(name: "running", elapsed: 47, side: 212),
            BurnCase(name: "long", elapsed: 135, side: 212), BurnCase(name: "small", elapsed: 47, side: 132),
        ]
        for mode in MissionModeOption.allCases {
            for burn in cases {
                for (name, size) in Self.sizes {
                    let button = BurnButton(isRunning: burn.elapsed != nil, elapsed: burn.elapsed, urgentAfter: 120) {}
                        .frame(width: burn.side, height: burn.side)
                    Snapshot.check(
                        Snapshot.image(button, size: size, mode: mode),
                        named: "burn-\(burn.name)-\(mode.rawValue)-\(name)")
                }
            }
        }
    }

    @Test("The trace, the numbers and the undo bar")
    func timerParts() {
        let (contractions, now) = Self.sampleContractions(count: 14)
        let running = contractions + [Contraction(start: now.addingTimeInterval(-20), end: nil)]
        for mode in MissionModeOption.allCases {
            for (name, size) in Self.sizes {
                let trace = ContractionTrace(contractions: running, missedTaps: [], now: now).frame(height: 80)
                Snapshot.check(Snapshot.image(trace, size: size, mode: mode), named: "trace-\(mode.rawValue)-\(name)")
                let stats = StatsStrip([("4:00", "Every"), ("50s", "Lasting"), ("15", "Last hour")])
                Snapshot.check(Snapshot.image(stats, size: size, mode: mode), named: "stats-\(mode.rawValue)-\(name)")
                let undo = UndoBar(text: "Contraction started") {}
                Snapshot.check(Snapshot.image(undo, size: size, mode: mode), named: "undo-\(mode.rawValue)-\(name)")
            }
        }
    }

    @Test("The orbit scene behind labour mode")
    func orbit() {
        for mode in MissionModeOption.allCases {
            let scene = OrbitScene(isPractice: mode == .practice).frame(width: 390, height: 844)
            let renderer = ImageRenderer(content: scene)
            renderer.scale = 1
            Snapshot.check(renderer.uiImage, named: "orbit-\(mode.rawValue)")
        }
    }
}
