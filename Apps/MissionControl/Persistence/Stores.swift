import Foundation
import SwiftData
import os

/// The app keeps two SwiftData stores apart (App Store guideline 5.1.3):
/// - planning: the pregnancy profile and birth plan;
/// - labour: sessions and taps. Local only: no CloudKit, excluded from backups, and readable after
///   first unlock so the lock-screen controls in Phase 4 can write to it.
/// Each opens on its own, so one failing never takes the other down (`AppModel`).
enum Stores {
    static let appGroupIdentifier = "group.com.liamdaly.missioncontrol"
    static let log = Logger(subsystem: "com.liamdaly.missioncontrol", category: "storage")

    static func planningContainer(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            return try container(PlanningSchemaV2.self, PlanningMigrationPlan.self, name: "Planning", url: nil)
        }
        return try planningContainer(
            at: directory(named: "PlanningStore", excludeFromBackup: false).appending(path: "Planning.store"))
    }

    /// The planning store in a file of its own. The app keeps it in the App Group; tests use a temporary file.
    static func planningContainer(at url: URL) throws -> ModelContainer {
        try container(PlanningSchemaV2.self, PlanningMigrationPlan.self, name: "Planning", url: url)
    }

    static func labourContainer(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            return try container(LabourSchemaV1.self, LabourMigrationPlan.self, name: "Labour", url: nil)
        }
        return try labourContainer(
            at: directory(named: "LabourStore", excludeFromBackup: true).appending(path: "Labour.store"))
    }

    /// The labour store in a file of its own. The app keeps it in the App Group; tests use a temporary file.
    static func labourContainer(at url: URL) throws -> ModelContainer {
        try container(LabourSchemaV1.self, LabourMigrationPlan.self, name: "Labour", url: url)
    }

    /// Where the backup copy of the hospital's numbers lives (`EmergencyCard`), next to the planning store.
    static func emergencyCardURL() throws -> URL {
        try directory(named: "PlanningStore", excludeFromBackup: false).appending(path: "EmergencyCard.json")
    }

    /// An empty store in memory, for when the real one can't be opened. Making one only fails if the
    /// phone is out of memory, and then nothing else would work either.
    static func temporary(_ make: (Bool) throws -> ModelContainer) -> ModelContainer {
        do {
            return try make(true)
        } catch {
            fatalError("Couldn't create an in-memory store: \(error)")
        }
    }

    private static func container(
        _ version: any VersionedSchema.Type,
        _ plan: any SchemaMigrationPlan.Type,
        name: String,
        url: URL?
    ) throws -> ModelContainer {
        let schema = Schema(versionedSchema: version)
        let configuration =
            if let url {
                ModelConfiguration(name, schema: schema, url: url, cloudKitDatabase: .none)
            } else {
                ModelConfiguration(name, schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            }
        return try ModelContainer(for: schema, migrationPlan: plan, configurations: configuration)
    }

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
