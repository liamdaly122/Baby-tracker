import Foundation
import MissionContent
import MissionCore
import Observation
import SwiftData

/// Owns the two stores, the content and the labour session for the life of the app.
@MainActor
@Observable
final class AppModel {
    let planning: ModelContainer
    let labourStore: ModelContainer
    let labour: LabourSessionModel
    let notifier: ThresholdNotifier
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

        labour = LabourSessionModel(
            context: labourStore.mainContext,
            deviceID: DeviceIdentity.current,
            contextProvider: { moment in
                LabourContext(profile: profile.labourProfile(at: moment), triage: profile.triageDetails(at: moment))
            }
        )
        labour.alerting = notifier
        reloadLibrary()
    }

    /// The thresholds a new labour would start with: region defaults plus any saved overrides.
    var thresholdTable: ThresholdTable {
        library.thresholds.region == profile.region ? library.thresholds : ThresholdTable.builtIn(for: profile.region)
    }

    var currentThresholds: ThresholdProfile {
        thresholdTable.profile(applying: profile.thresholdOverrides)
    }

    func reloadLibrary() {
        if library.region != profile.region {
            library = (try? BundledContent.library(for: profile.region)) ?? Self.emptyLibrary(profile.region)
        }
    }

    func launch() async {
        await notifier.requestAuthorization()
        labour.start(region: profile.region, thresholds: currentThresholds)
    }

    func savePlanning() {
        try? planning.mainContext.save()
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
