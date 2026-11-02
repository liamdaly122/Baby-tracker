import MissionCore
import MissionUI
import SwiftUI
import Testing

@testable import MissionControl

/// Picture tests for the home screen (redesign rule 9): the launch site in each sky, the countdown
/// over it, the set-up on paper and the dock, at the smallest, normal and largest text sizes, and
/// three moments of the lift-off.
@MainActor
@Suite("Home pictures")
struct HomeSnapshotTests {
    private static func check(
        _ view: some View, named name: String, background: Color = LabourTheme.cream, inset: CGFloat = 16
    ) {
        for (sizeName, size) in SnapshotTests.sizes {
            Snapshot.check(
                Snapshot.image(
                    view, width: 390, size: size, mode: .live, background: background, colorScheme: .light,
                    inset: inset),
                named: "home-\(name)-\(sizeName)")
        }
    }

    private static func picture(_ view: some View, width: CGFloat = 390, height: CGFloat) -> UIImage? {
        MissionType.registerFonts()
        let renderer = ImageRenderer(content: view.frame(width: width, height: height))
        renderer.scale = 1
        return Snapshot.draw(renderer)
    }

    @Test("The launch site in each of its skies")
    func skies() {
        for palette in SkyPalette.allCases {
            Snapshot.check(
                Self.picture(LaunchSiteScene(palette: palette), height: 470), named: "home-site-\(palette)")
        }
    }

    @Test("The countdown over the launch site, at 38+4")
    func header() throws {
        let today = try #require(CalendarDay(year: 2026, month: 11, day: 2))
        let calendar = PregnancyCalendar(dueDate: today.adding(days: 10))
        Self.check(
            LaunchSiteHeader(calendar: calendar, today: today), named: "header", background: LabourTheme.space, inset: 0
        )
    }

    @Test("Ground control's rows on paper")
    func setUp() {
        Self.check(
            PaperSection("Ground control", note: "What labour mode needs from you, ready before the day.") {
                VStack(spacing: 0) {
                    SetUpRow(
                        title: "Mission profile", detail: "Due date and her details for the call",
                        icon: "person.text.rectangle", isFirst: true)
                    SetUpRow(
                        title: "Hospital or birth centre", detail: "Check the numbers against her notes",
                        icon: "building.2", isWarning: true)
                    SetUpRow(title: "People to call", detail: "3 on the list", icon: "person.2")
                }
            }
            .foregroundStyle(LabourTheme.paperInk),
            named: "ground-control")
    }

    @Test("The dock: When to call, and LAUNCH under its cover and with it lifted")
    func dock() {
        Self.check(
            LaunchWell(window: .term, compact: true, onLaunch: {}, leading: { WhenToCallKey() }), named: "dock-closed")
        Self.check(
            LaunchWell(window: .term, startsOpen: true, compact: true, onLaunch: {}, leading: { WhenToCallKey() }),
            named: "dock-open")
    }

    @Test("The lift-off: the count, lift-off, and labour mode")
    func liftOff() {
        for time in [0.7, 2.6, 3.9] {
            let frame = Canvas { context, size in
                LiftOffView.drawFrame(in: &context, size: size, time: time)
            }
            Snapshot.check(
                Self.picture(frame, height: 844), named: "home-liftoff-\(Int(time * 10))")
        }
    }
}
