import Foundation
import MissionCore

/// A backup copy of what labour mode needs (the hospital, its numbers, her name and due date), kept
/// in a small file of its own. It's the same brief the watch gets. If the planning store can't be
/// opened, labour mode starts from this instead of a blank profile, so the Call tab still rings the
/// right unit.
enum EmergencyCard {
    static func write(_ brief: MissionBrief, to url: URL) {
        do {
            let data = try JSONEncoder().encode(brief)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            Stores.log.error("Couldn't save the emergency card: \(error)")
        }
    }

    static func read(from url: URL) -> MissionBrief? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(MissionBrief.self, from: data)
        } catch {
            Stores.log.error("Couldn't read the emergency card: \(error)")
            return nil
        }
    }
}

extension MissionProfile {
    /// Fills a blank profile from the emergency card. Thresholds that differ from `defaults` become
    /// overrides again, so a midwife's rule carries over.
    func restore(from card: MissionBrief, defaults: ThresholdProfile) {
        region = card.region
        dueDateText = card.dueDateText ?? ""
        parity = card.parity
        previousFastLabour = card.previousFastLabour
        travelMinutes = card.travelMinutes
        motherName = card.motherName
        unitName = card.unitName
        triagePhone = card.triage?.raw ?? ""
        labourWardPhone = card.labourWard?.raw ?? ""
        gbsPositive = card.gbsPositive
        plannedCaesarean = card.plannedCaesarean
        var overrides: [ThresholdField: Double] = [:]
        for field in ThresholdField.allCases where card.thresholds[field] != defaults[field] {
            overrides[field] = card.thresholds[field]
        }
        thresholdOverrides = overrides
    }
}
