import Foundation
import MissionCore

/// Launch arguments for testing in the simulator. They do nothing in release builds.
///   -inMemoryStores   start with empty stores that vanish on quit
///   -demoProfile      fill in a profile and birth plan, due in 10 days (38+4)
///   -demoPreterm      the same, due in 40 days (34+2): the drill key sits under LAUNCH
///   -demoLabour       start labour mode with an hour of contractions every 4 minutes
///   -demoDrill        open straight into a practice run
enum LaunchOptions {
    static var inMemory: Bool {
        #if DEBUG
            ProcessInfo.processInfo.arguments.contains("-inMemoryStores")
        #else
            false
        #endif
    }

    @MainActor
    static func applyDemoData(to model: AppModel) {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-demoProfile") || arguments.contains("-demoLabour")
                || arguments.contains("-demoPreterm")
            {
                fillProfile(model, dueInDays: arguments.contains("-demoPreterm") ? 40 : 10)
            }
            if arguments.contains("-demoDrill") {
                model.startDrill()
            }
            if arguments.contains("-demoLabour"), !model.session.isActive {
                let launched = Date().addingTimeInterval(-3700)
                model.session.start(
                    model.brief.sessionStart(at: launched, by: model.session.deviceID, calendar: .current))
                model.session.insertDemoHistory(count: 15, every: 240, lasting: 50)
            }
        #endif
    }

    #if DEBUG
        @MainActor
        private static func fillProfile(_ model: AppModel, dueInDays: Int) {
            let profile = model.profile
            if profile.dueDate == nil {
                profile.dueDate = CalendarDay(Date(), in: .current).adding(days: dueInDays)
            }
            if profile.motherName.isEmpty {
                profile.motherName = "Sam"
                profile.hospitalNumber = "LTH1234567"
                profile.notes = "GBS positive"
                // Ofcom's drama numbers: they ring nobody.
                profile.unitName = "Northgate General Maternity Assessment Centre"
                profile.triagePhone = "01632 960118 option 2"
                profile.labourWardPhone = "01632 960245"
                profile.travelMinutes = 25
                profile.parkingNotes = "Multi-storey on Great George Street, pay by card"
                profile.afterHoursEntrance = "Clarendon Wing, use the intercom"
                profile.partnerCanStayOvernight = true
            }
            let plan = model.birthPlan
            if plan.isEmpty {
                plan.headlines = [
                    "Gas and air first, epidural if she asks",
                    "Wait at least a minute before clamping the cord",
                    "Skin-to-skin straight away",
                    "Dad would like to cut the cord",
                    "Please explain any intervention to both of us",
                ]
                plan.sections = [
                    .place: "Midwife-led unit next to the labour ward",
                    .feeding: "Breastfeeding, with help on day one",
                    .photos: "No photos of her without asking",
                ]
            }
            model.savePlanning()
        }
    #endif
}

#if DEBUG
    extension LabourSessionModel {
        /// Back-dated taps for demos: `count` contractions ending just before now.
        func insertDemoHistory(count: Int, every: TimeInterval, lasting: TimeInterval) {
            let firstStart = Date().addingTimeInterval(-Double(count) * every)
            for index in 0..<count {
                recordDemoContraction(start: firstStart.addingTimeInterval(Double(index) * every), lasting: lasting)
            }
            refresh()
        }
    }
#endif
