import Foundation
import MissionCore
import SwiftData

/// The pregnancy and her details. Lives in the planning store, which never holds labour data. The
/// hospital and the call list have records of their own (`BirthPlace`, `CrewContact`).
@Model
final class MissionProfile {
    var dueDateText: String = ""
    var regionRaw: String = ContentRegion.uk.rawValue
    var parity: Int = 0
    var previousFastLabour: Bool = false
    var motherName: String = ""
    var hospitalNumber: String = ""
    var notes: String = ""
    var gbsPositive: Bool = false
    var plannedCaesarean: Bool = false
    // The hospital, before it had a `BirthPlace` of its own. Kept so version 1 of the store still
    // matches this class; `Migrations.moveHospital` moves anything here into a `BirthPlace` and
    // clears it. Nothing else reads these.
    var travelMinutes: Int?
    var unitName: String = ""
    var triagePhone: String = ""
    var labourWardPhone: String = ""
    var parkingNotes: String = ""
    var afterHoursEntrance: String = ""
    var partnerCanStayOvernight: Bool = false
    var humourRaw: String = HumourLevel.mild.rawValue
    var thresholdOverridesJSON: Data?

    init() {}
}

extension MissionProfile {
    var dueDate: CalendarDay? {
        get {
            let parts = dueDateText.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            return CalendarDay(year: parts[0], month: parts[1], day: parts[2])
        }
        set { dueDateText = newValue?.description ?? "" }
    }

    var region: ContentRegion {
        get { ContentRegion(rawValue: regionRaw) ?? .uk }
        set { regionRaw = newValue.rawValue }
    }

    var humour: HumourLevel {
        get { HumourLevel(rawValue: humourRaw) ?? .mild }
        set { humourRaw = newValue.rawValue }
    }

    var pregnancyCalendar: PregnancyCalendar? {
        dueDate.map(PregnancyCalendar.init(dueDate:))
    }

    var thresholdOverrides: [ThresholdField: Double] {
        get {
            guard let data = thresholdOverridesJSON,
                let raw = try? JSONDecoder().decode([String: Double].self, from: data)
            else { return [:] }
            var overrides: [ThresholdField: Double] = [:]
            for (key, value) in raw {
                if let field = ThresholdField(rawValue: key) {
                    overrides[field] = value
                }
            }
            return overrides
        }
        set {
            let raw = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.rawValue, $0.value) })
            thresholdOverridesJSON = raw.isEmpty ? nil : try? JSONEncoder().encode(raw)
        }
    }

    /// Everything labour mode needs to start, on the phone or the watch, with the hospital from
    /// `place` (where she's booked). Gestation is worked out from it once, when labour starts.
    func brief(thresholds: ThresholdProfile, place: BirthPlace?, now: Date = Date()) -> MissionBrief {
        MissionBrief(
            region: region,
            dueDateText: dueDate?.description,
            parity: parity,
            previousFastLabour: previousFastLabour,
            travelMinutes: place?.travelMinutes,
            thresholds: thresholds,
            motherName: motherName,
            unitName: place?.name ?? "",
            triage: place?.triageNumber(region: region),
            labourWard: place?.labourWardNumber(region: region),
            gbsPositive: gbsPositive,
            plannedCaesarean: plannedCaesarean,
            updatedAt: now
        )
    }

    /// Her details for the triage call. Gestation comes from the session, fixed when it started.
    func triageDetails(gestationalAgeDays: Int?, place: BirthPlace?) -> TriageDetails {
        TriageDetails(
            motherName: motherName,
            hospitalNumber: hospitalNumber,
            gestationalAge: gestationalAgeDays.map(GestationalAge.init(totalDays:)),
            parity: parity,
            previousFastLabour: previousFastLabour,
            travelMinutes: place?.travelMinutes,
            notes: notes,
            gbsPositive: gbsPositive,
            plannedCaesarean: plannedCaesarean
        )
    }

    /// True if the old hospital fields (before `BirthPlace`) hold anything.
    var hasLegacyHospital: Bool {
        !unitName.isEmpty || !triagePhone.isEmpty || !labourWardPhone.isEmpty || travelMinutes != nil
            || !parkingNotes.isEmpty || !afterHoursEntrance.isEmpty || partnerCanStayOvernight
    }
}

extension PhoneNumber.Problem {
    /// What went wrong, and how to fix it.
    var message: String {
        switch self {
        case .empty: "Add a number."
        case .letters: "Use digits only. Put menu options after the number, like “option 2”."
        case .twoNumbers: "That looks like two numbers. Save each one in its own field."
        case .tooShort: "That looks a digit short. Check it against her notes."
        case .tooLong: "That's too long. Check it against her notes."
        case .invalid: "That doesn't look like a number for this country. Check it against her notes."
        case .overseas: "That's an overseas number. Ask the unit for a local one."
        }
    }

    /// The same for a person on the call list, whose number isn't in her notes.
    var personMessage: String {
        switch self {
        case .tooShort: "That looks a digit short. Check it with them."
        case .tooLong: "That's too long. Check it with them."
        case .invalid:
            "That doesn't look like a number for this country. For a number abroad, start with + and the country code."
        case .empty, .letters, .twoNumbers, .overseas: message
        }
    }
}

/// The NHS birth plan sections, in the order a midwife reads them.
enum BirthPlanSection: String, CaseIterable, Identifiable {
    case place
    case birthPartners
    case painRelief
    case positionsAndMonitoring
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
        case .painRelief: "Pain relief"
        case .positionsAndMonitoring: "Positions and monitoring"
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
        case .painRelief: "What to try first, and what she'd rather avoid"
        case .positionsAndMonitoring: "Moving around, the pool, monitoring preferences"
        case .thirdStage: "Injection (active) or waiting (physiological)"
        case .skinToSkin: "Straight away, ideally before the cord is cut"
        case .vitaminK: "Injection or oral doses"
        case .feeding: "Breast, expressed, formula or a mix"
        case .cord: "Not before 1 minute; who cuts it"
        case .photos: "What's OK and what isn't"
        case .other: "Culture, faith, interpreter, past experiences"
        }
    }
}

/// The birth plan. The full builder and PDF arrive in Phase 6; labour mode reads this.
@Model
final class BirthPlanRecord {
    /// The top five things that matter most, shown large on one screen.
    var headlines: [String] = []
    var sectionsJSON: Data?
    var updatedAt: Date = Date.distantPast

    init() {}
}

extension BirthPlanRecord {
    var sections: [BirthPlanSection: String] {
        get {
            guard let data = sectionsJSON, let raw = try? JSONDecoder().decode([String: String].self, from: data)
            else { return [:] }
            var result: [BirthPlanSection: String] = [:]
            for (key, value) in raw {
                if let section = BirthPlanSection(rawValue: key) {
                    result[section] = value
                }
            }
            return result
        }
        set {
            let raw = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.rawValue, $0.value) })
            sectionsJSON = try? JSONEncoder().encode(raw)
        }
    }

    var isEmpty: Bool {
        headlines.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            && sections.values.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}
