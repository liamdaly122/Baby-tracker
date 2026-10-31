import MissionUI
import SwiftData
import SwiftUI

@main
struct MissionControlApp: App {
    /// Nil when the app is only hosting its tests: they make their own models.
    @State private var loaded: Result<AppModel, Error>? =
        LaunchOptions.isTestHost ? nil : Result { try AppModel(inMemory: LaunchOptions.inMemory) }

    var body: some Scene {
        WindowGroup {
            switch loaded {
            case .success(let model):
                AppRootView()
                    .environment(model)
                    .modelContainer(model.planning)
                    .task { LaunchOptions.applyDemoData(to: model) }
            case .failure(let error):
                StoreFailureView(error: error)
            case nil:
                EmptyView()
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

/// Shown if the stores can't be opened, which should only happen if the disk is full.
struct StoreFailureView: View {
    var error: Error

    var body: some View {
        VStack(spacing: 12) {
            Text("Mission Control can't open its data")
                .font(.title2.bold())
            Text("Free up some space and reopen the app. If labour has started, phone your maternity unit.")
                .multilineTextAlignment(.center)
            Text(error.localizedDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
