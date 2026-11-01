import Foundation
import MissionCore
import SwiftData
import Testing

@testable import MissionControl

/// How things ended (review action 10): recorded, kept, and the app goes quiet when it should.
@MainActor
@Suite("How things ended")
struct OutcomeTests {
    @Test("Recording an outcome ends labour mode and its alerts, and tells the watch")
    func recordingEndsLabour() throws {
        let model = AppModel(inMemory: true)
        let alerts = RecordingAlerts()
        let sync = RecordingSync()
        model.session.alerting = alerts
        model.session.sync = sync
        model.launch()
        let sessionID = try #require(model.session.sessionID)
        let born = Date(timeIntervalSince1970: 1_800_000_000)

        model.recordOutcome(.babyNeedsCare, birthAt: born, babyName: "Ada")
        #expect(!model.session.isActive)
        #expect(alerts.ended == [sessionID])
        #expect(sync.ended == [sessionID])
        #expect(model.outcome?.outcome == .babyNeedsCare)
        #expect(model.outcome?.birthAt == born)
        #expect(model.outcome?.babyName == "Ada")
        #expect(model.brief.outcome == .babyNeedsCare)
    }

    @Test("Anything but 'all well' turns the humour off, whatever the setting, until it's taken away")
    func humourOff() {
        let model = AppModel(inMemory: true)
        model.profile.humour = .full
        #expect(model.humour == .full)
        model.recordOutcome(.allWell, birthAt: Date(), babyName: "")
        #expect(model.humour == .full)
        for outcome in [PregnancyOutcome.babyNeedsCare, .sheNeedsCare, .loss] {
            model.recordOutcome(outcome, birthAt: nil, babyName: "")
            #expect(model.humour == .off, "\(outcome)")
        }
        model.clearOutcome()
        #expect(model.outcome == nil)
        #expect(model.humour == .full)
        #expect(model.brief.outcome == nil)
    }

    @Test("After an outcome there's no practice run, and only one outcome is kept")
    func noDrillAfterwards() throws {
        let model = AppModel(inMemory: true)
        model.startDrill()
        #expect(model.isDrilling)
        model.recordOutcome(.loss, birthAt: nil, babyName: "")
        #expect(!model.isDrilling)
        model.startDrill()
        #expect(model.drill == nil)
        model.recordOutcome(.allWell, birthAt: Date(), babyName: "")
        #expect(try model.planning.mainContext.fetchCount(FetchDescriptor<OutcomeRecord>()) == 1)
    }

    @Test("The outcome survives a relaunch, and a version 3 store opens with none")
    func survivesRelaunch() throws {
        let folder = FileManager.default.temporaryDirectory.appending(
            path: "MissionControlTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "Planning.store")
        do {
            let schema = Schema(versionedSchema: PlanningSchemaV3.self)
            let old = try ModelContainer(
                for: schema, configurations: ModelConfiguration("Planning", schema: schema, url: url))
            let profile = MissionProfile()
            profile.motherName = "Sam"
            old.mainContext.insert(profile)
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
            #expect(model.outcome == nil)
            #expect(model.profile.motherName == "Sam")
            model.recordOutcome(.loss, birthAt: nil, babyName: "")
        }
        let reopened = open()
        #expect(reopened.outcome?.outcome == .loss)
        #expect(reopened.humour == .off)
    }

    @Test("The birth message makes no claim about how anyone is doing unless he writes one")
    func birthMessage() {
        let born = Date(timeIntervalSince1970: 1_800_000_000)
        let time = born.formatted(date: .omitted, time: .shortened)
        let caring = BirthOutcomeMessage.text(
            outcome: .babyNeedsCare, bornAt: born, babyName: "Ada",
            details: ["7 lb 2 oz", PregnancyOutcome.babyNeedsCare.defaultWellbeing, ""])
        #expect(caring == "Ada was born at \(time). 7 lb 2 oz.")
        let well = BirthOutcomeMessage.text(
            outcome: .allWell, bornAt: born, babyName: "",
            details: [PregnancyOutcome.allWell.defaultWellbeing, "We'll be in touch about visiting."])
        #expect(
            well == "Baby's here! Our baby was born at \(time). Mum and baby are doing well. "
                + "We'll be in touch about visiting.")
    }
}
