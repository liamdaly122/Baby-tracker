import Foundation
import MissionCore
import SwiftData

/// Where she's booked to give birth, or the backup: another unit, or where a midwife-led unit
/// transfers to if she needs a doctor. Lives in the planning store. The numbers are typed from her
/// maternity notes and stamped when he checks them, because a wrong or out-of-date triage number
/// is found out at the worst moment.
@Model
final class BirthPlace {
    @Attribute(.unique) var id = UUID()
    var roleRaw: String = BirthPlaceRole.booked.rawValue
    var kindRaw: String = BirthPlaceKind.labourWard.rawValue
    var name: String = ""
    var triagePhone: String = ""
    var labourWardPhone: String = ""
    var address: String = ""
    /// The journey at the worst time of day, not a live estimate, so the advice doesn't change with traffic.
    var travelMinutes: Int?
    var parkingNotes: String = ""
    var afterHoursEntrance: String = ""
    var partnerCanStayOvernight: Bool = false
    /// When he last checked the numbers against her notes.
    var numbersCheckedAt: Date?

    init(role: BirthPlaceRole) {
        roleRaw = role.rawValue
    }
}

enum BirthPlaceRole: String, CaseIterable {
    case booked
    case backup
}

/// The kinds of place the NHS offers for a hospital or birth centre birth. A home birth needs its
/// own advice and copy (who to ring, no journey), so it comes later.
enum BirthPlaceKind: String, CaseIterable, Identifiable {
    case labourWard
    case alongsideUnit
    case freestandingUnit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .labourWard: "Hospital labour ward"
        case .alongsideUnit: "Midwife-led unit at a hospital"
        case .freestandingUnit: "Birth centre on its own"
        }
    }

    /// A birth centre on its own has no doctors on site, so it matters where it transfers to.
    var needsTransferUnit: Bool { self == .freestandingUnit }
}

extension BirthPlace {
    var role: BirthPlaceRole {
        get { BirthPlaceRole(rawValue: roleRaw) ?? .booked }
        set { roleRaw = newValue.rawValue }
    }

    var kind: BirthPlaceKind {
        get { BirthPlaceKind(rawValue: kindRaw) ?? .labourWard }
        set { kindRaw = newValue.rawValue }
    }

    /// "your maternity unit" until it's named.
    var displayName: String {
        name.isEmpty ? "your maternity unit" : name
    }

    /// The triage line, checked against the region's rules every time it's read.
    func triageCheck(region: ContentRegion) -> Result<PhoneNumber, PhoneNumber.Problem>? {
        Self.check(triagePhone, region: region)
    }

    func labourWardCheck(region: ContentRegion) -> Result<PhoneNumber, PhoneNumber.Problem>? {
        Self.check(labourWardPhone, region: region)
    }

    func triageNumber(region: ContentRegion) -> PhoneNumber? { try? triageCheck(region: region)?.get() }

    func labourWardNumber(region: ContentRegion) -> PhoneNumber? { try? labourWardCheck(region: region)?.get() }

    /// Apple Maps directions to the address, if there is one.
    var directionsURL: URL? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "daddr", value: trimmed)]
        return components?.url
    }

    /// The numbers should be checked against her notes once, and again from 34 weeks, because units
    /// do change them. True if they've never been checked, or were last checked before 34+0 and she
    /// is now 34 weeks or more.
    func numbersNeedChecking(calendar: PregnancyCalendar?, now: Date, in timeZone: Calendar = .current) -> Bool {
        guard let checked = numbersCheckedAt else { return true }
        guard let calendar else { return false }
        let recheckFrom = Self.recheckFromDays
        guard calendar.gestationalAgeDays(at: now, in: timeZone) >= recheckFrom else { return false }
        return calendar.gestationalAgeDays(at: checked, in: timeZone) < recheckFrom
    }

    /// 34+0.
    static let recheckFromDays = 238

    private static func check(_ text: String, region: ContentRegion) -> Result<PhoneNumber, PhoneNumber.Problem>? {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : PhoneNumber.parse(text, region: region)
    }
}

/// Someone to ring once the unit knows what's happening: a backup birth partner, a driver, whoever
/// has the children or the dog, family. The unit always comes first; these are on the Call tab
/// below it. Name and number are copied in (from Contacts or typed), so nothing else of theirs is kept.
@Model
final class CrewContact {
    @Attribute(.unique) var id = UUID()
    var name: String = ""
    var roleRaw: String = CrewRole.family.rawValue
    var phone: String = ""
    var note: String = ""
    var sortOrder: Int = 0

    init(name: String = "", phone: String = "", role: CrewRole = .family, sortOrder: Int = 0) {
        self.name = name
        self.phone = phone
        roleRaw = role.rawValue
        self.sortOrder = sortOrder
    }
}

enum CrewRole: String, CaseIterable, Identifiable {
    case backupPartner
    case driver
    case children
    case pets
    case family
    case friend
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .backupPartner: "Backup birth partner"
        case .driver: "Driver"
        case .children: "Has the children"
        case .pets: "Has the pets"
        case .family: "Family"
        case .friend: "Friend"
        case .other: "Other"
        }
    }
}

extension CrewContact {
    var role: CrewRole {
        get { CrewRole(rawValue: roleRaw) ?? .other }
        set { roleRaw = newValue.rawValue }
    }

    func phoneCheck(region: ContentRegion) -> Result<PhoneNumber, PhoneNumber.Problem>? {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        // A friend abroad is fine here, unlike the unit's numbers.
        return trimmed.isEmpty ? nil : PhoneNumber.parse(trimmed, region: region, allowOverseas: true)
    }

    /// A text message link, for "on our way" without a call.
    func textURL(region: ContentRegion) -> URL? {
        guard case .success(let number) = phoneCheck(region: region), !number.isShortCode else { return nil }
        return URL(string: "sms:\(number.dialable)")
    }
}
