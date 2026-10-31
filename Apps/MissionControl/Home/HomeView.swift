import MissionCore
import MissionUI
import SwiftUI
import UserNotifications

/// The pre-launch shell: countdown, LAUNCH, and the set-up labour mode needs. The full T-minus
/// dashboard, briefings and checklists arrive in Phase 6.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var isConfirmingLaunch = false

    /// Which keys the launch card shows this week. LAUNCH is the same at every week.
    private var window: LaunchWindow {
        LaunchWindow(
            gestationalAgeDays: model.profile.pregnancyCalendar?.gestationalAgeDays(at: Date(), in: .current))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    countdown
                    if isConfirmingLaunch {
                        LaunchGate(
                            offersDrill: window.drillOnLaunchCard,
                            onLaunch: { model.launch() },
                            onCancel: { withAnimation { isConfirmingLaunch = false } }
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        launchButton
                    }
                    setUpLinks
                }
                .padding(16)
            }
            .navigationTitle("Mission Control")
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

    private var launchButton: some View {
        Button {
            withAnimation { isConfirmingLaunch = true }
        } label: {
            VStack(spacing: 4) {
                Text("LAUNCH")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                Text(window.launchSubtitle)
                    .font(.headline)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(LabourTheme.amber))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Launch labour mode. \(window.launchSubtitle)")
    }

    private var setUpLinks: some View {
        VStack(spacing: 0) {
            NavigationLink {
                MissionProfileForm()
            } label: {
                SetUpRow(
                    title: "Mission profile", detail: "Due date, hospital and triage number",
                    icon: "person.text.rectangle")
            }
            Divider()
            NavigationLink {
                BirthPlanEditor()
            } label: {
                SetUpRow(title: "Birth plan", detail: "The five things that matter most", icon: "doc.text")
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
            if window.drillInHangar {
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

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

/// The launch card: the real key first and full size at every week, what the app does and doesn't
/// do (in full the first time, then one line), and from 30 weeks a smaller drill key under it.
struct LaunchGate: View {
    var offersDrill: Bool
    var onLaunch: () -> Void
    var onCancel: () -> Void
    @AppStorage("launchDisclaimerSeen") private var disclaimerSeen = false
    /// Read when the card opens, so the full text doesn't vanish while he's reading it.
    @State private var showsFullDisclaimer = true
    @State private var askingAboutDrill = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onLaunch) {
                Text("Start labour mode")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize + 16)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LabourTheme.amber))
            }
            .buttonStyle(.plain)
            if showsFullDisclaimer {
                Text(
                    "Mission Control times contractions. Its advice on when to call your maternity unit is based on "
                        + "NHS guidance, and it isn't affiliated with or endorsed by the NHS. It doesn't diagnose "
                        + "anything or tell you what stage of labour she's in."
                )
                Text("Your midwife's advice always comes first. In an emergency, call 999.")
                    .fontWeight(.semibold)
                Text("Allow alerts when asked, so it can tell you when to call even with the phone locked.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Based on NHS advice, not a diagnosis. Her midwife's advice comes first. Emergency: 999.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if offersDrill {
                if askingAboutDrill {
                    DrillStartQuestion()
                } else {
                    Button {
                        withAnimation { askingAboutDrill = true }
                    } label: {
                        Label("Not labour yet? Run the drill", systemImage: "airplane.departure")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LabourTheme.blueprint)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            }
            Button("Not yet", action: onCancel)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .onAppear {
            showsFullDisclaimer = !disclaimerSeen
            disclaimerSeen = true
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }
}

/// The training hangar, from 37 weeks: the drill, away from the launch card, behind the question
/// that sends a real labour to LAUNCH instead.
struct DrillHangarView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Practice run")
                    .font(.largeTitle.bold())
                Text(
                    "A pretend labour at 39 weeks: time two contractions, skip ahead to the call point, handle a "
                        + "curveball and rehearse the call. Nothing is saved, nothing dials and no alerts are sent."
                )
                DrillStartQuestion()
            }
            .padding(16)
        }
        .navigationTitle("Training hangar")
        .navigationBarTitleDisplayMode(.inline)
    }
}
