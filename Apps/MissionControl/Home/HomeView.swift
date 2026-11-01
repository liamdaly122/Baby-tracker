import MissionCore
import MissionUI
import SwiftData
import SwiftUI
import UserNotifications

/// The pre-launch shell: countdown, LAUNCH, and the set-up labour mode needs. The full T-minus
/// dashboard, briefings and checklists arrive in Phase 6.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Query private var places: [BirthPlace]
    @Query private var crew: [CrewContact]

    /// Which keys the launch card shows this week. LAUNCH is the same at every week.
    private var window: LaunchWindow {
        LaunchWindow(
            gestationalAgeDays: model.profile.pregnancyCalendar?.gestationalAgeDays(at: Date(), in: .current))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    StorageNotices()
                    if let outcome = model.outcome {
                        // After it has ended: no countdown, no LAUNCH, no practice run.
                        OutcomeHome(record: outcome)
                        if outcome.outcome != .loss {
                            setUpLinks
                        }
                    } else {
                        countdown
                        LaunchWell(window: window) { model.launch() }
                        setUpLinks
                    }
                }
                .padding(16)
            }
            .navigationTitle(model.outcome == nil ? "Mission Control" : "")
        }
    }

    private var countdown: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let calendar = model.profile.pregnancyCalendar {
                let today = CalendarDay(Date(), in: .current)
                let days = calendar.daysToDueDate(from: today)
                Text(
                    days >= 0
                        ? "T-minus \(days) \(days == 1 ? "day" : "days")"
                        : "T-plus \(-days) \(days == -1 ? "day" : "days")"
                )
                .font(.largeTitle.bold().monospacedDigit())
                Text("\(calendar.gestationalAge(on: today).description) weeks")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                Text("Set T-0")
                    .font(.largeTitle.bold())
                Text("Add the due date in Mission profile to start the countdown.")
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var setUpLinks: some View {
        VStack(spacing: 0) {
            NavigationLink {
                MissionProfileForm()
            } label: {
                SetUpRow(
                    title: "Mission profile", detail: "Due date and her details for the call",
                    icon: "person.text.rectangle")
            }
            Divider()
            NavigationLink {
                BirthPlacesView()
            } label: {
                SetUpRow(
                    title: "Hospital or birth centre", detail: placeDetail, icon: "building.2",
                    isWarning: placeNeedsWork)
            }
            Divider()
            NavigationLink {
                CrewView()
            } label: {
                SetUpRow(
                    title: "People to call",
                    detail: crew.isEmpty ? "Driver, childcare, family" : "\(crew.count) on the list",
                    icon: "person.2")
            }
            Divider()
            NavigationLink {
                BirthPlanEditor()
            } label: {
                SetUpRow(title: "Birth plan", detail: planDetail, icon: "doc.text", isWarning: planNeedsHer)
            }
            Divider()
            NavigationLink {
                ThresholdEditor()
            } label: {
                SetUpRow(
                    title: "When to call", detail: "NHS defaults, or your midwife's advice", icon: "slider.horizontal.3"
                )
            }
            Divider()
            AlertsRow()
            if model.outcome == nil {
                Divider()
                NavigationLink {
                    SomethingHappenedView()
                } label: {
                    SetUpRow(
                        title: "Something's happened", detail: "The baby's arrived, or things haven't gone to plan",
                        icon: "heart")
                }
            }
            if window.drillInHangar, model.outcome == nil {
                Divider()
                NavigationLink {
                    DrillHangarView()
                } label: {
                    SetUpRow(
                        title: "Practice run", detail: "Rehearse the timer and the call, about 5 minutes",
                        icon: "airplane.departure")
                }
            }
        }
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    /// She hasn't read the plan, or it has changed since she did.
    private var planNeedsHer: Bool {
        let plan = model.birthPlan
        guard !plan.content.isEmpty else { return false }
        return !(plan.changesSinceConfirmed(in: model.planning.mainContext)?.isEmpty ?? false)
    }

    private var planDetail: String {
        let plan = model.birthPlan
        if plan.content.isEmpty {
            return "Write it together: the five things that matter most"
        }
        guard let confirmed = plan.herConfirmedAt else { return "Not checked with her yet" }
        let date = confirmed.formatted(date: .abbreviated, time: .omitted)
        return planNeedsHer ? "Changed since she checked it" : "Checked with her \(date)"
    }

    private var bookedPlace: BirthPlace? {
        places.first { $0.role == .booked && !$0.isBlank }
    }

    /// No triage number yet, or numbers that haven't been checked against her notes.
    private var placeNeedsWork: Bool {
        guard let place = bookedPlace, !place.triagePhone.isEmpty else { return true }
        return place.numbersNeedChecking(calendar: model.profile.pregnancyCalendar, now: Date())
    }

    private var placeDetail: String {
        guard let place = bookedPlace else { return "Add where she's booked, and the triage number" }
        if place.triagePhone.isEmpty {
            return "Add the triage number from her notes"
        }
        if place.numbersNeedChecking(calendar: model.profile.pregnancyCalendar, now: Date()) {
            return place.numbersCheckedAt == nil
                ? "Check the numbers against her notes" : "34 weeks: check the numbers again"
        }
        return place.name.isEmpty ? place.kind.title : place.name
    }
}

/// Asks for notification permission before labour, so the first "time to call" alert isn't
/// stuck behind a permission prompt.
private struct AlertsRow: View {
    @Environment(AppModel.self) private var model
    @State private var status: UNAuthorizationStatus?

    var body: some View {
        Button {
            Task {
                await model.notifier.requestAuthorization()
                status = await model.notifier.authorizationStatus()
            }
        } label: {
            SetUpRow(title: "Labour alerts", detail: detail, icon: "bell.badge")
        }
        .buttonStyle(.plain)
        .disabled(status == .authorized || status == .denied)
        .task { status = await model.notifier.authorizationStatus() }
    }

    private var detail: String {
        switch status {
        case .authorized, .provisional, .ephemeral: "On. They break through Sleep and other Focus modes."
        case .denied: "Off. Turn them on in Settings, Notifications, Mission Control."
        default: "Allow them now, so they work the moment labour starts"
        }
    }
}

private struct SetUpRow: View {
    var title: String
    var detail: String
    var icon: String
    var isWarning = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(isWarning ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

/// The training hangar, from 37 weeks: the drill, away from the launch card, behind the question
/// that sends a real labour to LAUNCH instead.
struct DrillHangarView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SimCard(label: "Training hangar", title: "Practice run") {
                    Text(
                        "A pretend labour at 39 weeks: time two contractions, skip ahead to the call point, handle a "
                            + "curveball and rehearse the call. Nothing is saved, nothing dials and no alerts are sent."
                    )
                    .font(MissionType.body(15))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                }
                DrillStartQuestion()
            }
            .padding(16)
        }
        .navigationTitle("Training hangar")
        .navigationBarTitleDisplayMode(.inline)
    }
}
