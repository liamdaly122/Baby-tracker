import MissionCore
import MissionUI
import SwiftUI

enum LabourTab: Hashable {
    case timer
    case call
    case plan
    case coach
    case decoder
}

/// Labour mode: dark, high-contrast, humour off, five tabs, no modals.
struct LabourRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: LabourTab = .timer
    @State private var stage: LabourStage = .latent

    var body: some View {
        TabView(selection: $tab) {
            LabourTabStack(tab: $tab, showsStatus: false) { TimerTab() }
                .tabItem { Label("Timer", systemImage: "timer") }
                .tag(LabourTab.timer)
            LabourTabStack(tab: $tab, world: .call) { CallTab() }
                .tabItem { Label("Call", systemImage: "phone.fill") }
                .tag(LabourTab.call)
            LabourTabStack(tab: $tab, world: .plan) { PlanTab() }
                .tabItem { Label("Plan", systemImage: "doc.text.fill") }
                .tag(LabourTab.plan)
            LabourTabStack(tab: $tab, world: .coach) { CoachTab(stage: $stage) }
                .tabItem { Label("Coach", systemImage: "figure.2") }
                .tag(LabourTab.coach)
            LabourTabStack(tab: $tab, world: .decoder) { DecoderTab(stage: stage) }
                .tabItem { Label("Decoder", systemImage: "character.book.closed.fill") }
                .tag(LabourTab.decoder)
        }
        .tint(LabourTheme.amber)
        .toolbarBackground(LabourTheme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .environment(\.humourLevel, .off)
        .task {
            // Re-run the engine at the next moment the advice could change, at least every 15 s.
            while !Task.isCancelled {
                model.labour.refresh()
                let next = model.labour.output?.nextReviewAt?.timeIntervalSinceNow ?? 15
                try? await Task.sleep(for: .seconds(min(15, max(1, next))))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.labour.refresh()
            }
        }
    }
}

/// Each tab's navigation stack, with the labour menu and (off the timer) a slim status strip.
struct LabourTabStack<Content: View>: View {
    @Binding var tab: LabourTab
    var title: String = ""
    /// The tab's own look. Nil for the timer, which stays true black.
    var world: LabourWorld?
    var showsStatus = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showsStatus {
                    StatusStrip { tab = .timer }
                }
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background {
                if let world {
                    world.background
                } else {
                    LabourTheme.background
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        NavigationLink {
                            LabourSettingsView()
                        } label: {
                            Label("Labour settings", systemImage: "gearshape")
                        }
                        NavigationLink {
                            EndLabourView()
                        } label: {
                            Label("End labour", systemImage: "flag.checkered")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Labour menu")
                }
            }
        }
    }
}

/// The current advice in one line, on every tab but the timer. Tap to go to the timer.
struct StatusStrip: View {
    @Environment(AppModel.self) private var model
    var onTap: () -> Void

    var body: some View {
        if let output = model.labour.output {
            Button(action: onTap) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(LabourTheme.color(for: output.state))
                        .frame(width: 12, height: 12)
                    Text(StateCopy.headline(for: output.state, region: model.labour.region))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LabourTheme.primaryText)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "timer")
                        .foregroundStyle(LabourTheme.secondaryText)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(Color.black.opacity(0.4))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the timer")
        }
    }
}

/// A big red button that dials the emergency number.
struct EmergencyCallButton: View {
    var region: ContentRegion

    private var number: String { region == .us ? "911" : "999" }

    var body: some View {
        if let url = URL(string: "tel:\(number)") {
            Link(destination: url) {
                Label("Call \(number)", systemImage: "phone.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize + 8)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LabourTheme.emergency))
            }
            .accessibilityLabel("Call \(number)")
        }
    }
}
