import MissionCore
import MissionUI
import SwiftUI
import UserNotifications

/// The pre-launch shell: countdown, LAUNCH, and the set-up labour mode needs. The full T-minus
/// dashboard, briefings and checklists arrive in Phase 6.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var isConfirmingLaunch = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    countdown
                    if isConfirmingLaunch {
                        LaunchGate(
                            onLaunch: { Task { await model.launch() } },
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
                Text("Labour has started")
                    .font(.headline)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(LabourTheme.amber))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Launch labour mode")
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

/// Shown once before labour mode starts: what the app does and doesn't do.
struct LaunchGate: View {
    var onLaunch: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Before you start")
                .font(.title2.bold())
            Text(
                "Mission Control times contractions and follows NHS advice on when to call your maternity unit. "
                    + "It doesn't diagnose anything or tell you what stage of labour she's in."
            )
            Text("Your midwife's advice always comes first. In an emergency, call 999.")
                .fontWeight(.semibold)
            Text(
                "You'll be asked to allow notifications so the app can tell you when it's time to call, "
                    + "even with your phone locked."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            Button(action: onLaunch) {
                Text("Start labour mode")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LabourTheme.amber))
            }
            .buttonStyle(.plain)
            Button("Not yet", action: onCancel)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }
}
