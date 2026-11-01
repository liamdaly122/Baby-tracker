import Foundation
import MissionCore
import SwiftData

/// How things ended (review action 10): recorded once, from labour mode or from home at any week.
/// Lives in the planning store, so it survives a restored phone; the labour store doesn't.
@Model
final class OutcomeRecord {
    @Attribute(.unique) var id = UUID()
    var outcomeRaw: String = PregnancyOutcome.allWell.rawValue
    /// When the baby was born, if there was a birth. He can change it.
    var birthAt: Date?
    var babyName: String = ""
    var recordedAt = Date.distantPast

    init(outcome: PregnancyOutcome, birthAt: Date?, babyName: String, recordedAt: Date) {
        outcomeRaw = outcome.rawValue
        self.birthAt = birthAt
        self.babyName = babyName
        self.recordedAt = recordedAt
    }

    var outcome: PregnancyOutcome { PregnancyOutcome(rawValue: outcomeRaw) ?? .allWell }
}
