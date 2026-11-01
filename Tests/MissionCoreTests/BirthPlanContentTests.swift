import Foundation
import Testing

@testable import MissionCore

@Suite("Birth plan")
struct BirthPlanContentTests {
    @Test("An answer's date moves only when its words or who decided change")
    func changedAtOnlyOnRealChanges() {
        var plan = BirthPlanContent()
        plan.setAnswer("painRelief", text: "Gas and air first", decidedBy: .hisDraft, at: at(0))
        plan.setAnswer("painRelief", text: "Gas and air first", decidedBy: .hisDraft, at: at(100))
        #expect(plan.answer(for: "painRelief")?.changedAt == at(0))
        plan.setAnswer("painRelief", text: "Gas and air first", decidedBy: .her, at: at(200))
        #expect(plan.answer(for: "painRelief")?.changedAt == at(200))
        plan.setBranch(.caesarean, wishes: "Screen lowered", hisJob: "Ask for skin-to-skin", at: at(300))
        plan.setBranch(.caesarean, wishes: "Screen lowered", hisJob: "Ask for skin-to-skin", at: at(400))
        #expect(plan.branch(for: .caesarean)?.changedAt == at(300))
        #expect(plan.answers.count == 1 && plan.branches.count == 1)
    }

    @Test("What changed: the top five, each section and each branch, ignoring blanks and spacing")
    func changes() {
        var before = BirthPlanContent(topFive: ["Skin-to-skin straight away", ""])
        before.setAnswer("painRelief", text: "Gas and air first", decidedBy: .her, at: at(0))
        before.setAnswer("feeding", text: "Breastfeeding", decidedBy: .together, at: at(0))
        before.setAnswer("photos", text: "  ", decidedBy: .hisDraft, at: at(0))
        var after = before
        #expect(after.changes(since: before).isEmpty)
        after.topFive = ["Skin-to-skin straight away  ", "", ""]
        after.setAnswer("feeding", text: "Breastfeeding ", decidedBy: .together, at: at(10))
        #expect(after.changes(since: before).isEmpty)

        after.topFive = ["Skin-to-skin straight away", "Dad cuts the cord"]
        after.setAnswer("painRelief", text: "Gas and air, then an epidural if she asks", decidedBy: .her, at: at(20))
        after.setAnswer("feeding", text: "", decidedBy: .together, at: at(20))
        after.setAnswer("photos", text: "No photos of her", decidedBy: .hisDraft, at: at(20))
        after.setBranch(.induction, wishes: "Ask about a balloon first", hisJob: "", at: at(20))
        let changes = after.changes(since: before)
        #expect(
            changes == [
                PlanChange(part: .topFive, kind: .changed),
                PlanChange(part: .section("painRelief"), kind: .changed),
                PlanChange(part: .section("feeding"), kind: .removed),
                PlanChange(part: .section("photos"), kind: .added),
                PlanChange(part: .branch(.induction), kind: .added),
            ])
        // Her deciding what was his draft is a change too.
        var decided = after
        decided.setAnswer("photos", text: "No photos of her", decidedBy: .her, at: at(30))
        #expect(decided.changes(since: after) == [PlanChange(part: .section("photos"), kind: .changed)])
    }

    @Test("His drafts are unchecked until she has seen them, and again once he changes them")
    func unchecked() {
        var plan = BirthPlanContent()
        plan.setAnswer("cord", text: "Dad cuts it", decidedBy: .hisDraft, at: at(100))
        plan.setAnswer("feeding", text: "Breastfeeding", decidedBy: .her, at: at(100))
        #expect(plan.uncheckedAnswers(herConfirmedAt: nil).map(\.sectionID) == ["cord"])
        #expect(plan.uncheckedAnswers(herConfirmedAt: at(200)).isEmpty)
        plan.setAnswer("cord", text: "Dad cuts it, after a minute", decidedBy: .hisDraft, at: at(300))
        #expect(plan.uncheckedAnswers(herConfirmedAt: at(200)).map(\.sectionID) == ["cord"])
    }

    @Test("A plan saved before branches existed still opens")
    func decodesOlderPlans() throws {
        let data = Data(#"{"topFive":["Gas and air first"]}"#.utf8)
        let plan = try JSONDecoder().decode(BirthPlanContent.self, from: data)
        #expect(plan.filledTopFive == ["Gas and air first"])
        #expect(plan.answers.isEmpty && plan.branches.isEmpty)
        #expect(!plan.isEmpty)
        #expect(BirthPlanContent().isEmpty)
    }
}
