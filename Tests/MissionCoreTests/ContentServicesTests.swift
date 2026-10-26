import Foundation
import Testing

@testable import MissionCore

private func provenance() -> Provenance {
    Provenance(
        sourceURL: URL(fileURLWithPath: "/"),
        sourceTitle: "Test",
        accessed: "2026-10-26",
        clinical: true
    )
}

private func entry(_ id: String, _ term: String, aliases: [String] = [], _ plain: String, stages: [LabourStage] = [])
    -> GlossaryEntry
{
    GlossaryEntry(
        id: id,
        term: term,
        aliases: aliases,
        plainEnglish: plain,
        worryLevel: 0,
        questionToAsk: "?",
        stages: stages,
        provenance: provenance()
    )
}

@Suite("Glossary search")
struct GlossaryIndexTests {
    let index = GlossaryIndex(entries: [
        entry(
            "ctg", "CTG", aliases: ["the trace", "monitoring"], "Belts that record the baby's heart rate.",
            stages: [.established]),
        entry(
            "dilated", "Dilated", aliases: ["she's 6", "cm"], "How open the cervix is, 0 to 10 cm.",
            stages: [.established]),
        entry("fully", "Fully dilated", aliases: ["fully", "FD"], "10 cm: pushing can begin.", stages: [.pushing]),
        entry("syntocinon", "Syntocinon", aliases: ["the drip", "oxytocin"], "A drip to make contractions stronger."),
        entry(
            "srom", "SROM", aliases: ["waters broke"],
            "Spontaneous rupture of membranes: her waters broke on their own."),
        entry("engaged", "Engaged", aliases: ["3/5 palpable"], "How far the head has dropped into the pelvis."),
        entry(
            "decels", "Decelerations", aliases: ["decels", "dips"], "Dips in the baby's heart rate on the trace.",
            stages: [.pushing]),
        entry("cafe", "Café test", "Made-up entry with an accent."),
    ])

    @Test("Exact abbreviations come first")
    func exact() {
        #expect(index.search("CTG").first?.id == "ctg")
        #expect(index.search("srom").first?.id == "srom")
    }

    @Test("What midwives actually say finds the term")
    func midwifeSpeak() {
        #expect(index.search("the drip").first?.id == "syntocinon")
        #expect(index.search("she's 6").first?.id == "dilated")
        #expect(index.search("shes 6").first?.id == "dilated")
        #expect(index.search("She\u{2019}s 6").first?.id == "dilated")
        #expect(index.search("3/5 palpable").first?.id == "engaged")
        #expect(index.search("fully").first?.id == "fully")
    }

    @Test("Prefixes match as you type")
    func prefixes() {
        #expect(index.search("decel").first?.id == "decels")
        #expect(index.search("synto").first?.id == "syntocinon")
    }

    @Test("Names outrank explanations")
    func namesFirst() {
        let results = index.search("trace").map(\.id)
        #expect(results.first == "ctg")
        #expect(results.contains("decels"))
    }

    @Test("Accents and case don't matter")
    func folding() {
        #expect(index.search("CAFE").first?.id == "cafe")
        #expect(GlossaryIndex.normalise("  Café — 3/5  Palpable! ") == "cafe 3 5 palpable")
    }

    @Test("No match gives no results")
    func noMatch() {
        #expect(index.search("zzzz").isEmpty)
    }

    @Test("An empty query lists everything, current stage first")
    func emptyQuery() {
        let all = index.search("", stage: .pushing)
        #expect(all.count == 8)
        #expect(all.prefix(2).map(\.id) == ["decels", "fully"])
    }

    @Test("The current stage breaks ties but never beats an exact match")
    func stageBoost() {
        // Both mention "heart rate" in their explanation, so they tie without a stage.
        #expect(index.search("heart").map(\.id) == ["ctg", "decels"])
        #expect(index.search("heart", stage: .pushing).map(\.id) == ["decels", "ctg"])
        #expect(index.search("dilated", stage: .pushing).first?.id == "dilated")
    }
}

@Suite("Humour")
struct HumourResolverTests {
    let copy = LocalizedCopy(
        off: "Fit the car seat.", mild: "Fit the car seat. Properly.", full: "Pit Crew: fit the car seat.")

    @Test("Uses the preferred level outside labour")
    func preferred() {
        #expect(HumourResolver(preferred: .full).text(copy) == "Pit Crew: fit the car seat.")
        #expect(HumourResolver(preferred: .mild).text(copy) == "Fit the car seat. Properly.")
    }

    @Test("Labour mode forces the plain version")
    func labourMode() {
        let resolver = HumourResolver(preferred: .full, isLabourMode: true)
        #expect(resolver.effectiveLevel == .off)
        #expect(resolver.text(copy) == "Fit the car seat.")
    }

    @Test("The Flight Surgeon never jokes")
    func flightSurgeon() {
        #expect(HumourResolver(preferred: .full).text(copy, speaker: .flightSurgeon) == "Fit the car seat.")
        #expect(HumourResolver(preferred: .full).text(copy, speaker: .capcom) == "Pit Crew: fit the car seat.")
    }
}

@Suite("Content loader")
struct ContentLoaderTests {
    private func envelope(_ kind: ContentKind, _ items: String) -> Data {
        Data(#"{"schemaVersion": 1, "contentVersion": "t-\#(kind.rawValue)", "region": "uk", "items": \#(items)}"#.utf8)
    }

    @Test("Missing kinds load empty and thresholds fall back to the built-in table")
    func missingKinds() throws {
        let library = try ContentLoader.load(region: .uk) { _ in nil }
        #expect(library.checklist.isEmpty)
        #expect(library.thresholds == ThresholdTable.builtIn(for: .uk))
        #expect(library.versions.isEmpty)
        #expect(ContentLoader.problems(in: library).isEmpty)
    }

    @Test("Broken references are reported")
    func brokenReferences() throws {
        let checklist = #"""
            [{"id": "a", "module": "vehicle", "title": {"off": "t"}, "why": {"off": "w"}, "unlockWeek": 30,
              "reminderDaysBefore": [], "quizID": "car-seat", "xp": 5},
             {"id": "a", "module": "vehicle", "title": {"off": "t"}, "why": {"off": "w"}, "unlockWeek": 30,
              "reminderDaysBefore": [], "xp": 5}]
            """#
        let quiz = #"""
            [{"id": "q1", "quizID": "safe-sleep", "prompt": "p", "choices": ["a", "b"], "correctIndex": 2,
              "explanation": "e"}]
            """#
        let badges = #"""
            [{"id": "b1", "name": "Pit Crew", "description": {"off": "d"},
              "rule": {"kind": "checklistItemsDone", "targetIDs": ["a", "nope"]}},
             {"id": "b2", "name": "Module", "description": {"off": "d"},
              "rule": {"kind": "moduleComplete", "targetIDs": ["vehicle"]}}]
            """#
        let library = try ContentLoader.load(region: .uk) { kind in
            switch kind {
            case .checklist: envelope(kind, checklist)
            case .quiz: envelope(kind, quiz)
            case .badges: envelope(kind, badges)
            default: nil
            }
        }
        #expect(library.versions[.checklist] == "t-checklist")
        let problems = Set(ContentLoader.problems(in: library))
        #expect(
            problems == [
                .duplicateID(kind: .checklist, id: "a"),
                .missingQuiz(checklistID: "a", quizID: "car-seat"),
                .quizTooShort(quizID: "safe-sleep", count: 1),
                .badAnswerIndex(questionID: "q1"),
                .missingBadgeTarget(badgeID: "b1", target: "nope"),
            ]
        )
    }

    @Test("A file in the wrong region is rejected")
    func wrongRegion() {
        #expect(throws: ContentDecodingError.self) {
            _ = try ContentLoader.load(region: .us) { kind in
                kind == .badges
                    ? Data(#"{"schemaVersion": 1, "contentVersion": "x", "region": "uk", "items": []}"#.utf8) : nil
            }
        }
    }
}
