import Foundation
import MissionCore
import SwiftData
import Testing

@testable import MissionControl

private struct DiskFull: Error {}

/// A folder for one test's files, removed afterwards.
private struct TempFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory.appending(
            path: "MissionControlTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func file(_ name: String) -> URL { url.appending(path: name) }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

/// One store failing must never stop labour mode, or lose the hospital's number.
@MainActor
@Suite("Storage problems")
struct StorageTests {
    private func inMemory(_ make: (Bool) throws -> ModelContainer) -> Result<ModelContainer, Error> {
        Result { try make(true) }
    }

    /// A model whose profile names the unit, with its numbers and a midwife's hold, saved to `card`.
    private func savedProfile(card: URL) throws -> AppModel {
        let model = AppModel(
            planning: inMemory(Stores.planningContainer(inMemory:)),
            labour: inMemory(Stores.labourContainer(inMemory:)),
            emergencyCardURL: card,
            runsMigrations: false
        )
        model.profile.motherName = "Sam"
        model.profile.unitName = "Northgate"
        model.profile.triagePhone = "01632 960118 option 2"
        model.profile.labourWardPhone = "01632 960245"
        model.profile.dueDateText = "2026-12-07"
        model.profile.thresholdOverrides = [.patternWindowSec: 1800]
        model.savePlanning()
        return model
    }

    @Test("Healthy stores show no problems")
    func healthy() {
        let model = AppModel(inMemory: true)
        #expect(!model.planningUnavailable && !model.restoredFromCard && !model.planningSaveFailed)
        #expect(!model.session.storeIsTemporary && !model.session.isNotSaving)
    }

    @Test("If her details can't be opened, labour mode starts from the emergency card and rings the right unit")
    func planningFailsWithCard() throws {
        let folder = try TempFolder()
        defer { folder.remove() }
        let card = folder.file("EmergencyCard.json")
        let saved = try savedProfile(card: card)

        let model = AppModel(
            planning: .failure(DiskFull()),
            labour: inMemory(Stores.labourContainer(inMemory:)),
            emergencyCardURL: card,
            runsMigrations: false
        )
        #expect(model.planningUnavailable && model.restoredFromCard)
        #expect(model.profile.unitName == "Northgate")
        #expect(model.profile.motherName == "Sam")
        #expect(model.profile.triageNumber?.dialable == saved.profile.triageNumber?.dialable)
        #expect(model.profile.triageNumber?.afterConnecting == saved.profile.triageNumber?.afterConnecting)
        #expect(model.profile.labourWardNumber != nil)
        #expect(model.currentThresholds == saved.currentThresholds)
        #expect(model.currentThresholds.patternWindowSec == 1800)

        model.launch()
        #expect(model.session.isActive)
        #expect(model.session.start?.profile.gestationalAgeDays != nil)
        #expect(!model.session.isNotSaving)
    }

    @Test("With no emergency card either, labour mode still starts, on a blank profile")
    func planningFailsWithoutCard() throws {
        let folder = try TempFolder()
        defer { folder.remove() }
        let model = AppModel(
            planning: .failure(DiskFull()),
            labour: inMemory(Stores.labourContainer(inMemory:)),
            emergencyCardURL: folder.file("EmergencyCard.json"),
            runsMigrations: false
        )
        #expect(model.planningUnavailable && !model.restoredFromCard)
        #expect(model.profile.triageNumber == nil)
        model.launch()
        #expect(model.session.isActive)
        // No due date, so labour mode asks "Is she 37 weeks or more?" and says call until it's answered.
        #expect(model.session.needsTermAnswer)
    }

    @Test("If the labour store can't be opened, the timer still works and says it isn't saving")
    func labourFails() {
        let model = AppModel(
            planning: inMemory(Stores.planningContainer(inMemory:)),
            labour: .failure(DiskFull()),
            emergencyCardURL: nil,
            runsMigrations: false
        )
        #expect(model.session.storeIsTemporary && model.session.isNotSaving)
        #expect(!model.planningUnavailable)
        model.launch()
        model.session.tap()
        #expect(model.session.openContraction != nil)
        // A practice run is in memory on purpose, so it never says it isn't saving.
        let practice = AppModel(inMemory: true)
        practice.startDrill()
        #expect(practice.drill?.labour.isNotSaving == false)
    }

    @Test("Saving the profile keeps the emergency card up to date")
    func cardFollowsSaves() throws {
        let folder = try TempFolder()
        defer { folder.remove() }
        let card = folder.file("EmergencyCard.json")
        let model = try savedProfile(card: card)
        #expect(EmergencyCard.read(from: card)?.unitName == "Northgate")
        model.profile.unitName = "Riverside"
        model.savePlanning()
        let saved = try #require(EmergencyCard.read(from: card))
        #expect(saved.unitName == "Riverside")
        #expect(saved.triage == model.brief.triage)
        #expect(saved.thresholds == model.brief.thresholds)
        // A damaged card is ignored rather than trusted.
        try Data("not a card".utf8).write(to: card)
        #expect(EmergencyCard.read(from: card) == nil)
    }

    @Test("A planning store saved before stores had versions opens as version 1 with nothing lost")
    func oldPlanningStoreOpens() throws {
        let folder = try TempFolder()
        defer { folder.remove() }
        let url = folder.file("Planning.store")
        do {
            let schema = Schema([MissionProfile.self, BirthPlanRecord.self])
            let old = try ModelContainer(
                for: schema, configurations: ModelConfiguration("Planning", schema: schema, url: url))
            let profile = MissionProfile()
            profile.unitName = "Northgate"
            old.mainContext.insert(profile)
            try old.mainContext.save()
        }
        let reopened = try Stores.planningContainer(at: url)
        let profiles = try reopened.mainContext.fetch(FetchDescriptor<MissionProfile>())
        #expect(profiles.map(\.unitName) == ["Northgate"])
    }

    @Test("A labour store saved before stores had versions opens as version 1 and the labour carries on")
    func oldLabourStoreOpens() throws {
        let folder = try TempFolder()
        defer { folder.remove() }
        let url = folder.file("Labour.store")
        let clock = TestClock()
        do {
            let schema = Schema([LabourSessionRecord.self, TapEventRecord.self])
            let old = try ModelContainer(
                for: schema, configurations: ModelConfiguration("Labour", schema: schema, url: url))
            let model = LabourSessionModel(context: old.mainContext, deviceID: "phone-test") { clock.now }
            model.start(labourStart(at: clock.now))
            model.tap()
        }
        let reopened = try Stores.labourContainer(at: url)
        let model = LabourSessionModel(context: reopened.mainContext, deviceID: "phone-test") { clock.now }
        model.loadActiveSession { record in labourStart(at: record.startedAt) }
        #expect(model.isActive)
        #expect(model.openContraction != nil)
    }
}
