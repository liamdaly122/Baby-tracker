import MissionUI
import SwiftData
import SwiftUI

@main
struct MissionControlApp: App {
    /// Nil when the app is only hosting its tests: they make their own models.
    @State private var model: AppModel? = LaunchOptions.isTestHost ? nil : LaunchOptions.makeModel()

    var body: some Scene {
        WindowGroup {
            if let model {
                AppRootView()
                    .environment(model)
                    .modelContainer(model.planning)
                    .task { LaunchOptions.applyDemoData(to: model) }
            }
        }
    }
}

/// Labour mode when a session or a practice run is going, otherwise the pre-launch home.
struct AppRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.labour.isActive {
                LabourRootView()
                    .environment(\.missionMode, model.isDrilling ? .practice : .live)
                    // A new identity, so nothing from a practice run carries into real labour mode.
                    .id(model.isDrilling)
            } else {
                HomeView()
            }
        }
        .environment(\.humourLevel, model.profile.humour)
        .onChange(of: model.session.isActive) { _, active in
            // A real labour always wins, whichever device started it.
            if active {
                model.endDrill()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard let drill = model.drill else { return }
            switch phase {
            case .background:
                drill.backgroundedAt = Date()
            case .active:
                if drill.isStale(at: Date()) {
                    model.endDrill()
                } else {
                    drill.backgroundedAt = nil
                }
            default:
                break
            }
        }
    }
}
