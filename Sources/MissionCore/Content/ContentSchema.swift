import Foundation

// Codable DTOs for the bundled JSON content. One file per kind per region, each wrapped in a
// `ContentEnvelope`. Content is never persisted; only the user's state against stable item IDs is.

/// The region a content pack and threshold profile belong to.
public enum ContentRegion: String, Codable, Sendable, CaseIterable {
    case uk
    case us
}

/// How much humour copy carries. Labour mode forces `.off`.
public enum HumourLevel: String, Codable, Sendable, CaseIterable, Comparable {
    case off
    case mild
    case full

    private var rank: Int {
        switch self {
        case .off: 0
        case .mild: 1
        case .full: 2
        }
    }

    public static func < (lhs: HumourLevel, rhs: HumourLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// The content files that ship in `MissionContent/Content/<region>/<kind>.json`.
public enum ContentKind: String, Codable, Sendable, CaseIterable {
    case briefings
    case checklist
    case glossary
    case coaching
    case quiz
    case thresholds
    case badges
}

/// Wrapper shared by every content file.
public struct ContentEnvelope<Item: Codable & Sendable>: Codable, Sendable {
    public var schemaVersion: Int
    public var contentVersion: String
    public var region: ContentRegion
    public var items: [Item]

    public init(schemaVersion: Int, contentVersion: String, region: ContentRegion, items: [Item]) {
        self.schemaVersion = schemaVersion
        self.contentVersion = contentVersion
        self.region = region
        self.items = items
    }
}

/// Where a clinical item came from and who has reviewed it. Required on every clinical item.
public struct Provenance: Codable, Sendable, Hashable {
    public var sourceURL: URL
    public var sourceTitle: String
    /// ISO date the source was read, e.g. "2026-10-26".
    public var accessed: String
    /// Registered midwife who signed the item off. Nil until review; required for release.
    public var reviewer: String?
    public var reviewedOn: String?
    public var clinical: Bool

    public init(
        sourceURL: URL,
        sourceTitle: String,
        accessed: String,
        reviewer: String? = nil,
        reviewedOn: String? = nil,
        clinical: Bool
    ) {
        self.sourceURL = sourceURL
        self.sourceTitle = sourceTitle
        self.accessed = accessed
        self.reviewer = reviewer
        self.reviewedOn = reviewedOn
        self.clinical = clinical
    }
}

/// Copy with humour variants. `off` is mandatory; the others fall back full → mild → off.
public struct LocalizedCopy: Codable, Sendable, Hashable {
    public var off: String
    public var mild: String?
    public var full: String?

    public init(off: String, mild: String? = nil, full: String? = nil) {
        self.off = off
        self.mild = mild
        self.full = full
    }

    public func text(for level: HumourLevel) -> String {
        switch level {
        case .full: full ?? mild ?? off
        case .mild: mild ?? off
        case .off: off
        }
    }
}

/// Who delivers a briefing. The Flight Surgeon is the serious voice used for anything medical.
public enum Speaker: String, Codable, Sendable, CaseIterable {
    case capcom
    case flightSurgeon
    case veteran
}

public enum StoryAct: String, Codable, Sendable, CaseIterable {
    case recruitment
    case systemsCheck
    case countdown
    case holdAtTMinus
    case launch
    case splashdown
}

public enum ChecklistModule: String, Codable, Sendable, CaseIterable {
    case adminAndLeave
    case money
    case appointments
    case classes
    case birthPlan
    case hospitalBag
    case vehicle
    case homeModule
    case dayOfLogistics
    case skillsTraining
    case commanderSupport
    case splashdown
}

/// Stages used to filter glossary terms and coaching cards in labour mode.
public enum LabourStage: String, Codable, Sendable, CaseIterable {
    case latent
    case established
    case transition
    case pushing
    case thirdStage
    case theatre
    case goldenHour
    case postnatal
}

/// A date a checklist item is due, relative to the expected week of childbirth, due date or birth.
public struct Deadline: Codable, Sendable, Hashable {
    public enum Anchor: String, Codable, Sendable {
        case ewc
        case edd
        case birth
    }

    public var anchor: Anchor
    public var offsetDays: Int

    public init(anchor: Anchor, offsetDays: Int) {
        self.anchor = anchor
        self.offsetDays = offsetDays
    }
}

public struct ChecklistItem: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var module: ChecklistModule
    public var title: LocalizedCopy
    public var why: LocalizedCopy
    /// Medical wording that never varies with humour level.
    public var clinicalText: String?
    public var unlockWeek: Int
    public var deadline: Deadline?
    public var reminderDaysBefore: [Int]
    public var quizID: String?
    public var xp: Int
    public var provenance: Provenance?
}

public struct GlossaryEntry: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var term: String
    public var aliases: [String]
    public var plainEnglish: String
    /// 0 = nothing to worry about, 3 = act now.
    public var worryLevel: Int
    public var questionToAsk: String
    public var stages: [LabourStage]
    public var provenance: Provenance
}

/// Partner coaching for a labour stage. No humour variants by design.
public struct CoachingCard: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var stage: LabourStage
    public var title: String
    public var doThis: [String]
    public var avoidThis: [String]
    public var provenance: Provenance?
}

public struct Briefing: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var week: Int
    public var act: StoryAct
    public var speaker: Speaker
    public var title: LocalizedCopy
    public var body: LocalizedCopy
    public var provenance: Provenance?
}

public struct QuizQuestion: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var quizID: String
    public var prompt: String
    public var choices: [String]
    public var correctIndex: Int
    public var explanation: String
    public var provenance: Provenance?
}

public enum BadgeRuleKind: String, Codable, Sendable {
    case checklistItemsDone
    case moduleComplete
    case quizPassed
    case streakDays
}

public struct BadgeDefinition: Codable, Sendable, Hashable, Identifiable {
    public struct Rule: Codable, Sendable, Hashable {
        public var kind: BadgeRuleKind
        public var targetIDs: [String]
        public var count: Int?
    }

    public var id: String
    public var name: String
    public var description: LocalizedCopy
    public var rule: Rule
}

/// One field of the go/no-go threshold profile, with its safe bounds, as stored in thresholds.json.
public struct ThresholdItem: Codable, Sendable, Hashable, Identifiable {
    public enum Unit: String, Codable, Sendable {
        case seconds
        case minutes
        case count
        case ratio
    }

    public var id: ThresholdField
    public var defaultValue: Double
    public var min: Double
    public var max: Double
    /// When true, 0 means "rule switched off" and the bounds only apply to non-zero values.
    public var allowsDisabled: Bool
    public var unit: Unit
    public var note: String
    public var provenance: Provenance

    enum CodingKeys: String, CodingKey {
        case id
        case defaultValue = "default"
        case min
        case max
        case allowsDisabled
        case unit
        case note
        case provenance
    }
}

public enum ContentDecodingError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case regionMismatch(expected: ContentRegion, found: ContentRegion)
}

public enum ContentDecoding {
    public static let supportedSchemaVersion = 1

    /// Decodes a content file and checks its envelope.
    public static func envelope<Item: Codable & Sendable>(
        _ type: Item.Type,
        from data: Data,
        expectedRegion: ContentRegion? = nil
    ) throws -> ContentEnvelope<Item> {
        let envelope = try JSONDecoder().decode(ContentEnvelope<Item>.self, from: data)
        guard envelope.schemaVersion == supportedSchemaVersion else {
            throw ContentDecodingError.unsupportedSchemaVersion(envelope.schemaVersion)
        }
        if let expectedRegion, envelope.region != expectedRegion {
            throw ContentDecodingError.regionMismatch(expected: expectedRegion, found: envelope.region)
        }
        return envelope
    }
}
