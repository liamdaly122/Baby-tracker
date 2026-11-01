import MissionCore
import MissionUI
import SwiftUI
import Testing

/// Picture tests for the labour components the redesign will restyle first: the advice panel for
/// every level and the big START/STOP button, live and in practice, at three text sizes.
@MainActor
@Suite("Labour pictures")
struct SnapshotTests {
    static let sizes: [(name: String, size: DynamicTypeSize)] = [
        ("xs", .xSmall), ("l", .large), ("ax3", .accessibility3),
    ]

    private static func banner(_ state: LabourState) -> StateBanner {
        let output = sampleOutput(state)
        return StateBanner(
            state: state,
            headline: StateCopy.headline(for: state, region: .uk),
            detail: StateCopy.detail(for: output, region: .uk, thresholds: output.thresholds),
            reasonLines: ["Regular, every 4 min, lasting about 50 sec, for 60 min."],
            source: "NHS: Signs that labour has begun",
            isExpanded: state >= .callNow
        )
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
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let count = state >= .callTriage ? 15 : (state == .establishing ? 6 : 2)
        let every: TimeInterval = state == .establishing ? 420 : 240
        let contractions = (0..<count).map { index in
            let begin = start.addingTimeInterval(Double(index) * every)
            return Contraction(start: begin, end: begin.addingTimeInterval(50))
        }
        let now = start.addingTimeInterval(Double(count) * every)
        return GoNoGoEngine.evaluate(
            EngineInput(
                contractions: contractions, redFlags: flags,
                profile: LabourProfile(region: .uk, gestationalAgeDays: 273), thresholds: thresholds,
                previous: nil, easedAt: nil, now: now))
    }

    @Test("The advice panel at every level", arguments: LabourState.allCases)
    func banners(state: LabourState) {
        for mode in MissionModeOption.allCases {
            for (name, size) in Self.sizes {
                Snapshot.check(
                    Snapshot.image(Self.banner(state), size: size, mode: mode),
                    named: "banner-\(state.rawValue)-\(mode.rawValue)-\(name)")
            }
        }
    }

    @Test("START and STOP")
    func startStop() {
        for running in [false, true] {
            for (name, size) in Self.sizes {
                let button = StartStopButton(isRunning: running, elapsed: running ? 47 : nil) {}
                    .frame(height: 220)
                Snapshot.check(
                    Snapshot.image(button, size: size, mode: .live),
                    named: "startstop-\(running ? "running" : "idle")-\(name)")
            }
        }
    }
}
