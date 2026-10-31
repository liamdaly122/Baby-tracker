import Foundation
import SwiftData

/// The app keeps two SwiftData stores apart (App Store guideline 5.1.3):
/// - planning: the pregnancy profile and birth plan;
/// - labour: sessions and taps. Local only: no CloudKit, excluded from backups, and readable after
///   first unlock so the lock-screen controls in Phase 4 can write to it.
enum Stores {
    static let appGroupIdentifier = "group.com.liamdaly.missioncontrol"

    static func planningContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([MissionProfile.self, BirthPlanRecord.self])
        let configuration =
            inMemory
            ? ModelConfiguration("Planning", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            : ModelConfiguration(
                "Planning",
                schema: schema,
                url: try directory(named: "PlanningStore", excludeFromBackup: false).appending(path: "Planning.store"),
                cloudKitDatabase: .none
            )
        return try ModelContainer(for: schema, configurations: configuration)
    }

    static func labourContainer(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            let configuration = ModelConfiguration(
                "Labour", schema: labourSchema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            return try ModelContainer(for: labourSchema, configurations: configuration)
        }
        return try labourContainer(
            at: directory(named: "LabourStore", excludeFromBackup: true).appending(path: "Labour.store"))
    }

    /// The labour store in a file of its own. The app keeps it in the App Group; tests use a temporary file.
    static func labourContainer(at url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration("Labour", schema: labourSchema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: labourSchema, configurations: configuration)
    }

    private static var labourSchema: Schema { Schema([LabourSessionRecord.self, TapEventRecord.self]) }

    /// A folder in the App Group container (shared with the widget and, later, intents), or in
    /// Application Support when the App Group isn't available (unsigned simulator builds).
    private static func directory(named name: String, excludeFromBackup: Bool) throws -> URL {
        let fileManager = FileManager.default
        let base: URL
        if let group = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            base = group
        } else {
            base = try fileManager.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        }
        var folder = base.appending(path: name, directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: folder,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        if excludeFromBackup {
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try folder.setResourceValues(values)
        }
        return folder
    }
}
