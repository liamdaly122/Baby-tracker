import MissionCore
import MissionUI
import SwiftUI
import Testing

@testable import MissionControl

/// Picture tests for launch, the practice run and the end of labour (redesign rule 9), at the
/// smallest, normal and largest text sizes. Launch and the drill question sit on the home screen,
/// before labour mode, so they're drawn once; the end of labour is live only, as a practice run
/// has its own ending.
@MainActor
@Suite("Launch, practice and ending pictures")
struct LaunchSnapshotTests {
    private static func check(
        _ view: some View, named name: String, background: Color, colorScheme: ColorScheme = .dark
    ) {
        for (sizeName, size) in SnapshotTests.sizes {
            Snapshot.check(
                Snapshot.image(view, size: size, mode: .live, background: background, colorScheme: colorScheme),
                named: "\(name)-\(sizeName)")
        }
    }

    @Test("LAUNCH under its cover, and with the cover lifted")
    func launch() {
        let home = Color(red: 0.95, green: 0.95, blue: 0.97)
        // The home screen is light until its own redesign.
        Self.check(LaunchWell(window: .drill) {}, named: "launch-closed", background: home, colorScheme: .light)
        Self.check(
            LaunchWell(window: .drill, startsOpen: true) {}, named: "launch-open", background: home, colorScheme: .light
        )
        Self.check(DrillStartCard(onYes: {}, onNo: {}), named: "drill-question", background: home, colorScheme: .light)
    }

    @Test("The end of labour: the choice, and the dawn when everyone is well")
    func ending() {
        Self.check(
            VStack(alignment: .leading, spacing: 12) {
                EndHeading(eyebrow: "End labour mode", title: "How is labour mode ending?")
                EndChoice(title: "Labour has ended", detail: "The baby's here, or something has happened") {}
                EndChoice(title: "Not in labour after all", detail: "Back home. Nothing is kept running") {}
            },
            named: "end-choice", background: LabourTheme.space)
        let renderer = ImageRenderer(content: DawnScene().frame(width: 390))
        renderer.scale = 1
        Snapshot.check(renderer.uiImage, named: "end-dawn")
    }
}
