import Foundation
import MissionContent
import MissionCore
import Observation
import SwiftData

/// Owns the two stores, the content, the labour session and the watch link for the life of the app.
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

    init(inMemory: Bool = false) throws {
        planning = try Stores.planningContainer(inMemory: inMemory)
        labourStore = try Stores.labourContainer(inMemory: inMemory)
        let planningContext = planning.mainContext
        let profile = Self.fetchOrInsert(MissionProfile.self, in: planningContext, make: MissionProfile.init)
        self.profile = profile
        birthPlan = Self.fetchOrInsert(BirthPlanRecord.self, in: planningContext, make: BirthPlanRecord.init)
        library = (try? BundledContent.library(for: profile.region)) ?? Self.emptyLibrary(profile.region)
        notifier = ThresholdNotifier()
        if !inMemory {
            Migrations.run(profile: profile, labour: labourStore.mainContext)
            try? planningContext.save()
        }

        let session = LabourSessionModel(context: labourStore.mainContext, deviceID: DeviceIdentity.current)
        self.session = session
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
        sync.activate()
        sync.publishContext()
    }

    /// The thresholds a new labour would start with: region defaults plus any saved overrides.
    var thresholdTable: ThresholdTable {
        library.thresholds.region == profile.region ? library.thresholds : ThresholdTable.builtIn(for: profile.region)
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

    /// Saves the profile and sends the watch the new brief.
    func savePlanning() {
        try? planning.mainContext.save()
        sync?.publishContext()
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
