import Foundation

/// Everything bundled for one region, decoded and ready to use.
public struct ContentLibrary: Sendable {
    public var region: ContentRegion
    public var checklist: [ChecklistItem]
    public var glossary: [GlossaryEntry]
    public var coaching: [CoachingCard]
    public var briefings: [Briefing]
    public var quiz: [QuizQuestion]
    public var badges: [BadgeDefinition]
    public var thresholds: ThresholdTable
    /// The contentVersion of each file that loaded.
    public var versions: [ContentKind: String]

    public init(
        region: ContentRegion,
        checklist: [ChecklistItem] = [],
        glossary: [GlossaryEntry] = [],
        coaching: [CoachingCard] = [],
        briefings: [Briefing] = [],
        quiz: [QuizQuestion] = [],
        badges: [BadgeDefinition] = [],
        thresholds: ThresholdTable,
        versions: [ContentKind: String] = [:]
    ) {
        self.region = region
        self.checklist = checklist
        self.glossary = glossary
        self.coaching = coaching
        self.briefings = briefings
        self.quiz = quiz
        self.badges = badges
        self.thresholds = thresholds
        self.versions = versions
    }

    public func checklistItem(id: String) -> ChecklistItem? {
        checklist.first { $0.id == id }
    }

    public func checklist(in module: ChecklistModule) -> [ChecklistItem] {
        checklist.filter { $0.module == module }
    }

    public func questions(forQuiz quizID: String) -> [QuizQuestion] {
        quiz.filter { $0.quizID == quizID }
    }

    public var quizIDs: [String] {
        var seen: Set<String> = []
        return quiz.map(\.quizID).filter { seen.insert($0).inserted }
    }

    /// The latest weekly story beat at or before `week`. Launch and splashdown beats are left out:
    /// they play when labour mode starts and when it ends, not by week.
    public func briefing(forWeek week: Int) -> Briefing? {
        briefings
            .filter { $0.week <= week && $0.act != .launch && $0.act != .splashdown }
            .max { $0.week < $1.week }
    }

    /// The beat for an act, such as `.launch` when labour mode starts.
    public func briefing(for act: StoryAct) -> Briefing? {
        briefings.first { $0.act == act }
    }

    public func coachingCards(for stage: LabourStage) -> [CoachingCard] {
        coaching.filter { $0.stage == stage }
    }
}

/// A broken link between content files, found by `ContentLoader.problems(in:)`.
public enum ContentProblem: Hashable, Sendable, CustomStringConvertible {
    case duplicateID(kind: ContentKind, id: String)
    case missingQuiz(checklistID: String, quizID: String)
    case quizTooShort(quizID: String, count: Int)
    case badAnswerIndex(questionID: String)
    case missingBadgeTarget(badgeID: String, target: String)

    public var description: String {
        switch self {
        case .duplicateID(let kind, let id): "\(kind.rawValue): duplicate id \(id)"
        case .missingQuiz(let checklistID, let quizID): "checklist \(checklistID): quiz \(quizID) not found"
        case .quizTooShort(let quizID, let count): "quiz \(quizID): \(count) questions, needs at least 3"
        case .badAnswerIndex(let questionID): "quiz question \(questionID): correctIndex out of range"
        case .missingBadgeTarget(let badgeID, let target): "badge \(badgeID): target \(target) not found"
        }
    }
}

public enum ContentLoader {
    /// Questions each skill quiz needs (a short lesson plus a 3-question quiz per skill).
    public static let minimumQuizQuestions = 3

    /// Loads every kind for a region. `data` returns nil for a kind that isn't shipped yet, which
    /// loads as empty; thresholds fall back to the compiled-in table so the timer always works.
    public static func load(
        region: ContentRegion,
        data: (ContentKind) throws -> Data?
    ) throws -> ContentLibrary {
        var versions: [ContentKind: String] = [:]

        func items<Item: Codable & Sendable>(_ type: Item.Type, _ kind: ContentKind) throws -> [Item] {
            guard let bytes = try data(kind) else { return [] }
            let envelope = try ContentDecoding.envelope(type, from: bytes, expectedRegion: region)
            versions[kind] = envelope.contentVersion
            return envelope.items
        }

        let thresholdItems = try items(ThresholdItem.self, .thresholds)
        let thresholds =
            thresholdItems.isEmpty
            ? ThresholdTable.builtIn(for: region)
            : try ThresholdTable(
                file: ContentEnvelope(schemaVersion: 1, contentVersion: "", region: region, items: thresholdItems)
            )
        return ContentLibrary(
            region: region,
            checklist: try items(ChecklistItem.self, .checklist),
            glossary: try items(GlossaryEntry.self, .glossary),
            coaching: try items(CoachingCard.self, .coaching),
            briefings: try items(Briefing.self, .briefings),
            quiz: try items(QuizQuestion.self, .quiz),
            badges: try items(BadgeDefinition.self, .badges),
            thresholds: thresholds,
            versions: versions
        )
    }

    /// Cross-file checks the decoder can't do. The bundled content must have none.
    public static func problems(in library: ContentLibrary) -> [ContentProblem] {
        var problems: [ContentProblem] = []
        problems += duplicates(library.checklist.map(\.id), kind: .checklist)
        problems += duplicates(library.glossary.map(\.id), kind: .glossary)
        problems += duplicates(library.coaching.map(\.id), kind: .coaching)
        problems += duplicates(library.briefings.map(\.id), kind: .briefings)
        problems += duplicates(library.quiz.map(\.id), kind: .quiz)
        problems += duplicates(library.badges.map(\.id), kind: .badges)

        let quizIDs = Set(library.quizIDs)
        for item in library.checklist {
            if let quizID = item.quizID, !quizIDs.contains(quizID) {
                problems.append(.missingQuiz(checklistID: item.id, quizID: quizID))
            }
        }
        for quizID in library.quizIDs {
            let count = library.questions(forQuiz: quizID).count
            if count < minimumQuizQuestions {
                problems.append(.quizTooShort(quizID: quizID, count: count))
            }
        }
        for question in library.quiz where !question.choices.indices.contains(question.correctIndex) {
            problems.append(.badAnswerIndex(questionID: question.id))
        }

        let checklistIDs = Set(library.checklist.map(\.id))
        let modules = Set(ChecklistModule.allCases.map(\.rawValue))
        for badge in library.badges {
            let valid: Set<String> =
                switch badge.rule.kind {
                case .checklistItemsDone: checklistIDs
                case .moduleComplete: modules
                case .quizPassed: quizIDs
                case .streakDays: []
                }
            for target in badge.rule.targetIDs where !valid.contains(target) {
                problems.append(.missingBadgeTarget(badgeID: badge.id, target: target))
            }
        }
        return problems
    }

    private static func duplicates(_ ids: [String], kind: ContentKind) -> [ContentProblem] {
        var seen: Set<String> = []
        return ids.filter { !seen.insert($0).inserted }.map { .duplicateID(kind: kind, id: $0) }
    }
}
