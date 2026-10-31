import Foundation
import MissionCore
import SwiftData
import Testing

@testable import MissionControl

/// The hospital and the call list (review action 16).
@MainActor
@Suite("Hospital and call list")
struct CallListTests {
    private struct Folder {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "MissionControlTests-\(UUID().uuidString)", directoryHint: .isDirectory)

        func make() throws -> Folder {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return self
        }

        func remove() {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func appModel(planningAt url: URL) -> AppModel {
        AppModel(
            planning: Result { try Stores.planningContainer(at: url) },
            labour: Result { try Stores.labourContainer(inMemory: true) },
            emergencyCardURL: nil,
            runsMigrations: false
        )
    }

    @Test("A version 1 store's hospital moves into a booked place once, with nothing lost")
    func hospitalMovesFromVersionOne() throws {
        let folder = try Folder().make()
        defer { folder.remove() }
        let url = folder.url.appending(path: "Planning.store")
        do {
            let schema = Schema(versionedSchema: PlanningSchemaV1.self)
            let old = try ModelContainer(
                for: schema, configurations: ModelConfiguration("Planning", schema: schema, url: url))
            let profile = MissionProfile()
            profile.motherName = "Sam"
            profile.unitName = "Northgate"
            profile.triagePhone = "01632 960118 option 2"
            profile.labourWardPhone = "01632 960245"
            profile.travelMinutes = 40
            profile.parkingNotes = "Multi-storey, pay by card"
            profile.afterHoursEntrance = "Clarendon Wing"
            profile.partnerCanStayOvernight = true
            old.mainContext.insert(profile)
            try old.mainContext.save()
        }
        do {
            let model = appModel(planningAt: url)
            #expect(!model.planningUnavailable)
            let place = try #require(model.bookedPlace)
            #expect(place.name == "Northgate")
            #expect(place.triageNumber(region: .uk)?.afterConnecting == "Then press 2")
            #expect(place.labourWardNumber(region: .uk) != nil)
            #expect(place.travelMinutes == 40)
            #expect(place.parkingNotes == "Multi-storey, pay by card")
            #expect(place.afterHoursEntrance == "Clarendon Wing")
            #expect(place.partnerCanStayOvernight)
            #expect(!model.profile.hasLegacyHospital)
            // The watch, the emergency card and the triage script read the booked place.
            #expect(model.brief.unitName == "Northgate")
            #expect(model.brief.triage == place.triageNumber(region: .uk))
            #expect(model.brief.travelMinutes == 40)
            #expect(model.profile.triageDetails(gestationalAgeDays: 273, place: place).travelMinutes == 40)
        }
        let reopened = appModel(planningAt: url)
        let places = try reopened.planning.mainContext.fetch(FetchDescriptor<BirthPlace>())
        #expect(places.count == 1)
        #expect(reopened.bookedPlace?.name == "Northgate")
    }

    @Test("Moving the old fields fills only the blanks of a place that already exists")
    func moveKeepsExistingPlace() throws {
        let model = AppModel(inMemory: true)
        let place = model.editablePlace(.booked)
        place.name = "Riverside"
        place.triagePhone = "01632 960331"
        model.profile.unitName = "Northgate"
        model.profile.triagePhone = "01632 960118"
        model.profile.labourWardPhone = "01632 960245"
        Migrations.moveHospital(from: model.profile, in: model.planning.mainContext)
        let places = try model.planning.mainContext.fetch(FetchDescriptor<BirthPlace>())
        #expect(places.count == 1)
        #expect(place.name == "Riverside")
        #expect(place.triagePhone == "01632 960331")
        #expect(place.labourWardPhone == "01632 960245")
        #expect(!model.profile.hasLegacyHospital)
    }

    @Test("With no hospital added, the brief has no unit and labour mode still starts")
    func noPlace() {
        let model = AppModel(inMemory: true)
        #expect(model.bookedPlace == nil)
        #expect(model.brief.unitName.isEmpty && model.brief.triage == nil)
        model.launch()
        #expect(model.session.isActive)
    }

    @Test("The numbers need checking until he has, and again from 34 weeks if he checked before")
    func numbersCheck() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let calendar = Calendar(identifier: .gregorian)
        func pregnancy(atDays days: Int) -> PregnancyCalendar {
            PregnancyCalendar(dueDate: CalendarDay(now, in: calendar).adding(days: 280 - days))
        }
        let day: TimeInterval = 86_400
        let place = BirthPlace(role: .booked)
        #expect(place.numbersNeedChecking(calendar: pregnancy(atDays: 200), now: now, in: calendar))
        place.numbersCheckedAt = now.addingTimeInterval(-10 * day)
        // No due date: checked once is enough.
        #expect(!place.numbersNeedChecking(calendar: nil, now: now, in: calendar))
        // Checked at 32+3, now 33+6: fine.
        #expect(!place.numbersNeedChecking(calendar: pregnancy(atDays: 237), now: now, in: calendar))
        // Checked at 32+4, now 34+0: check again.
        #expect(place.numbersNeedChecking(calendar: pregnancy(atDays: 238), now: now, in: calendar))
        // Checked at 34+1, now 35+4: fine.
        place.numbersCheckedAt = now.addingTimeInterval(-10 * day)
        #expect(!place.numbersNeedChecking(calendar: pregnancy(atDays: 249), now: now, in: calendar))
    }

    @Test("Directions go to Apple Maps with the address, and only when there is one")
    func directions() throws {
        let place = BirthPlace(role: .booked)
        #expect(place.directionsURL == nil)
        place.address = "Great George Street, Leeds LS1 3EX"
        let url = try #require(place.directionsURL)
        #expect(url.host() == "maps.apple.com")
        #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value == place.address)
    }

    @Test("People on the call list can have numbers abroad, and get a text link but short codes don't")
    func crewNumbers() throws {
        let gran = CrewContact(name: "Gran", phone: "+33 6 12 34 56 78", role: .family)
        guard case .success = gran.phoneCheck(region: .uk) else {
            Issue.record("An overseas number should be allowed on the call list")
            return
        }
        let mum = CrewContact(name: "Mum", phone: "07700 900123", role: .driver)
        #expect(mum.textURL(region: .uk)?.absoluteString == "sms:+447700900123")
        let odd = CrewContact(name: "Odd", phone: "111")
        #expect(odd.textURL(region: .uk) == nil)
        let blank = CrewContact(name: "Blank")
        #expect(blank.phoneCheck(region: .uk) == nil && blank.textURL(region: .uk) == nil)
    }

    @Test("An empty backup is removed, and the booked place is kept")
    func removePlace() throws {
        let model = AppModel(inMemory: true)
        let booked = model.editablePlace(.booked)
        booked.name = "Northgate"
        let backup = model.editablePlace(.backup)
        #expect(backup.isBlank)
        model.removePlace(backup)
        #expect(model.place(.backup) == nil)
        #expect(model.bookedPlace?.name == "Northgate")
    }
}
