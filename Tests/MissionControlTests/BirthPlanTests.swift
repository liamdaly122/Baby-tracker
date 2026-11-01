import Foundation
import MissionCore
import SwiftData
import Testing

@testable import MissionControl

/// The birth plan (review action 17): drafts, checking it with her, history, and moving old plans.
@MainActor
@Suite("Birth plan in the app")
struct BirthPlanTests {
    private func revisions(_ model: AppModel) throws -> [BirthPlanRevision] {
        try model.planning.mainContext.fetch(
            FetchDescriptor<BirthPlanRevision>(sortBy: [SortDescriptor(\.savedAt)]))
    }

    @Test("Opening and closing the plan saves nothing; a real change is saved with a dated copy")
    func savesOnlyRealChanges() throws {
        let model = AppModel(inMemory: true)
        let plan = model.birthPlan
        #expect(!plan.save(plan.content, in: model.planning.mainContext))
        #expect(plan.changedAt == nil)
        #expect(try revisions(model).isEmpty)

        var draft = plan.content
        draft.setAnswer("painRelief", text: "Gas and air first", decidedBy: .hisDraft, at: Date())
        #expect(plan.save(draft, in: model.planning.mainContext, at: Date(timeIntervalSince1970: 100)))
        #expect(plan.changedAt == Date(timeIntervalSince1970: 100))
        #expect(try revisions(model).map(\.reason) == [.saved])
        #expect(plan.content.answer(for: "painRelief")?.text == "Gas and air first")
    }

    @Test("Once she has read it, the app knows what changed since and which drafts are unchecked")
    func checkedWithHer() throws {
        let model = AppModel(inMemory: true)
        let plan = model.birthPlan
        let context = model.planning.mainContext
        var draft = BirthPlanContent(topFive: ["Skin-to-skin straight away"])
        draft.setAnswer("cord", text: "Dad cuts it", decidedBy: .hisDraft, at: Date(timeIntervalSince1970: 100))
        plan.save(draft, in: context, at: Date(timeIntervalSince1970: 100))
        #expect(plan.changesSinceConfirmed(in: context) == nil)
        #expect(plan.content.uncheckedAnswers(herConfirmedAt: plan.herConfirmedAt).count == 1)

        plan.confirmWithHer(in: context, at: Date(timeIntervalSince1970: 200))
        #expect(plan.herConfirmedAt == Date(timeIntervalSince1970: 200))
        #expect(plan.reviewedAt == Date(timeIntervalSince1970: 200))
        #expect(plan.changesSinceConfirmed(in: context)?.isEmpty == true)
        #expect(plan.content.uncheckedAnswers(herConfirmedAt: plan.herConfirmedAt).isEmpty)

        draft.setAnswer("feeding", text: "Breastfeeding", decidedBy: .hisDraft, at: Date(timeIntervalSince1970: 300))
        plan.save(draft, in: context, at: Date(timeIntervalSince1970: 300))
        let changes = try #require(plan.changesSinceConfirmed(in: context))
        #expect(changes.map(\.description) == ["Feeding added"])
        #expect(plan.content.uncheckedAnswers(herConfirmedAt: plan.herConfirmedAt).map(\.sectionID) == ["feeding"])

        plan.markReviewed(in: context, at: Date(timeIntervalSince1970: 400))
        #expect(plan.reviewedAt == Date(timeIntervalSince1970: 400))
        #expect(plan.herConfirmedAt == Date(timeIntervalSince1970: 200))
        #expect(try revisions(model).map(\.reason) == [.saved, .confirmedWithHer, .saved, .reviewed])
    }

    @Test("A plan saved by an early build moves across once, as his drafts, from a version 1 store")
    func oldPlanMovesAcross() throws {
        let folder = FileManager.default.temporaryDirectory.appending(
            path: "MissionControlTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "Planning.store")
        let written = Date(timeIntervalSince1970: 1_790_000_000)
        do {
            let schema = Schema(versionedSchema: PlanningSchemaV1.self)
            let old = try ModelContainer(
                for: schema, configurations: ModelConfiguration("Planning", schema: schema, url: url))
            let record = BirthPlanRecord()
            record.headlines = ["Gas and air first", "", "Skin-to-skin straight away", "", ""]
            record.sections = [.feeding: "Breastfeeding", .photos: " "]
            record.updatedAt = written
            old.mainContext.insert(record)
            try old.mainContext.save()
        }
        func open() -> AppModel {
            AppModel(
                planning: Result { try Stores.planningContainer(at: url) },
                labour: Result { try Stores.labourContainer(inMemory: true) },
                emergencyCardURL: nil, runsMigrations: false)
        }
        do {
            let model = open()
            #expect(!model.planningUnavailable)
            let content = model.birthPlan.content
            #expect(content.filledTopFive == ["Gas and air first", "Skin-to-skin straight away"])
            #expect(content.answer(for: "feeding")?.decidedBy == .hisDraft)
            #expect(content.answer(for: "feeding")?.changedAt == written)
            #expect(content.answer(for: "photos") == nil)
            #expect(model.birthPlan.changedAt == written)
            #expect(model.birthPlan.herConfirmedAt == nil)
            #expect(try revisions(model).map(\.reason) == [.moved])
            let records = try model.planning.mainContext.fetch(FetchDescriptor<BirthPlanRecord>())
            #expect(records.allSatisfy { $0.isEmpty })
        }
        let reopened = open()
        let plans = try reopened.planning.mainContext.fetchCount(FetchDescriptor<BirthPlan>())
        #expect(plans == 1)
        #expect(try revisions(reopened).count == 1)
        #expect(reopened.birthPlan.content.filledTopFive.count == 2)
    }

    @Test("Moving an old plan never writes over a plan that's already been started")
    func moveKeepsNewPlan() throws {
        let model = AppModel(inMemory: true)
        let context = model.planning.mainContext
        model.birthPlan.save(BirthPlanContent(topFive: ["New plan"]), in: context)
        let record = BirthPlanRecord()
        record.headlines = ["Old plan"]
        context.insert(record)
        Migrations.moveBirthPlan(into: model.birthPlan, in: context)
        #expect(model.birthPlan.content.filledTopFive == ["New plan"])
        #expect(record.isEmpty)
    }

    @Test("The text to send her marks his drafts and includes what to do if plans change")
    func plainText() {
        var content = BirthPlanContent(topFive: ["Skin-to-skin straight away"])
        content.setAnswer("feeding", text: "Breastfeeding", decidedBy: .her, at: Date())
        content.setAnswer("cord", text: "Dad cuts it", decidedBy: .hisDraft, at: Date())
        content.setBranch(.caesarean, wishes: "Screen lowered", hisJob: "Ask for skin-to-skin", at: Date())
        let text = content.plainText(motherName: "Sam")
        #expect(text.hasPrefix("Birth plan for Sam"))
        #expect(text.contains("1. Skin-to-skin straight away"))
        #expect(text.contains("Feeding: Breastfeeding\n"))
        #expect(text.contains("Cutting the cord: Dad cuts it (my draft: is this right?)"))
        #expect(text.contains("If she has a caesarean: Screen lowered. My job: Ask for skin-to-skin"))
        #expect(text.hasSuffix("A list of preferences, not a contract. Things can change, and it's her choice."))
    }
}
