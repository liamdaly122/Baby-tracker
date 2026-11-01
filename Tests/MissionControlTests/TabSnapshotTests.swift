import MissionContent
import MissionCore
import MissionUI
import SwiftUI
import Testing

@testable import MissionControl

/// Picture tests for the redesigned Plan, Coach and Decoder tabs (redesign rule 9), live and in
/// practice, at the smallest, normal and largest labour text sizes, each on its tab's background.
@MainActor
@Suite("Plan, Coach and Decoder pictures")
struct TabSnapshotTests {
    private static func check(_ view: some View, named name: String, background: PaletteColor) {
        for mode in MissionModeOption.allCases {
            for (sizeName, size) in SnapshotTests.sizes {
                Snapshot.check(
                    Snapshot.image(view, size: size, mode: mode, background: background.color),
                    named: "\(name)-\(mode.rawValue)-\(sizeName)")
            }
        }
    }

    /// A plan with a top three, two answers (one his draft, one for the day) and a change of plan.
    static let plan: BirthPlanContent = {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        return BirthPlanContent(
            topFive: [
                "Gas and air first, epidural if she asks", "Skin-to-skin straight away", "Wait to clamp the cord",
            ],
            answers: [
                PlanAnswer(
                    sectionID: BirthPlanSection.place.id, text: "Midwife-led unit", decidedBy: .her, changedAt: date),
                PlanAnswer(
                    sectionID: BirthPlanSection.painRelief.id, text: "Breathing, TENS, then gas and air",
                    decidedBy: .onTheDay, changedAt: date),
            ],
            branches: [
                PlanBranch(
                    scenario: .caesarean, wishes: "You stay with her. Skin-to-skin in theatre if it's safe.",
                    hisJob: "Ask for the screen and for skin-to-skin", changedAt: date)
            ])
    }()

    @Test("The plan sheet: checked, not checked, and empty")
    func planSheet() {
        let checked = Date(timeIntervalSince1970: 1_800_000_000)
        Self.check(
            PlanSheet(content: Self.plan, motherName: "Sam", stamp: PlanStamp(confirmedAt: checked)),
            named: "plan-checked", background: LabourPalette.planTop)
        Self.check(
            VStack(spacing: 12) {
                CheckedWithHerLine(confirmedAt: nil, changes: [])
                PlanSheet(
                    content: Self.plan, motherName: "Sam", unchecked: [BirthPlanSection.place.id],
                    stamp: PlanStamp(confirmedAt: nil))
            },
            named: "plan-unchecked", background: LabourPalette.planTop)
        Self.check(
            PlanSheet(content: BirthPlanContent(), motherName: ""), named: "plan-empty",
            background: LabourPalette.planTop)
    }

    @Test("The coach: the stage line and a card with things to avoid")
    func coach() throws {
        let library = try BundledContent.library(for: .uk)
        let card = try #require(library.coachingCards(for: .latent).first { !$0.avoidThis.isEmpty })
        let stages: [LabourStage] = [.latent, .established, .transition, .pushing, .theatre, .goldenHour]
        Self.check(
            StageTrack(stages: stages, current: .transition) { _ in }, named: "coach-track",
            background: LabourPalette.coachTop)
        Self.check(CoachingCardView(card: card), named: "coach-card", background: LabourPalette.coachTop)
    }

    @Test("The decoder: a term at each of the four worry levels")
    func decoder() throws {
        let library = try BundledContent.library(for: .uk)
        for level in 0...3 {
            let entry = try #require(library.glossary.first { $0.worryLevel == level }, "No term at level \(level)")
            Self.check(
                GlossaryRow(entry: entry, isExpanded: level == 0) {}, named: "decoder-level\(level)",
                background: LabourPalette.decoderBlue)
        }
    }
}
