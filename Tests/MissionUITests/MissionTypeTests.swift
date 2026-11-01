import CoreText
import Foundation
import Testing

@testable import MissionUI

/// The prototype's fonts ship with their licences and load (redesign rule 5), and the big
/// button's breathing ring keeps its rhythm.
@Suite("Labour type and button")
struct MissionTypeTests {
    @Test("All three fonts are bundled with their licences, and load by name")
    func fontsLoad() {
        #expect(MissionType.registerFonts())
        for family in [MissionType.displayFamily, MissionType.monoFamily, MissionType.bodyFamily] {
            let font = CTFontCreateWithName(family as CFString, 12, nil)
            #expect(CTFontCopyFamilyName(font) as String == family)
        }
        for licence in ["LeagueGothic-OFL", "InstrumentSans-OFL", "MartianMono-OFL"] {
            let url = MissionType.bundle.url(forResource: licence, withExtension: "txt", subdirectory: "Fonts")
            let text = url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
            #expect(text.contains("SIL OPEN FONT LICENSE"), "\(licence)")
        }
    }

    @Test("Nothing is set under 11 points, and the display face never under 22")
    func minimumSizes() {
        #expect(MissionType.minimumSize == 11)
        // The helpers clamp: asking for the prototype's 8.5-point labels gives 11.
        #expect(MissionType.mono(8.5) == MissionType.mono(11))
        #expect(MissionType.body(9) == MissionType.body(11))
        #expect(MissionType.display(12) == MissionType.display(22))
    }

    @Test("The ring breathes in over 4 seconds and out over 6, with the words in step")
    func breathing() {
        #expect(abs(BurnButton.ringScale(elapsed: 0) - 0.76) < 0.001)
        #expect(abs(BurnButton.ringScale(elapsed: 4) - 1) < 0.001)
        #expect(abs(BurnButton.ringScale(elapsed: 7) - 0.88) < 0.001)
        #expect(abs(BurnButton.ringScale(elapsed: 10) - 0.76) < 0.001)
        #expect(BurnButton.cue(isRunning: true, elapsed: 3) == "Breathe in with her")
        #expect(BurnButton.cue(isRunning: true, elapsed: 4) == "Long breath out")
        #expect(BurnButton.cue(isRunning: false, elapsed: nil) == "when one begins")
    }

    @Test("Past the urgent length it asks if it's still going, in short on a small button")
    func longContraction() {
        #expect(BurnButton.top(isRunning: true, elapsed: 30, urgentAfter: 120) == "Contraction · tap to stop")
        #expect(BurnButton.top(isRunning: true, elapsed: 130, urgentAfter: 120).hasSuffix("still going?"))
        #expect(BurnButton.shortTop(isRunning: true, elapsed: 30, urgentAfter: 120) == "Tap to stop")
        #expect(BurnButton.shortTop(isRunning: true, elapsed: 130, urgentAfter: 120) == "Still going?")
        #expect(BurnButton.top(isRunning: false, elapsed: nil, urgentAfter: 120) == "Contraction")
    }
}
