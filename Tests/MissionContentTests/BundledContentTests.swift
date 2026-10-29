import Foundation
import MissionContent
import MissionCore
import Testing

@Suite("Bundled content")
struct BundledContentTests {
    @Test("Every region ships thresholds", arguments: ContentRegion.allCases)
    func thresholdsPresent(region: ContentRegion) {
        #expect(BundledContent.availableKinds(for: region).contains(.thresholds))
    }

    @Test("Every bundled file decodes with the right envelope", arguments: ContentRegion.allCases)
    func everyFileDecodes(region: ContentRegion) throws {
        for kind in BundledContent.availableKinds(for: region) {
            let data = try BundledContent.data(for: kind, region: region)
            switch kind {
            case .briefings: _ = try ContentDecoding.envelope(Briefing.self, from: data, expectedRegion: region)
            case .checklist: _ = try ContentDecoding.envelope(ChecklistItem.self, from: data, expectedRegion: region)
            case .glossary: _ = try ContentDecoding.envelope(GlossaryEntry.self, from: data, expectedRegion: region)
            case .coaching: _ = try ContentDecoding.envelope(CoachingCard.self, from: data, expectedRegion: region)
            case .quiz: _ = try ContentDecoding.envelope(QuizQuestion.self, from: data, expectedRegion: region)
            case .thresholds: _ = try ContentDecoding.envelope(ThresholdItem.self, from: data, expectedRegion: region)
            case .badges: _ = try ContentDecoding.envelope(BadgeDefinition.self, from: data, expectedRegion: region)
            }
        }
    }

    @Test("thresholds.json matches the compiled-in fallback", arguments: ContentRegion.allCases)
    func thresholdsMatchBuiltIn(region: ContentRegion) throws {
        let table = try BundledContent.thresholdTable(for: region)
        #expect(table == ThresholdTable.builtIn(for: region))
    }

    @Test("UK defaults follow NHS wording")
    func ukDefaults() throws {
        let defaults = try BundledContent.thresholdTable(for: .uk).defaults
        #expect(defaults.adviceIntervalSec == 300)
        #expect(defaults.adviceDurationSec == 0)
        #expect(defaults.patternWindowSec == 0)
        #expect(defaults.urgentSingleDurationSec == 120)
        #expect(defaults.urgentCountIn10Min == 6)
    }

    @Test("US defaults follow 5-1-1")
    func usDefaults() throws {
        let defaults = try BundledContent.thresholdTable(for: .us).defaults
        #expect(defaults.adviceIntervalSec == 300)
        #expect(defaults.adviceDurationSec == 60)
        #expect(defaults.patternWindowSec == 3600)
    }
}
