import Foundation
import MissionCore
import SwiftData

/// One-off fixes to saved data when the rules change.
enum Migrations {
    /// Review action 16: the hospital moves from flat fields on the profile into a `BirthPlace`
    /// (where she's booked). Runs whenever those fields hold anything, so it also catches a profile
    /// filled the old way. If a booked place already exists, its own values win and only blanks
    /// are filled in.
    @MainActor
    static func moveHospital(from profile: MissionProfile, in context: ModelContext) {
        guard profile.hasLegacyHospital else { return }
        let existing = try? context.fetch(FetchDescriptor<BirthPlace>()).first { $0.role == .booked }
        let place = existing ?? BirthPlace(role: .booked)
        if existing == nil {
            context.insert(place)
        }
        func fill(_ value: inout String, from legacy: String) {
            if value.isEmpty { value = legacy }
        }
        fill(&place.name, from: profile.unitName)
        fill(&place.triagePhone, from: profile.triagePhone)
        fill(&place.labourWardPhone, from: profile.labourWardPhone)
        fill(&place.parkingNotes, from: profile.parkingNotes)
        fill(&place.afterHoursEntrance, from: profile.afterHoursEntrance)
        place.travelMinutes = place.travelMinutes ?? profile.travelMinutes
        place.partnerCanStayOvernight = place.partnerCanStayOvernight || profile.partnerCanStayOvernight
        profile.unitName = ""
        profile.triagePhone = ""
        profile.labourWardPhone = ""
        profile.parkingNotes = ""
        profile.afterHoursEntrance = ""
        profile.travelMinutes = nil
        profile.partnerCanStayOvernight = false
        try? context.save()
    }

    static let ukHoldKey = "migrations.b14.ukHold"

    /// Plan amendment B14: the UK hold before "Time to call" is now off by default, because the NHS
    /// gives no time. Before, it was always an hour and couldn't be switched off, so a saved hour
    /// was never a choice: drop it from the overrides and from an unfinished labour. A hold set
    /// from now on is deliberate (a midwife's advice) and is left alone. Runs once.
    @MainActor
    static func run(profile: MissionProfile, labour: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: ukHoldKey) else { return }
        defaults.set(true, forKey: ukHoldKey)
        guard profile.region == .uk else { return }
        let oldHold: Double = 3600
        var overrides = profile.thresholdOverrides
        let chosen = overrides[.patternWindowSec]
        if chosen == oldHold {
            overrides[.patternWindowSec] = nil
            profile.thresholdOverrides = overrides
        }
        // A shorter hold was a real choice; only the old automatic hour is undone.
        guard chosen == nil || chosen == oldHold else { return }
        let sessions =
            (try? labour.fetch(FetchDescriptor<LabourSessionRecord>(predicate: #Predicate { $0.endedAt == nil }))) ?? []
        for session in sessions where session.region == .uk {
            if var thresholds = session.thresholds, thresholds.patternWindowSec == oldHold {
                thresholds.patternWindowSec = 0
                session.thresholds = thresholds
            }
            if var start = session.start, start.thresholds.patternWindowSec == oldHold {
                start.thresholds.patternWindowSec = 0
                session.start = start
            }
        }
        try? labour.save()
    }
}
