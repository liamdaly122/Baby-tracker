import MissionCore
import MissionUI
import SwiftData
import SwiftUI
import UserNotifications

/// The pre-launch home, in the agreed prototype's look: the launch site with the countdown over it,
/// the set-up labour mode needs on paper beneath, and a dock with "When to call" and LAUNCH. The
/// rocket's stage-by-stage building, the weekly briefing and the checklists arrive in Phase 6.
/// After the birth, or a loss, there's no launch site, no countdown and no LAUNCH.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                VStack(spacing: 0) {
                    if model.outcome == nil {
                        LaunchSiteHeader(
                            calendar: model.profile.pregnancyCalendar, today: CalendarDay(Date(), in: .current))
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        StorageNotices()
                        if let outcome = model.outcome {
                            // After it has ended: no countdown, no LAUNCH, no practice run.
                            OutcomeHome(record: outcome)
                            if outcome.outcome != .loss {
                                setUpLinks
                            }
                        } else {
                            setUpLinks
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        UnevenRoundedRectangle(cornerRadii: .init(topLeading: 28, topTrailing: 28))
                            .fill(LabourTheme.cream)
                    )
                    .padding(.top, model.outcome == nil ? -20 : 0)
                }
            }
            .ignoresSafeArea(edges: model.outcome == nil ? .top : [])
            .background(LabourTheme.cream.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if model.outcome == nil {
                    dock
                }
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            // Light status bar text over the night sky of the launch site.
            .toolbarColorScheme(model.outcome == nil ? .dark : .light, for: .navigationBar)
        }
    }

    /// The prototype's dock: "When to call", and LAUNCH in its well. The lift-off plays from 37
    /// weeks, as in the prototype, unless motion is reduced.
    private var dock: some View {
        let liftOff =
            window == .term && !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
        return LaunchWell(
            window: window, compact: true, onLaunch: { model.launch(liftOff: liftOff) },
            leading: {
                NavigationLink {
                    ThresholdEditor()
                } label: {
                    WhenToCallKey()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("When to call")
            }
        )
        .padding(.horizontal, 14)
        .padding(.top, 22)
        .padding(.bottom, 8)
        .background {
            // The paper fades in over the top padding only, so nothing shows through what opens
            // with the cover.
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [LabourTheme.cream.opacity(0), LabourTheme.cream], startPoint: .top, endPoint: .bottom
                )
                .frame(height: 22)
                LabourTheme.cream
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    /// The set-up labour mode needs, on paper: the prototype's "Ground control".
    private var setUpLinks: some View {
        PaperSection("Ground control", note: "What labour mode needs from you, ready before the day.") {
            VStack(spacing: 0) {
                NavigationLink {
                    MissionProfileForm()
                } label: {
                    SetUpRow(
                        title: "Mission profile", detail: "Due date and her details for the call",
                        icon: "person.text.rectangle", isFirst: true)
                }
                NavigationLink {
                    BirthPlacesView()
                } label: {
                    SetUpRow(
                        title: "Hospital or birth centre", detail: placeDetail, icon: "building.2",
                        isWarning: placeNeedsWork)
                }
                NavigationLink {
                    CrewView()
                } label: {
                    SetUpRow(
                        title: "People to call",
                        detail: crew.isEmpty ? "Driver, childcare, family" : "\(crew.count) on the list",
                        icon: "person.2")
                }
                NavigationLink {
                    BirthPlanEditor()
                } label: {
                    SetUpRow(title: "Birth plan", detail: planDetail, icon: "doc.text", isWarning: planNeedsHer)
                }
                NavigationLink {
                    ThresholdEditor()
                } label: {
                    SetUpRow(
                        title: "When to call", detail: "NHS defaults, or your midwife's advice",
                        icon: "slider.horizontal.3")
                }
                AlertsRow()
                if model.outcome == nil {
                    NavigationLink {
                        SomethingHappenedView()
                    } label: {
                        SetUpRow(
                            title: "Something's happened", detail: "The baby's arrived, or things haven't gone to plan",
                            icon: "heart")
                    }
                }
                if window.drillInHangar, model.outcome == nil {
                    NavigationLink {
                        DrillHangarView()
                    } label: {
                        SetUpRow(
                            title: "Practice run", detail: "Rehearse the timer and the call, about 5 minutes",
                            icon: "airplane.departure")
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(LabourTheme.paperInk)
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

/// The dock's "When to call", beside LAUNCH: the prototype's red-ink key on paper. At the
/// accessibility text sizes it runs the width of the dock, above LAUNCH.
struct WhenToCallKey: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let big = typeSize.isAccessibilitySize
        let layout = big ? AnyLayout(HStackLayout(spacing: 10)) : AnyLayout(VStackLayout(spacing: 4))
        layout {
            Image(systemName: "phone")
                .font(.system(size: 18, weight: .semibold))
            Text(big ? "When to call" : "When to\ncall")
                .font(MissionType.body(13).weight(.bold))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(LabourPalette.redInk.color)
        .padding(.vertical, big ? 10 : 0)
        .frame(maxWidth: big ? .infinity : 84, minHeight: big ? LabourTheme.minimumControlSize : 74)
        .frame(width: big ? nil : 84, height: big ? nil : 74)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LabourPalette.paperHi.color))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(LabourPalette.redInk.color, lineWidth: 2))
    }
}

/// One line of set-up on the paper: an icon, what it is, how it stands in small capitals, and a
/// dashed rule above, as the prototype's task rows.
struct SetUpRow: View {
    var title: String
    var detail: String
    var icon: String
    var isWarning = false
    var isFirst = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .medium))
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(MissionType.body(15.5).weight(.semibold))
                Text(detail.uppercased())
                    .font(MissionType.mono())
                    .tracking(0.8)
                    .foregroundStyle(isWarning ? LabourPalette.amberText.color : LabourTheme.paperMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .foregroundStyle(LabourTheme.paperMuted)
                .accessibilityHidden(true)
        }
        .foregroundStyle(LabourTheme.paperInk)
        .padding(.vertical, 12)
        .frame(minHeight: LabourTheme.minimumControlSize)
        .contentShape(Rectangle())
        .overlay(alignment: .top) {
            if !isFirst {
                Line()
                    .stroke(LabourPalette.paperEdge.color, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .frame(height: 1.5)
            }
        }
    }
}

/// A straight line across, for the dashed rules between rows.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

/// The launch site, with the prototype's big T-minus, the due date and the week over the sky. At
/// the accessibility text sizes the small print moves below the picture, onto the ground, so it can
/// grow without covering the rocket.
struct LaunchSiteHeader: View {
    var calendar: PregnancyCalendar?
    var today: CalendarDay
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let age = calendar?.gestationalAge(on: today)
        let palette = SkyPalette.forWeek(age?.weeks)
        let below = typeSize.isAccessibilitySize
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                LaunchSiteScene(palette: palette)
                HStack(alignment: .top) {
                    if let calendar {
                        VStack(alignment: .leading, spacing: 4) {
                            countdown(calendar)
                            if !below {
                                details(calendar)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    } else if !below {
                        setDueDate
                    }
                    Spacer(minLength: 8)
                    if let age, !below {
                        weekChip(age)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 54)
            }
            if below {
                VStack(alignment: .leading, spacing: 10) {
                    if let calendar {
                        details(calendar)
                    } else {
                        setDueDate
                    }
                    if let age {
                        weekChip(age)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                // Room for the paper's rounded top, which overlaps the header.
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.ground)
            }
        }
    }

    private var setDueDate: some View {
        NavigationLink {
            MissionProfileForm()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Set T-0")
                    .font(.custom(MissionType.displayFamily, fixedSize: 72))
                Text("Add the due date in Mission profile".uppercased())
                    .font(MissionType.mono())
                    .foregroundStyle(Self.glow)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(LabourTheme.cream)
            // Over the sky, kept left of the rocket.
            .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : 210, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func weekChip(_ age: GestationalAge) -> some View {
        Text("Week \(age.description)".uppercased())
            .font(MissionType.mono())
            .tracking(1.1)
            .foregroundStyle(LabourTheme.cream)
            .padding(.horizontal, 12)
            .frame(minHeight: 30)
            .background(Capsule().fill(Self.chipFill))
            .overlay(Capsule().strokeBorder(LabourTheme.cream.opacity(0.65), lineWidth: 1.5))
            .padding(.top, 4)
            .accessibilityLabel("\(age.weeks) weeks and \(age.days) days")
    }

    private func countdown(_ calendar: PregnancyCalendar) -> some View {
        let days = calendar.daysToDueDate(from: today)
        let number = days >= 0 ? "T–\(days)" : "T+\(-days)"
        return Text(number)
            .font(.custom(MissionType.displayFamily, fixedSize: number.count > 4 ? 92 : 112))
            .foregroundStyle(LabourTheme.cream)
            // The prototype's hard shadow under the number: no blur.
            .shadow(color: LabourTheme.navy.opacity(0.35), radius: 0, x: 0, y: 3)
            .accessibilityLabel(days >= 0 ? "\(days) days to the due date" : "\(-days) days past the due date")
    }

    /// "Days to launch" and the due date, in the prototype's glowing small capitals.
    private func details(_ calendar: PregnancyCalendar) -> some View {
        let days = calendar.daysToDueDate(from: today)
        let due = calendar.dueDate.startDate(in: .current)
        return VStack(alignment: .leading, spacing: 2) {
            Text(days >= 0 ? "Days to launch" : "Days past T-0")
            if let due {
                Text("T-0 · \(due.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))")
            }
        }
        .font(MissionType.mono())
        .tracking(1.1)
        .textCase(.uppercase)
        .foregroundStyle(Self.glow)
        .accessibilityHidden(true)
    }

    /// The prototype's glow and its chip, rgba(14, 20, 51, 0.35).
    private static let glow = PaletteColor(hex: 0xFFE2A3).color
    private static let chipFill = Color(red: 14 / 255, green: 20 / 255, blue: 51 / 255).opacity(0.35)
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
