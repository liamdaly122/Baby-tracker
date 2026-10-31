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
    @Environment(\.missionMode) private var mode
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
        .overlay {
            if mode == .practice {
                // A blueprint frame round every practice screen, so it's never mistaken for labour.
                Rectangle()
                    .strokeBorder(LabourTheme.blueprint, lineWidth: 4)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .preferredColorScheme(.dark)
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .environment(\.humourLevel, .off)
        .task(id: model.isDrilling) {
            // Re-run the engine at the next moment the advice could change, at least every 15 s.
            while !Task.isCancelled {
                let labour = model.labour
                labour.refresh()
                let next = labour.output?.nextReviewAt?.timeIntervalSince(labour.currentTime) ?? 15
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
    @Environment(AppModel.self) private var model
    @Environment(\.missionMode) private var mode
    @Binding var tab: LabourTab
    var title: String = ""
    /// The tab's own look. Nil for the timer, which stays true black.
    var world: LabourWorld?
    var showsStatus = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if mode == .practice {
                    SimulationBar()
                } else if model.labour.isNotSaving {
                    NotSavingBar()
                }
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
                            Label(mode == .practice ? "End drill" : "End labour", systemImage: "flag.checkered")
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
    @Environment(\.missionMode) private var mode
    var onTap: () -> Void

    var body: some View {
        if let output = model.labour.output {
            let headline = StateCopy.headline(for: output, region: model.labour.region)
            Button(action: onTap) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(LabourTheme.color(for: output.state))
                        .frame(width: 12, height: 12)
                    Text(mode.headline(headline))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LabourTheme.primaryText)
                        .lineLimit(1)
                        .accessibilityLabel(mode.spokenHeadline(headline))
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

/// A big red button that dials the emergency number. In a practice run it says what it would do.
struct EmergencyCallButton: View {
    @Environment(\.missionMode) private var mode
    var region: ContentRegion

    private var number: String { region == .us ? "911" : "999" }

    var body: some View {
        if mode == .practice {
            PracticeDial(action: "Call \(number)", detail: "In a real emergency this rings \(number).")
        } else if let url = URL(string: "tel:\(number)") {
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

/// Where a call button would be, in a practice run: what it would ring, and no dialling.
struct PracticeDial: View {
    var action: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(action, systemImage: "phone")
                .font(.title3.bold())
            Text(detail)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(LabourTheme.blueprint)
        .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(LabourTheme.blueprint, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Practice. \(action). \(detail)")
    }
}

/// On every practice screen: the SIMULATION tape, and one tap to a real labour.
struct SimulationBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            Text("SIMULATION · NOT REAL LABOUR")
                .font(.caption.weight(.heavy).monospaced())
                .tracking(2)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 26)
                .background(LabourTheme.blueprint)
            Button {
                model.launch()
            } label: {
                Label("Real labour? Launch now", systemImage: "flame.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(LabourTheme.amber)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Ends the practice run and starts labour mode")
        }
        .accessibilityElement(children: .contain)
    }
}
