import MissionCore
import MissionUI
import SwiftUI

@main
struct MissionControlWatchApp: App {
    @State private var model = WatchLabourModel()

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
        VStack(spacing: 8) {
            Text(weeksText)
                .font(.footnote)
                .foregroundStyle(LabourTheme.secondaryText)
            ZStack {
                Circle()
                    .fill(LabourTheme.emergency)
                Circle()
                    .trim(from: 0, to: isPressing ? 1 : 0)
                    .stroke(LabourTheme.primaryText, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(4)
                VStack(spacing: 0) {
                    Text("LAUNCH")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                    Text("Hold")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
            }
            .frame(width: 110, height: 110)
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
                .font(.caption2)
                .foregroundStyle(LabourTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var weeksText: String {
        if let age = model.gestationToday { return "\(age.description) weeks" }
        return model.brief == nil ? "Open the iPhone app once" : "No due date on iPhone"
    }
}
