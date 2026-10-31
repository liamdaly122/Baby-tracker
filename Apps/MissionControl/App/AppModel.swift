import Foundation
import MissionContent
import MissionCore
import Observation
import SwiftData

/// Owns the two stores, the content, the labour session and the watch link for the life of the app.
/// The stores open separately. If one can't be opened, an empty one in memory takes its place, so
/// labour mode always works; the screens say what isn't being kept (`planningUnavailable`,
/// `LabourSessionModel.isNotSaving`).
@MainActor
@Observable
final class AppModel {
    let planning: ModelContainer
    let labourStore: ModelContainer
    /// The real labour: saved, alerted and shared with the watch.
    let session: LabourSessionModel
    /// A practice run, if one is going. In memory only, with no alerts, no watch link and no dialling.
    private(set) var drill: DrillController?
    let notifier: ThresholdNotifier
    private(set) var sync: PhoneSync?
    private(set) var library: ContentLibrary
    private(set) var profile: MissionProfile
    private(set) var birthPlan: BirthPlanRecord
    /// The saved profile and birth plan couldn't be opened, so changes to them aren't kept. The
    /// profile was filled from the emergency card if there was one (`restoredFromCard`).
    let planningUnavailable: Bool
    let restoredFromCard: Bool
    /// The last save of the profile or birth plan failed.
    private(set) var planningSaveFailed = false
    /// Where the emergency card is kept. Nil keeps no card (in-memory runs).
    private let emergencyCardURL: URL?

    convenience init(inMemory: Bool = false) {
        self.init(
            planning: Result { try Stores.planningContainer(inMemory: inMemory) },
            labour: Result { try Stores.labourContainer(inMemory: inMemory) },
            emergencyCardURL: inMemory ? nil : try? Stores.emergencyCardURL(),
            runsMigrations: !inMemory
        )
    }

    init(
        planning: Result<ModelContainer, Error>,
        labour: Result<ModelContainer, Error>,
        emergencyCardURL: URL?,
        runsMigrations: Bool
    ) {
        let planningContainer = Self.opened(planning, name: "planning", temporary: Stores.planningContainer(inMemory:))
        self.planning = planningContainer
        labourStore = Self.opened(labour, name: "labour", temporary: Stores.labourContainer(inMemory:))
        self.emergencyCardURL = emergencyCardURL
        let planningUnavailable = (try? planning.get()) == nil
        self.planningUnavailable = planningUnavailable
        let labourUnavailable = (try? labour.get()) == nil
        let planningContext = planningContainer.mainContext
        let profile = Self.fetchOrInsert(MissionProfile.self, in: planningContext, make: MissionProfile.init)
        self.profile = profile
        birthPlan = Self.fetchOrInsert(BirthPlanRecord.self, in: planningContext, make: BirthPlanRecord.init)
        let card = planningUnavailable ? emergencyCardURL.flatMap(EmergencyCard.read) : nil
        restoredFromCard = card != nil
        if let card {
            profile.region = card.region
        }
        let library = (try? BundledContent.library(for: profile.region)) ?? Self.emptyLibrary(profile.region)
        self.library = library
        notifier = ThresholdNotifier()
        if let card {
            profile.restore(from: card, defaults: Self.thresholdTable(library, region: card.region).defaults)
        }
        if runsMigrations && !planningUnavailable && !labourUnavailable {
            Migrations.run(profile: profile, labour: labourStore.mainContext)
            try? planningContext.save()
        }

        let session = LabourSessionModel(context: labourStore.mainContext, deviceID: DeviceIdentity.current)
        self.session = session
        session.storeIsTemporary = labourUnavailable
        session.detailsProvider = { days in profile.triageDetails(gestationalAgeDays: days) }
        session.alerting = notifier
        reloadLibrary()

        let sync = PhoneSync(labour: session) { [unowned self] in self.brief }
        self.sync = sync
        session.sync = sync
        let legacyThresholds = currentThresholds
        session.loadActiveSession { record in
            // Saved before sessions kept their start: fix gestation at the start time now.
            SessionStart(
                sessionID: record.id,
                startedAt: record.startedAt,
                startedBy: record.ownerDeviceID,
                profile: profile.brief(thresholds: legacyThresholds).labourProfile(
                    at: record.startedAt, calendar: .current),
                thresholds: record.thresholds ?? legacyThresholds
            )
        }
        if !planningUnavailable {
            writeEmergencyCard()
        }
        sync.activate()
        sync.publishContext()
    }

    /// The thresholds a new labour would start with: region defaults plus any saved overrides.
    var thresholdTable: ThresholdTable {
        Self.thresholdTable(library, region: profile.region)
    }

    private static func thresholdTable(_ library: ContentLibrary, region: ContentRegion) -> ThresholdTable {
        library.thresholds.region == region ? library.thresholds : ThresholdTable.builtIn(for: region)
    }

    var currentThresholds: ThresholdProfile {
        thresholdTable.profile(applying: profile.thresholdOverrides)
    }

    /// What the watch needs to launch on its own.
    var brief: MissionBrief {
        profile.brief(thresholds: currentThresholds)
    }

    func reloadLibrary() {
        if library.region != profile.region {
            library = (try? BundledContent.library(for: profile.region)) ?? Self.emptyLibrary(profile.region)
        }
    }

    /// The labour the screens show: the real one whenever it's running, otherwise a practice run.
    var labour: LabourSessionModel {
        guard !session.isActive, let drill else { return session }
        return drill.labour
    }

    /// A practice run is on screen.
    var isDrilling: Bool { !session.isActive && drill != nil }

    /// LAUNCH: fixes gestation, region and thresholds for this labour, and tells the watch. Ends any
    /// practice run, and starts the session before asking about alerts, so a permission prompt
    /// can't hold it up.
    func launch() {
        endDrill()
        session.start(brief.sessionStart(at: Date(), by: session.deviceID, calendar: .current))
        Task { await notifier.requestAuthorization() }
    }

    /// A practice run on a pretend 39+0 labour. Asks about alerts too, as part of getting ready.
    func startDrill() {
        guard !session.isActive else { return }
        let profile = self.profile
        drill = try? DrillController(brief: brief) { days in profile.triageDetails(gestationalAgeDays: days) }
        Task { await notifier.requestAuthorization() }
    }

    func endDrill() {
        drill = nil
    }

    /// Saves the profile, updates the emergency card and sends the watch the new brief.
    func savePlanning() {
        do {
            try planning.mainContext.save()
            planningSaveFailed = false
        } catch {
            planningSaveFailed = true
            Stores.log.error("Couldn't save the profile: \(error)")
        }
        writeEmergencyCard()
        sync?.publishContext()
    }

    private func writeEmergencyCard() {
        if let emergencyCardURL {
            EmergencyCard.write(brief, to: emergencyCardURL)
        }
    }

    /// The store if it opened, or an empty one in memory if it didn't.
    private static func opened(
        _ result: Result<ModelContainer, Error>, name: String, temporary: (Bool) throws -> ModelContainer
    ) -> ModelContainer {
        switch result {
        case .success(let container):
            return container
        case .failure(let error):
            Stores.log.error("Couldn't open the \(name) store: \(error)")
            return Stores.temporary(temporary)
        }
    }

    private static func fetchOrInsert<Model: PersistentModel>(
        _ type: Model.Type,
        in context: ModelContext,
        make: () -> Model
    ) -> Model {
        if let existing = try? context.fetch(FetchDescriptor<Model>()).first {
            return existing
        }
        let model = make()
        context.insert(model)
        try? context.save()
        return model
    }

    private static func emptyLibrary(_ region: ContentRegion) -> ContentLibrary {
        // Only reachable if the bundle is damaged; thresholds still come from the built-in table.
        ContentLibrary(region: region, thresholds: ThresholdTable.builtIn(for: region))
    }
}

/// A stable ID for this install, used to tell phone taps from watch taps.
enum DeviceIdentity {
    private static let key = "missionControl.deviceID"

    static var current: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: key) {
            return existing
        }
        let made = "phone-\(UUID().uuidString.prefix(8).lowercased())"
        defaults.set(made, forKey: key)
        return made
    }
}
