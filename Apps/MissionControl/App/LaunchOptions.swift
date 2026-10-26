import Foundation
import MissionCore

/// Launch arguments for testing in the simulator. They do nothing in release builds.
///   -inMemoryStores   start with empty stores that vanish on quit
///   -demoProfile      fill in a profile and birth plan
///   -demoLabour       start labour mode with an hour of contractions every 4 minutes
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
            if arguments.contains("-demoProfile") || arguments.contains("-demoLabour") {
                fillProfile(model)
            }
            if arguments.contains("-demoLabour"), !model.labour.isActive {
                model.labour.start(region: model.profile.region, thresholds: model.currentThresholds)
                model.labour.insertDemoHistory(count: 15, every: 240, lasting: 50)
            }
        #endif
    }

    #if DEBUG
        @MainActor
        private static func fillProfile(_ model: AppModel) {
            let profile = model.profile
            if profile.dueDate == nil {
                profile.dueDate = CalendarDay(Date(), in: .current).adding(days: 10)
            }
            if profile.motherName.isEmpty {
                profile.motherName = "Sam"
                profile.hospitalNumber = "LTH1234567"
                profile.notes = "GBS positive"
                profile.unitName = "LGI Maternity Assessment Centre"
                profile.triagePhone = "0113 000 0000"
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
                let start = firstStart.addingTimeInterval(Double(index) * every)
                recordBackdated(.start, at: start)
                if let open = openContraction {
                    recordBackdated(.stop, at: start.addingTimeInterval(lasting), target: open.id)
                }
            }
            refresh()
        }
    }
#endif
