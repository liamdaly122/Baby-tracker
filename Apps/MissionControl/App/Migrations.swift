import Foundation
import MissionCore
import SwiftData

/// One-off fixes to saved data when the rules change.
enum Migrations {
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
