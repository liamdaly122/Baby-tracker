import Foundation
import MissionContent
import MissionCore
import Testing

@Suite("UK content v1")
struct UKContentTests {
    let library: ContentLibrary

    init() throws {
        library = try BundledContent.library(for: .uk)
    }

    @Test("Loads with no broken references")
    func noProblems() {
        let problems = ContentLoader.problems(in: library)
        #expect(problems.isEmpty, "\(problems.map(\.description))")
    }

    @Test("Ships the planned amount of content")
    func counts() {
        #expect(library.checklist.count >= 120)
        #expect(library.glossary.count >= 54)
        #expect(library.coaching.count >= 12)
        #expect(library.briefings.count >= 10)
        #expect(library.quiz.count >= 20)
        #expect(library.badges.count >= 20)
        #expect(Set(library.versions.keys) == Set(ContentKind.allCases))
    }

    @Test("Every checklist module has items", arguments: ChecklistModule.allCases)
    func moduleHasItems(module: ChecklistModule) {
        #expect(!library.checklist(in: module).isEmpty)
    }

    @Test("Every module gets a mission patch", arguments: ChecklistModule.allCases)
    func moduleHasPatch(module: ChecklistModule) {
        #expect(library.badges.contains { $0.rule.kind == .moduleComplete && $0.rule.targetIDs == [module.rawValue] })
    }

    @Test("Paternity notice is due at the end of the qualifying week, with reminders")
    func paternityNotice() throws {
        let item = try #require(library.checklistItem(id: "admin.paternity-notice"))
        #expect(item.deadline == Deadline(anchor: .ewc, offsetDays: -99))
        #expect(!item.reminderDaysBefore.isEmpty)
        // Acas worked example: due 1 May 2026 → notice by Saturday 17 January 2026.
        let calendar = PregnancyCalendar(dueDate: try #require(CalendarDay(year: 2026, month: 5, day: 1)))
        #expect(calendar.day(for: try #require(item.deadline)) == CalendarDay(year: 2026, month: 1, day: 17))
    }

    @Test("Registering the birth is due 42 days after it")
    func registration() throws {
        let item = try #require(library.checklistItem(id: "splashdown.register"))
        #expect(item.deadline == Deadline(anchor: .birth, offsetDays: 42))
    }

    @Test("Every skills quiz has at least 3 questions")
    func quizzes() {
        for quizID in library.quizIDs {
            #expect(library.questions(forQuiz: quizID).count >= 3, "\(quizID)")
        }
    }

    @Test("Quiz answers aren't always in the same position")
    func answerPositions() {
        #expect(Set(library.quiz.map(\.correctIndex)).count > 1)
    }

    @Test("Weekly beats follow the weeks; launch and splashdown play on events")
    func storyBeats() throws {
        #expect(library.briefing(forWeek: 3) == nil)
        #expect(library.briefing(forWeek: 4)?.id == "briefing.w04-drafted")
        #expect(library.briefing(forWeek: 26)?.id == "briefing.w25-deadline")
        #expect(library.briefing(forWeek: 41)?.act == .holdAtTMinus)
        let launch = try #require(library.briefing(for: .launch))
        #expect(launch.speaker == .flightSurgeon)
        #expect(library.briefing(for: .splashdown) != nil)
    }

    @Test("The Flight Surgeon never has humour variants")
    func flightSurgeonPlain() {
        for briefing in library.briefings where briefing.speaker == .flightSurgeon {
            #expect(briefing.title.mild == nil && briefing.title.full == nil, "\(briefing.id)")
            #expect(briefing.body.mild == nil && briefing.body.full == nil, "\(briefing.id)")
        }
    }

    @Test("Labour mode strips humour from every bundled line")
    func labourModeStripsHumour() {
        let resolver = HumourResolver(preferred: .full, isLabourMode: true)
        for item in library.checklist {
            #expect(resolver.title(of: item) == item.title.off)
        }
        for briefing in library.briefings {
            #expect(resolver.body(of: briefing) == briefing.body.off)
        }
    }

    @Test("Every clinical item carries provenance with an https source")
    func provenance() {
        for item in library.checklist where item.clinicalText != nil {
            #expect(item.provenance?.clinical == true, "\(item.id)")
        }
        let sources =
            library.glossary.map(\.provenance) + library.coaching.compactMap(\.provenance)
            + library.checklist.compactMap(\.provenance) + library.quiz.compactMap(\.provenance)
        for source in sources {
            #expect(source.sourceURL.scheme == "https")
        }
    }

    @Test("No bundled copy says what stage of labour she's in")
    func noDiagnosticCopy() throws {
        let forbidden = ["you are in labour", "you're in labour", "diagnos"]
        let data = try ContentKind.allCases.map { try BundledContent.data(for: $0, region: .uk) }
        for file in data {
            let text = try #require(String(bytes: file, encoding: .utf8)).lowercased()
            for phrase in forbidden {
                #expect(!text.contains(phrase), "\(phrase)")
            }
        }
    }

    @Test("The jargon decoder finds what midwives actually say")
    func glossarySearch() {
        let index = GlossaryIndex(entries: library.glossary)
        let expectations = [
            "the drip": "syntocinon",
            "CTG": "ctg",
            "fully": "fully",
            "she's 6": "dilat",
            "SROM": "srom",
            "decels": "decel",
            "the reg": "review",
            "back to back": "back-to-back",
        ]
        for (query, fragment) in expectations {
            let top = index.search(query).first?.id ?? "nothing"
            #expect(top.contains(fragment), "\(query) → \(top)")
        }
    }

    @Test("US ships thresholds only for now")
    func usContent() throws {
        let us = try BundledContent.library(for: .us)
        #expect(us.checklist.isEmpty)
        #expect(us.thresholds.defaults.adviceDurationSec == 60)
    }
}
