import MissionCore
import Testing

@testable import MissionUI

/// Redesign rule 5: every colour pair that carries text passes WCAG 2.2 contrast (1.4.3).
@Suite("Labour palette")
struct LabourPaletteTests {
    @Test("The contrast formula matches WCAG's known values")
    func formula() {
        #expect(abs(LabourPalette.black.contrast(with: LabourPalette.white) - 21) < 0.01)
        #expect(LabourPalette.white.contrast(with: LabourPalette.white) == 1)
        // Mid-grey #777777 on white is the textbook 4.48:1.
        let grey = PaletteColor(white: 0x77 / 255.0)
        #expect(abs(grey.contrast(with: LabourPalette.white) - 4.48) < 0.01)
    }

    @Test("Every text pair passes", arguments: LabourPalette.textPairs.map(\.name))
    func pairPasses(name: String) throws {
        let pair = try #require(LabourPalette.textPairs.first { $0.name == name })
        let ratio = pair.text.contrast(with: pair.background)
        #expect(ratio >= pair.minimum, "\(name): \(ratio) is under \(pair.minimum)")
    }

    @Test("Each state's filled panel carries its text colour at 4.5:1 or better", arguments: LabourState.allCases)
    func fills(state: LabourState) {
        let ratio = LabourTheme.textOnFillPalette(for: state).contrast(with: LabourTheme.fillPalette(for: state))
        #expect(ratio >= 4.5, "\(state): \(ratio)")
    }

    @Test("White on the bright orange would fail, which is why panels use the deeper fill")
    func brightOrangeIsForStrokes() {
        #expect(LabourPalette.white.contrast(with: LabourPalette.urgent) < 4.5)
        #expect(LabourPalette.urgent.contrast(with: LabourPalette.black) >= 4.5)
    }

    @Test("The timer shows a control for every red flag, each once, with the two pinned first")
    func everyFlagHasAControl() {
        let shown = RedFlagLayout.pinned + RedFlagLayout.others
        #expect(Set(shown) == Set(RedFlag.allCases))
        #expect(shown.count == RedFlag.allCases.count)
        #expect(RedFlagLayout.pinned == [.reducedMovements, .watersBroken])
    }
}

/// Redesign rule 2: 999 (911 in the US) is a real dial link.
@Suite("Emergency number")
struct EmergencyNumberTests {
    @Test("The emergency number dials", arguments: ContentRegion.allCases)
    func dials(region: ContentRegion) throws {
        let number = StateCopy.emergencyNumber(region)
        #expect(number == (region == .uk ? "999" : "911"))
        let url = try #require(PhoneNumber.shortCode(number)?.telURL)
        #expect(url.absoluteString == "tel:\(number)")
    }
}
