import MissionCore
import MissionUI
import SwiftUI
import Testing

@testable import MissionControl

/// Picture tests for the set-up screens' paper pieces (redesign rule 9): on paper from the home
/// screen, and in the night colours when Labour settings opens them inside labour mode, at the
/// smallest, normal and largest text sizes.
@MainActor
@Suite("Set-up pictures")
struct SetupSnapshotTests {
    private static func check(_ view: some View, named name: String) {
        for scheme in [ColorScheme.light, .dark] {
            let colours = PaperColors.for(scheme)
            for (sizeName, size) in SnapshotTests.sizes {
                Snapshot.check(
                    Snapshot.image(
                        view.foregroundStyle(colours.ink), size: size, mode: .live, background: colours.page,
                        colorScheme: scheme),
                    named: "setup-\(name)-\(scheme == .light ? "paper" : "night")-\(sizeName)")
            }
        }
    }

    @Test("A section with fields, a number check, ticks, chips and a stepper")
    func fields() {
        let triage = PhoneNumber.parse("01632 960118 option 2", region: .uk)
        Self.check(
            PaperSection("Numbers", note: "Copy them from her maternity notes, menu options and all.") {
                VStack(alignment: .leading, spacing: 5) {
                    PaperField("Triage or assessment line") { Text("01632 960118 option 2") }
                    NumberCheck(result: triage)
                }
                NumberCheck(result: PhoneNumber.parse("0163", region: .uk))
                PaperTick("I've checked the triage number against her maternity notes", isOn: .constant(true))
                PaperTick("A partner can stay overnight", isOn: .constant(false))
                PaperChips(
                    BirthPlaceKind.allCases, title: \.title, isPicked: { $0 == .labourWard }, pick: { _ in })
                PaperStepper("Journey at the busiest time", value: "25 min", decrease: {}, increase: {})
            },
            named: "fields")
    }

    @Test("Your data: where it's kept, what leaves the phone, and Delete everything")
    func yourData() {
        Self.check(
            VStack(alignment: .leading, spacing: 16) {
                PrivacySummary()
                PaperSection("Delete everything", note: DeleteEverything.note) {
                    Button("Delete everything") {}.buttonStyle(PaperButtonStyle(.danger))
                }
            },
            named: "your-data")
    }

    @Test("The hospital's card, buttons and a card")
    func cards() {
        Self.check(
            VStack(alignment: .leading, spacing: 12) {
                PlaceCard(
                    kind: "Hospital labour ward", name: "Northgate General", detail: "1 Northgate Road",
                    facts: [("25 min", "At the busiest time")]
                ) {
                    Text("Change")
                        .foregroundStyle(LabourTheme.paperInk)
                        .padding(.horizontal, 12)
                        .background(Capsule().fill(LabourPalette.paperHi.color))
                }
                Button("Read it through with her") {}.buttonStyle(PaperButtonStyle(.solid))
                Button("Send it to her") {}.buttonStyle(PaperButtonStyle(.ghost))
                Button("Remove the backup") {}.buttonStyle(PaperButtonStyle(.danger))
                PaperCard {
                    PaperLabel("Pain relief")
                    Text("Breathing, TENS, then gas and air").paperBox()
                    PaperNote("Checked with her on 19 Oct".uppercased(), tone: .good)
                    PaperNote("Changed since: Photos and video added.", tone: .warn)
                }
            },
            named: "cards")
    }
}
