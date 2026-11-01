import Foundation
import MissionCore
import SwiftData

/// Her birth plan (review action 17). The words live in `content`, a `BirthPlanContent` value, so
/// the editor works on a draft that is saved or discarded. The dates are kept apart: `changedAt`
/// moves only when the words do, `reviewedAt` when it was last looked at and still right, and
/// `herConfirmedAt` when she last read it and agreed. Every save, review and confirmation keeps a
/// dated copy (`BirthPlanRevision`), so the app can say what changed since she checked it.
/// It stays on this phone: never in iCloud.
@Model
final class BirthPlan {
    @Attribute(.unique) var id = UUID()
    var contentJSON: Data?
    var changedAt: Date?
    var reviewedAt: Date?
    var herConfirmedAt: Date?

    init() {}
}

/// A dated copy of the plan.
@Model
final class BirthPlanRevision {
    @Attribute(.unique) var id = UUID()
    var savedAt = Date.distantPast
    var reasonRaw: String = BirthPlanRevisionReason.saved.rawValue
    var contentJSON = Data()

    init(content: BirthPlanContent, reason: BirthPlanRevisionReason, at date: Date) {
        savedAt = date
        reasonRaw = reason.rawValue
        contentJSON = (try? JSONEncoder().encode(content)) ?? Data()
    }

    var content: BirthPlanContent? { try? JSONDecoder().decode(BirthPlanContent.self, from: contentJSON) }
    var reason: BirthPlanRevisionReason { BirthPlanRevisionReason(rawValue: reasonRaw) ?? .saved }
}

enum BirthPlanRevisionReason: String {
    /// He saved changes.
    case saved
    /// Looked at again, nothing to change.
    case reviewed
    /// She read it and agreed.
    case confirmedWithHer
    /// Moved from the old five-headlines record.
    case moved
}

extension BirthPlan {
    var content: BirthPlanContent {
        get { contentJSON.flatMap { try? JSONDecoder().decode(BirthPlanContent.self, from: $0) } ?? BirthPlanContent() }
        set { contentJSON = try? JSONEncoder().encode(newValue) }
    }

    /// Saves the draft if it really differs. Returns false if there was nothing to save, so
    /// opening and closing the editor never looks like a change.
    @discardableResult
    func save(_ draft: BirthPlanContent, in context: ModelContext, at date: Date = Date()) -> Bool {
        guard !draft.changes(since: content).isEmpty else { return false }
        content = draft
        changedAt = date
        context.insert(BirthPlanRevision(content: draft, reason: .saved, at: date))
        return true
    }

    /// Looked at again and still right.
    func markReviewed(in context: ModelContext, at date: Date = Date()) {
        reviewedAt = date
        context.insert(BirthPlanRevision(content: content, reason: .reviewed, at: date))
    }

    /// She read it through and agreed.
    func confirmWithHer(in context: ModelContext, at date: Date = Date()) {
        herConfirmedAt = date
        reviewedAt = date
        context.insert(BirthPlanRevision(content: content, reason: .confirmedWithHer, at: date))
    }

    /// The plan as she last agreed it, if she has.
    func lastConfirmed(in context: ModelContext) -> BirthPlanContent? {
        let raw = BirthPlanRevisionReason.confirmedWithHer.rawValue
        var descriptor = FetchDescriptor<BirthPlanRevision>(
            predicate: #Predicate { $0.reasonRaw == raw }, sortBy: [SortDescriptor(\.savedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.content
    }

    /// What has changed since she last agreed it. Nil if she never has.
    func changesSinceConfirmed(in context: ModelContext) -> [PlanChange]? {
        lastConfirmed(in: context).map { content.changes(since: $0) }
    }
}

/// The NHS birth plan sections, in the order a midwife reads them, with what goes in each.
enum BirthPlanSection: String, CaseIterable, Identifiable {
    case place
    case birthPartners
    case hisRole
    case aboutHer
    case environment
    case painRelief
    case positionsAndMonitoring
    case students
    case thirdStage
    case skinToSkin
    case vitaminK
    case feeding
    case cord
    case photos
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .place: "Where"
        case .birthPartners: "Birth partners"
        case .hisRole: "Your role"
        case .aboutHer: "About her"
        case .environment: "The room"
        case .painRelief: "Pain relief"
        case .positionsAndMonitoring: "Positions and monitoring"
        case .students: "Students"
        case .thirdStage: "Placenta (third stage)"
        case .skinToSkin: "Skin-to-skin"
        case .vitaminK: "Vitamin K"
        case .feeding: "Feeding"
        case .cord: "Cutting the cord"
        case .photos: "Photos and video"
        case .other: "Anything else"
        }
    }

    var prompt: String {
        switch self {
        case .place: "Home, midwife-led unit or labour ward"
        case .birthPartners: "Who's with her, and who goes into theatre"
        case .hisRole: "What she wants you to do, and when to leave it to the midwife"
        case .aboutHer: "Preferred name, language or interpreter, access needs, anything from before"
        case .environment: "Lights, music, quiet, her own things"
        case .painRelief: "What to try first, and what she'd rather avoid"
        case .positionsAndMonitoring: "Moving around, the pool, monitoring preferences"
        case .students: "Whether students can be in the room"
        case .thirdStage: "Injection (active) or waiting (physiological)"
        case .skinToSkin: "Straight away, ideally before the cord is cut"
        case .vitaminK: "Injection or oral doses"
        case .feeding: "Breast, expressed, formula or a mix"
        case .cord: "Not before 1 minute; who cuts it"
        case .photos: "What's OK and what isn't"
        case .other: "Culture, faith, anything else"
        }
    }

    /// A section's title from its stored ID, for a plan saved with a section this build doesn't know.
    static func title(for sectionID: String) -> String {
        BirthPlanSection(rawValue: sectionID)?.title ?? sectionID
    }
}

extension PlanScenario {
    var title: String {
        switch self {
        case .induction: "If she's induced"
        case .epidural: "If she has an epidural"
        case .assistedBirth: "If she needs forceps or ventouse"
        case .caesarean: "If she has a caesarean"
        case .transfer: "If she moves to the labour ward"
        }
    }

    var prompt: String {
        switch self {
        case .induction: "What she'd want to know or try first"
        case .epidural: "What still matters: positions, pushing, the room"
        case .assistedBirth: "Who stays with her, what to explain"
        case .caesarean: "Seeing the baby born, skin-to-skin in theatre, music"
        case .transfer: "What comes with you, who to tell"
        }
    }
}

extension PlanDecider {
    var title: String {
        switch self {
        case .her: "Her choice"
        case .together: "Decided together"
        case .onTheDay: "Decide on the day"
        case .hisDraft: "My draft: check with her"
        }
    }
}

extension PlanChange {
    /// "Pain relief changed", "If she's induced added".
    var description: String {
        let name =
            switch part {
            case .topFive: "What matters most"
            case .section(let id): BirthPlanSection.title(for: id)
            case .branch(let scenario): scenario.title
            }
        let what =
            switch kind {
            case .added: "added"
            case .changed: "changed"
            case .removed: "taken out"
            }
        return "\(name) \(what)"
    }
}

extension BirthPlanContent {
    /// The plan as plain text, to send her to check or paste into her notes app.
    func plainText(motherName: String) -> String {
        var lines = ["Birth plan\(motherName.isEmpty ? "" : " for \(motherName)")", ""]
        if !filledTopFive.isEmpty {
            lines.append("What matters most")
            lines += filledTopFive.enumerated().map { "\($0.offset + 1). \($0.element)" }
            lines.append("")
        }
        for section in BirthPlanSection.allCases {
            guard let answer = answer(for: section.id) else { continue }
            let note = answer.decidedBy == .hisDraft ? " (my draft: is this right?)" : ""
            lines.append("\(section.title): \(answer.text.trimmingCharacters(in: .whitespacesAndNewlines))\(note)")
        }
        let branches = PlanScenario.allCases.compactMap(branch(for:))
        if !branches.isEmpty {
            lines += ["", "If plans change"]
            for branch in branches {
                let parts = [branch.wishes, branch.hisJob.isEmpty ? "" : "My job: \(branch.hisJob)"]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                lines.append("\(branch.scenario.title): \(parts.joined(separator: ". "))")
            }
        }
        lines += ["", "A list of preferences, not a contract. Things can change, and it's her choice."]
        return lines.joined(separator: "\n")
    }
}
