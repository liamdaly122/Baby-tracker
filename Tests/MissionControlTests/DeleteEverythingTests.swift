import Foundation
import MissionCore
import SwiftData
import Testing

@testable import MissionControl

/// "Delete everything" (review action 12, PRT-10) and the privacy manifest: nothing he put in is
/// left in the app's stores or files, a running labour is never deleted, and the app tells Apple
/// it collects nothing.
@MainActor
@Suite("Delete everything")
struct DeleteEverythingTests {
    /// Both stores and the emergency card in a folder of their own, opened as the app does.
    private struct Files {
        let folder: URL

        init() throws {
            folder = FileManager.default.temporaryDirectory.appending(
                path: "MissionControlTests-\(UUID().uuidString)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        var card: URL { folder.appending(path: "EmergencyCard.json") }

        @MainActor
        func open() -> AppModel {
            AppModel(
                planning: Result { try Stores.planningContainer(at: folder.appending(path: "Planning.store")) },
                labour: Result { try Stores.labourContainer(at: folder.appending(path: "Labour.store")) },
                emergencyCardURL: card,
                runsMigrations: false
            )
        }

        func remove() {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    /// A model with something in every kind of record: her details, both places, a person to call,
    /// a birth plan, its saved copy and an old-style one, a finished labour with taps, and how it ended.
    private func filled(_ files: Files) throws -> AppModel {
        let model = files.open()
        model.profile.motherName = "Sam"
        model.profile.hospitalNumber = "RX123"
        model.profile.dueDateText = "2026-12-07"
        let booked = model.editablePlace(.booked)
        booked.name = "Northgate"
        booked.triagePhone = "01632 960118 option 2"
        model.editablePlace(.backup).name = "Riverside"
        model.planning.mainContext.insert(CrewContact(name: "Mum", phone: "07700 900123", role: .driver))
        #expect(model.birthPlan.save(BirthPlanContent(topFive: ["Low lights"]), in: model.planning.mainContext))
        // A plan from an early build that hasn't been moved across yet.
        let old = BirthPlanRecord()
        old.headlines = ["Music on"]
        model.planning.mainContext.insert(old)
        model.savePlanning()
        model.session.start(labourStart(at: Date()))
        model.session.tap()
        model.session.tap()
        model.recordOutcome(.allWell, birthAt: Date(), babyName: "Ada")
        UserDefaults.standard.set(true, forKey: LaunchDisclaimer.seenKey)
        return model
    }

    private func count<Model: PersistentModel>(_ type: Model.Type, in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<Model>())
    }

    /// How many records of each kind the stores hold, by name.
    private func counts(_ model: AppModel) throws -> [String: Int] {
        var counts: [String: Int] = [:]
        for type in PlanningSchemaV4.models {
            counts["\(type)"] = try count(type, in: model.planning.mainContext)
        }
        for type in LabourSchemaV1.models {
            counts["\(type)"] = try count(type, in: model.labourStore.mainContext)
        }
        return counts
    }

    @Test("Every record in both stores, the emergency card and the disclaimer mark go, and stay gone")
    func deletesEverything() throws {
        let files = try Files()
        defer { files.remove() }
        let model = try filled(files)
        let before = try counts(model)
        #expect(before.filter { $0.value == 0 }.keys.sorted() == [], "Every kind of record starts with something in it")
        #expect(FileManager.default.fileExists(atPath: files.card.path))

        try model.deleteEverything()

        // Only the blank profile and plan the app makes on first launch.
        var expected = try counts(model).mapValues { _ in 0 }
        expected["MissionProfile"] = 1
        expected["BirthPlan"] = 1
        #expect(try counts(model) == expected)
        #expect(model.profile.motherName.isEmpty && model.profile.dueDateText.isEmpty)
        #expect(model.birthPlan.content.isEmpty)
        #expect(model.outcome == nil && model.bookedPlace == nil)
        #expect(!FileManager.default.fileExists(atPath: files.card.path))
        #expect(UserDefaults.standard.object(forKey: LaunchDisclaimer.seenKey) == nil)

        // Opened again from the same files, as after a relaunch.
        let reopened = files.open()
        #expect(try counts(reopened) == expected)
        #expect(reopened.profile.motherName.isEmpty && reopened.outcome == nil)
    }

    @Test("After deleting, the app works as new: details save, the card comes back, and labour uses them")
    func worksAfterwards() throws {
        let files = try Files()
        defer { files.remove() }
        let model = try filled(files)
        try model.deleteEverything()
        model.profile.motherName = "Jo"
        model.savePlanning()
        #expect(EmergencyCard.read(from: files.card)?.motherName == "Jo")
        model.session.start(labourStart(at: Date()))
        #expect(model.session.isActive)
        // The call script reads the new profile, not the deleted one.
        #expect(model.session.detailsProvider(273).motherName == "Jo")
        model.session.end()
    }

    @Test("Never while labour mode is running")
    func notDuringLabour() throws {
        let files = try Files()
        defer { files.remove() }
        let model = files.open()
        model.profile.motherName = "Sam"
        model.savePlanning()
        model.session.start(labourStart(at: Date()))
        try model.deleteEverything()
        #expect(model.session.isActive)
        #expect(model.profile.motherName == "Sam")
        model.session.end()
    }

    @Test("The app tells Apple it tracks nothing and collects nothing, and why it reads its own settings")
    func privacyManifest() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let manifest = try #require(
            try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
        #expect((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        let reasons = (manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]]) ?? []
        #expect(reasons.count == 1)
        #expect(reasons.first?["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults")
        #expect(reasons.first?["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
    }
}
