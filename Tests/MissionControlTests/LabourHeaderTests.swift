import Foundation
import MissionCore
import MissionUI
import SwiftUI
import Testing

@testable import MissionControl

/// 999 is one tap away on every labour screen (hazard HZ-03). `LabourHeader` sits above whichever
/// tab is showing, and every layout of its top row carries the 999 key, so these pictures guard
/// the one place it lives: live and in practice, at the smallest, normal and largest text sizes.
@MainActor
@Suite("999 on every labour screen")
struct LabourHeaderTests {
    @Test("The 999 key dials 999")
    func dials999() {
        #expect(EmergencyDial.url(.uk)?.absoluteString == "tel:999")
    }

    @Test("The top row, with 999, above every tab, live and in practice")
    func topRow() {
        let model = AppModel(inMemory: true)
        model.session.start(labourStart(at: Date()))
        defer { model.session.end() }
        for mode in MissionModeOption.allCases {
            for (sizeName, size) in SnapshotTests.sizes {
                Snapshot.check(
                    Snapshot.image(
                        LabourHeader(showsStatus: false) {}.environment(model), size: size, mode: mode,
                        background: LabourTheme.space, inset: 0),
                    named: "labour-header-\(mode.rawValue)-\(sizeName)")
            }
        }
    }
}
