import Foundation
import MissionCore
import SwiftData

/// The pregnancy and hospital details. Lives in the planning store, which never holds labour data.
@Model
final class MissionProfile {
    var dueDateText: String = ""
    var regionRaw: String = ContentRegion.uk.rawValue
    var parity: Int = 0
    var previousFastLabour: Bool = false
    var travelMinutes: Int?
    var motherName: String = ""
    var hospitalNumber: String = ""
    var notes: String = ""
    var unitName: String = ""
    var triagePhone: String = ""
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

    /// What the engine needs, worked out at `date` (gestational age moves on during a long labour).
    func labourProfile(at date: Date, calendar: Calendar = .current) -> LabourProfile {
        LabourProfile(
            region: region,
            parity: parity,
            previousFastLabour: previousFastLabour,
            gestationalAgeDays: pregnancyCalendar?.gestationalAgeDays(at: date, in: calendar),
            travelMinutes: travelMinutes
        )
    }

    func triageDetails(at date: Date, calendar: Calendar = .current) -> TriageDetails {
        TriageDetails(
            motherName: motherName,
            hospitalNumber: hospitalNumber,
            gestationalAge: pregnancyCalendar?.gestationalAge(on: CalendarDay(date, in: calendar)),
            parity: parity,
            previousFastLabour: previousFastLabour,
            travelMinutes: travelMinutes,
            notes: notes
        )
    }

    /// "your maternity unit" until the user names it.
    var unitDisplayName: String {
        unitName.isEmpty ? "your maternity unit" : unitName
    }

    var triageURL: URL? {
        let digits = triagePhone.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
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
