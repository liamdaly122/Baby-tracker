import MissionCore
import MissionUI
import SwiftUI

@main
struct MissionControlWatchApp: App {
    @State private var model = WatchLabourModel()

    init() {
        MissionType.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(model)
        }
    }
}

/// Labour mode when a session is running, otherwise the launch screen.
struct WatchRootView: View {
    @Environment(WatchLabourModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.isActive {
                TabView {
                    WatchTimerPage()
                    WatchCallPage()
                    WatchFlagsPage()
                }
                .tabViewStyle(.verticalPage)
            } else {
                WatchLaunchView()
            }
        }
        .task {
            // The advice is replayed from the log, so a slow tick only delays the screen, not the rules.
            while !Task.isCancelled {
                model.refresh()
                try? await Task.sleep(for: .seconds(5))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refresh() }
        }
    }
}

/// Before labour: press and hold to launch. Never gated by the week.
struct WatchLaunchView: View {
    @Environment(WatchLabourModel.self) private var model
    @State private var isPressing = false

    var body: some View {
        if model.brief?.outcome != nil {
            // Labour mode is over: no LAUNCH on the wrist either. Plain whatever happened.
            Text("Labour mode is off.")
                .font(MissionType.body(14))
                .foregroundStyle(LabourTheme.muted)
                .multilineTextAlignment(.center)
        } else {
            launch
        }
    }

    /// LAUNCH on the wrist: hold the key, and a cream ring fills.
    private var launch: some View {
        VStack(spacing: 8) {
            Text(weeksText.uppercased())
                .font(MissionType.mono())
                .tracking(1)
                .foregroundStyle(LabourTheme.muted)
            WatchLaunchKey(progress: isPressing ? 1 : 0)
                .onLongPressGesture(minimumDuration: 0.8) {
                    WKHaptics.success()
                    model.launch()
                } onPressingChanged: { pressing in
                    withAnimation(pressing ? .linear(duration: 0.8) : .easeOut(duration: 0.2)) { isPressing = pressing }
                }
                .accessibilityLabel("Launch labour mode")
                .accessibilityHint("Press and hold. Labour started? Any week.")
                .accessibilityAction(named: "Launch") { model.launch() }
            Text("Labour started? Any week.")
                .font(MissionType.body(13, relativeTo: .footnote))
                .foregroundStyle(LabourTheme.muted)
                .multilineTextAlignment(.center)
        }
    }

    private var weeksText: String {
        if let age = model.gestationToday { return "\(age.description) weeks" }
        return model.brief == nil ? "Open the iPhone app once" : "No due date on iPhone"
    }
}
