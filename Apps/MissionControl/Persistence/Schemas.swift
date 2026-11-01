import Foundation
import SwiftData

// Each store has a numbered version, so an app update can change what's saved without losing it.
// Version 1 is what the first TestFlight build will ship. Before changing a model after that: copy
// its version 1 class into the version 1 schema as a nested type, add a version 2 schema with the
// new class, and add a migration stage from 1 to 2 with a test that opens a version 1 store.

enum PlanningSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [MissionProfile.self, BirthPlanRecord.self] }
}

/// Version 2 adds the birth places and the call list (review action 16). The profile keeps its old
/// hospital fields so version 1 still describes saved stores; `Migrations.moveHospital` moves them
/// into a `BirthPlace` once.
enum PlanningSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [MissionProfile.self, BirthPlanRecord.self, BirthPlace.self, CrewContact.self]
    }
}

/// Version 3 adds the birth plan's answers, branches and dated copies (review action 17). The old
/// `BirthPlanRecord` stays so earlier versions still match; `Migrations.moveBirthPlan` moves it once.
enum PlanningSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [
            MissionProfile.self, BirthPlanRecord.self, BirthPlace.self, CrewContact.self, BirthPlan.self,
            BirthPlanRevision.self,
        ]
    }
}

/// Version 4 adds how things ended (review action 10).
enum PlanningSchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }
    static var models: [any PersistentModel.Type] { PlanningSchemaV3.models + [OutcomeRecord.self] }
}

enum PlanningMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PlanningSchemaV1.self, PlanningSchemaV2.self, PlanningSchemaV3.self, PlanningSchemaV4.self]
    }
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: PlanningSchemaV1.self, toVersion: PlanningSchemaV2.self),
            .lightweight(fromVersion: PlanningSchemaV2.self, toVersion: PlanningSchemaV3.self),
            .lightweight(fromVersion: PlanningSchemaV3.self, toVersion: PlanningSchemaV4.self),
        ]
    }
}

enum LabourSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [LabourSessionRecord.self, TapEventRecord.self] }
}

enum LabourMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LabourSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
