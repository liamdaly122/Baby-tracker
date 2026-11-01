import MissionCore
import MissionUI
import SwiftUI
import Testing

/// Picture tests for the redesigned Call tab (redesign rule 9): its header, the unit and 999
/// plates, the "If nobody answers" ladder, the notepad script and a person's row, live and in
/// practice, at the smallest, normal and largest labour text sizes.
@MainActor
@Suite("Call tab pictures")
struct CallSnapshotTests {
    static let triage = (try? PhoneNumber.parse("01632 960118 option 2", region: .uk).get())
    static let ward = (try? PhoneNumber.parse("01632 960245", region: .uk).get())
    static let person = (try? PhoneNumber.parse("07700 900123", region: .uk).get())

    private static func check(_ view: some View, named name: String) {
        for mode in MissionModeOption.allCases {
            for (sizeName, size) in SnapshotTests.sizes {
                Snapshot.check(
                    Snapshot.image(view, size: size, mode: mode, background: LabourPalette.callTop.color),
                    named: "call-\(name)-\(mode.rawValue)-\(sizeName)")
            }
        }
    }

    @Test("The header, the unit's plate and 999's plate")
    func plates() throws {
        let triage = try #require(Self.triage)
        Self.check(
            LabourTabHeader(
                world: .call, eyebrow: "Comms", title: "Who to ring", subtitle: "In this order. Every button dials."),
            named: "header")
        Self.check(
            CallPlate(label: "Hospital labour ward", title: "Northgate General") {
                BigDial(number: triage, title: "Call triage", detail: "01632 960118 · then press 2")
                NumberRow(number: triage)
                PlateNote("Checked against her notes in week 34. Have her notes ready when they answer.")
            },
            named: "unit")
        let emergency = try #require(PhoneNumber.shortCode("999"))
        Self.check(
            CallPlate(isEmergency: true, label: "Emergency") {
                BigDial(number: emergency, title: "Call 999", detail: nil)
            },
            named: "999")
    }

    @Test("If nobody answers, and the script")
    func ladderAndScript() {
        Self.check(
            FallbackLadder(steps: CallFallback.steps(region: .uk, unit: Self.triage, labourWard: Self.ward)),
            named: "ladder")
        Self.check(
            NotepadCard(
                opening: "Hi, I'm calling about Sam. She's 40+2 weeks, first baby.",
                lines: [
                    TriageScript.Line(label: "Waters", value: "Broke at 14:10, clear", isUrgent: true),
                    TriageScript.Line(label: "Contractions", value: "Every 4 min, lasting 50 sec", isUrgent: false),
                    TriageScript.Line(label: "Notes", value: "GBS positive", isUrgent: false),
                ]),
            named: "notepad")
    }

    @Test("A person to ring, after the unit")
    func person() throws {
        let number = try #require(Self.person)
        Self.check(
            CommsSection("People · after the unit") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Linda, Sam's mum").font(MissionType.body(15).weight(.bold))
                        Text("DRIVER").font(MissionType.mono()).foregroundStyle(LabourTheme.muted)
                    }
                    .foregroundStyle(LabourTheme.cream)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    SmallDial(number: number, title: "Call", accessibilityName: "Linda")
                }
            },
            named: "person")
    }
}
