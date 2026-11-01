import Foundation
import Testing

@testable import MissionCore

@Suite("When things go differently")
struct PregnancyOutcomeTests {
    @Test("Every support line has a number that dials, and every source is in the research")
    func supportIsSourced() throws {
        let research = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "docs/research")
        let reports = try FileManager.default.contentsOfDirectory(at: research, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
        for item in SupportDirectory.all {
            #expect(reports.contains(item.source.url.absoluteString), "\(item.id): source not in docs/research")
            if let link = item.link {
                #expect(reports.contains(link.absoluteString), "\(item.id): link not in docs/research")
            }
        }
        let withNumbers = ["sands", "miscarriage-uk", "tommys", "samaritans"]
        for id in withNumbers {
            let item = try #require(SupportDirectory.all.first { $0.id == id })
            #expect(item.number?.telURL != nil, "\(id) has no number that dials")
        }
        #expect(SupportDirectory.all.first { $0.id == "sands" }?.number?.dialable == "+448081643332")
        #expect(SupportDirectory.all.first { $0.id == "samaritans" }?.number?.dialable == "116123")
    }

    @Test("After a loss, the right line comes first, and leave and registration only from 24 weeks")
    func lossOrder() {
        let early = SupportDirectory.items(for: .loss, region: .uk, gestationalAgeDays: 70).map(\.id)
        #expect(early == ["miscarriage-uk", "sands", "tommys", "samaritans"])
        let later = SupportDirectory.items(for: .loss, region: .uk, gestationalAgeDays: 168).map(\.id)
        let laterExpected = [
            "sands", "miscarriage-uk", "tommys", "samaritans", "register-stillbirth", "leave-after-loss",
        ]
        #expect(later == laterExpected)
        let unknown = SupportDirectory.items(for: .loss, region: .uk, gestationalAgeDays: nil).map(\.id)
        #expect(unknown.first == "sands")
        let caring = SupportDirectory.items(for: .babyNeedsCare, region: .uk, gestationalAgeDays: 200).map(\.id)
        #expect(caring == ["bliss", "neonatal-leave", "samaritans"])
        #expect(SupportDirectory.items(for: .allWell, region: .uk, gestationalAgeDays: 280).isEmpty)
        #expect(SupportDirectory.items(for: .loss, region: .us, gestationalAgeDays: 280).map(\.id) == ["ask-the-team"])
    }

    @Test("Only 'all well' keeps the humour, claims anyone is well, or opens with a celebration")
    func quietUnlessAllWell() {
        for outcome in PregnancyOutcome.allCases {
            let opener = outcome.messageOpener(babyName: "", bornAt: "09:12")
            #expect(outcome.keepsHumour == (outcome == .allWell))
            #expect(opener.contains("!") == (outcome == .allWell))
            #expect(outcome.defaultWellbeing.isEmpty == (outcome != .allWell))
        }
        let named = PregnancyOutcome.babyNeedsCare.messageOpener(babyName: " Ada ", bornAt: "09:12")
        #expect(named == "Ada was born at 09:12.")
        #expect(!PregnancyOutcome.loss.hasBirthMessage)
    }

    @Test("Support copy is plain: no humour, no space theme, nothing diagnostic")
    func plainCopy() {
        let banned = ["payload", "mission", "launch", "splashdown", "capcom", "!"] + StateCopyTests.forbidden
        var lines = PregnancyOutcome.allCases.map(\.choice)
        for outcome in PregnancyOutcome.allCases where outcome != .allWell {
            let heading = SupportDirectory.heading(for: outcome)
            lines += [heading.title, heading.detail]
        }
        lines += SupportDirectory.all.flatMap { [$0.title, $0.detail] }
        for line in lines {
            for word in banned {
                #expect(!line.lowercased().contains(word), "\"\(line)\" contains \"\(word)\"")
            }
        }
    }
}
