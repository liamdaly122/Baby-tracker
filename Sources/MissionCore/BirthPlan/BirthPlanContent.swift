import Foundation

/// What the birth plan says: her top five, an answer per section, and what she'd want if plans
/// change. A value, so the app can edit a draft and save or discard it, keep dated copies, and say
/// what changed between two of them. Section IDs come from the app (and from birth plan content in
/// Phase 6), so older plans keep working when sections are added.
public struct BirthPlanContent: Codable, Sendable, Hashable {
    /// The things that matter most to her, in order. Up to five.
    public var topFive: [String]
    public var answers: [PlanAnswer]
    public var branches: [PlanBranch]

    public static let maxTopFive = 5

    public init(topFive: [String] = [], answers: [PlanAnswer] = [], branches: [PlanBranch] = []) {
        self.topFive = topFive
        self.answers = answers
        self.branches = branches
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        topFive = try container.decodeIfPresent([String].self, forKey: .topFive) ?? []
        answers = try container.decodeIfPresent([PlanAnswer].self, forKey: .answers) ?? []
        branches = try container.decodeIfPresent([PlanBranch].self, forKey: .branches) ?? []
    }

    /// The top five with blanks dropped.
    public var filledTopFive: [String] {
        topFive.map(Self.trimmed).filter { !$0.isEmpty }
    }

    public func answer(for sectionID: String) -> PlanAnswer? {
        answers.first { $0.sectionID == sectionID && !$0.isBlank }
    }

    public func branch(for scenario: PlanScenario) -> PlanBranch? {
        branches.first { $0.scenario == scenario && !$0.isBlank }
    }

    public var isEmpty: Bool {
        filledTopFive.isEmpty && answers.allSatisfy(\.isBlank) && branches.allSatisfy(\.isBlank)
    }

    /// Sets a section's answer. Its `changedAt` moves only if the text or who decided changed.
    public mutating func setAnswer(_ sectionID: String, text: String, decidedBy: PlanDecider, at date: Date) {
        if let index = answers.firstIndex(where: { $0.sectionID == sectionID }) {
            guard answers[index].text != text || answers[index].decidedBy != decidedBy else { return }
            answers[index].text = text
            answers[index].decidedBy = decidedBy
            answers[index].changedAt = date
        } else {
            answers.append(PlanAnswer(sectionID: sectionID, text: text, decidedBy: decidedBy, changedAt: date))
        }
    }

    /// Sets what she'd want, and his job, if this happens.
    public mutating func setBranch(_ scenario: PlanScenario, wishes: String, hisJob: String, at date: Date) {
        if let index = branches.firstIndex(where: { $0.scenario == scenario }) {
            guard branches[index].wishes != wishes || branches[index].hisJob != hisJob else { return }
            branches[index].wishes = wishes
            branches[index].hisJob = hisJob
            branches[index].changedAt = date
        } else {
            branches.append(PlanBranch(scenario: scenario, wishes: wishes, hisJob: hisJob, changedAt: date))
        }
    }

    /// What's different from `earlier`, ignoring blanks, spacing and dates: the top five as a whole,
    /// then each section and each branch that was added, changed or cleared.
    public func changes(since earlier: BirthPlanContent) -> [PlanChange] {
        var changes: [PlanChange] = []
        if filledTopFive != earlier.filledTopFive {
            changes.append(PlanChange(part: .topFive, kind: Self.kind(earlier.filledTopFive, filledTopFive)))
        }
        let sectionIDs = Self.orderedUnion(earlier.answers.map(\.sectionID), answers.map(\.sectionID))
        for sectionID in sectionIDs {
            let before = earlier.answer(for: sectionID)
            let after = answer(for: sectionID)
            let wasText = before.map { Self.trimmed($0.text) } ?? ""
            let isText = after.map { Self.trimmed($0.text) } ?? ""
            if wasText != isText || (!isText.isEmpty && before?.decidedBy != after?.decidedBy) {
                changes.append(PlanChange(part: .section(sectionID), kind: Self.kind(wasText, isText)))
            }
        }
        for scenario in PlanScenario.allCases {
            let before = earlier.branch(for: scenario)
            let after = branch(for: scenario)
            let was = before.map { [Self.trimmed($0.wishes), Self.trimmed($0.hisJob)] } ?? ["", ""]
            let now = after.map { [Self.trimmed($0.wishes), Self.trimmed($0.hisJob)] } ?? ["", ""]
            if was != now {
                changes.append(PlanChange(part: .branch(scenario), kind: Self.kind(was.joined(), now.joined())))
            }
        }
        return changes
    }

    /// Answers he wrote that she hasn't checked: his drafts changed since `herConfirmedAt`, or all of
    /// his drafts if she never has.
    public func uncheckedAnswers(herConfirmedAt: Date?) -> [PlanAnswer] {
        answers.filter { answer in
            guard !answer.isBlank, answer.decidedBy == .hisDraft else { return false }
            return herConfirmedAt.map { answer.changedAt > $0 } ?? true
        }
    }

    private static func kind<Value: Equatable & Collection>(_ before: Value, _ after: Value) -> PlanChange.Kind {
        if before.isEmpty { return .added }
        if after.isEmpty { return .removed }
        return .changed
    }

    private static func orderedUnion(_ first: [String], _ second: [String]) -> [String] {
        var seen = Set<String>()
        return (first + second).filter { seen.insert($0).inserted }
    }

    static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// One section of the plan, in words for now. `choiceIDs` is for the Phase 6 builder's choices.
public struct PlanAnswer: Codable, Sendable, Hashable {
    public var sectionID: String
    public var text: String
    public var choiceIDs: [String]
    public var decidedBy: PlanDecider
    /// When the words or who decided last changed. Opening and closing the plan doesn't move it.
    public var changedAt: Date

    public init(
        sectionID: String, text: String, choiceIDs: [String] = [], decidedBy: PlanDecider, changedAt: Date
    ) {
        self.sectionID = sectionID
        self.text = text
        self.choiceIDs = choiceIDs
        self.decidedBy = decidedBy
        self.changedAt = changedAt
    }

    public var isBlank: Bool { BirthPlanContent.trimmed(text).isEmpty && choiceIDs.isEmpty }
}

/// Whose decision an answer is. It's her plan: anything he writes on his own is a draft until
/// she's seen it.
public enum PlanDecider: String, Codable, Sendable, CaseIterable {
    case her
    case together
    case onTheDay
    case hisDraft
}

/// What she'd want, and what he'll do, if this happens.
public struct PlanBranch: Codable, Sendable, Hashable {
    public var scenario: PlanScenario
    public var wishes: String
    public var hisJob: String
    public var changedAt: Date

    public init(scenario: PlanScenario, wishes: String, hisJob: String, changedAt: Date) {
        self.scenario = scenario
        self.wishes = wishes
        self.hisJob = hisJob
        self.changedAt = changedAt
    }

    public var isBlank: Bool {
        BirthPlanContent.trimmed(wishes).isEmpty && BirthPlanContent.trimmed(hisJob).isEmpty
    }
}

/// The changes of plan the checklist asks them to talk through at 32 weeks (plan.plan-changes),
/// and moving to the labour ward from a midwife-led unit.
public enum PlanScenario: String, Codable, Sendable, CaseIterable {
    case induction
    case epidural
    case assistedBirth
    case caesarean
    case transfer
}

/// One difference between two versions of the plan.
public struct PlanChange: Sendable, Hashable {
    public enum Part: Sendable, Hashable {
        case topFive
        case section(String)
        case branch(PlanScenario)
    }

    public enum Kind: Sendable, Hashable {
        case added
        case changed
        case removed
    }

    public var part: Part
    public var kind: Kind
}
