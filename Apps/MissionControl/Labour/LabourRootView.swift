import MissionCore
import MissionUI
import SwiftUI

enum LabourTab: Hashable, CaseIterable {
    case timer
    case call
    case plan
    case coach
    case decoder

    var title: String {
        switch self {
        case .timer: "Timer"
        case .call: "Call"
        case .plan: "Plan"
        case .coach: "Coach"
        case .decoder: "Decoder"
        }
    }

    var icon: String {
        switch self {
        case .timer: "timer"
        case .call: "phone"
        case .plan: "doc.text"
        case .coach: "person.2"
        case .decoder: "book.closed"
        }
    }

    /// Each tab's own look. Nil for the timer, which is the orbit scene.
    var world: LabourWorld? {
        switch self {
        case .timer: nil
        case .call: .call
        case .plan: .plan
        case .coach: .coach
        case .decoder: .decoder
        }
    }
}

/// Labour mode, laid out like the agreed prototype: the top row, the tab, and the prototype's own
/// five-tab bar along the bottom. Humour off, no modals. Pushed screens (settings, ending labour)
/// cover the whole thing.
struct LabourRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.missionMode) private var mode
    @State private var tab: LabourTab = .timer
    @State private var stage: LabourStage = .latent

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                LabourHeader(showsStatus: tab != .timer) { tab = .timer }
                Group {
                    switch tab {
                    case .timer: TimerTab()
                    case .call: CallTab()
                    case .plan: PlanTab()
                    case .coach: CoachTab(stage: $stage)
                    case .decoder: DecoderTab(stage: stage)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                LabourTabBar(tab: $tab)
            }
            .background {
                if let world = tab.world {
                    world.background
                } else {
                    OrbitScene(isPractice: mode == .practice)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(LabourTheme.sun)
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

/// Above every tab: the practice tape or "not saving", the top row, and (off the timer) a slim
/// line with the current advice.
struct LabourHeader: View {
    @Environment(AppModel.self) private var model
    @Environment(\.missionMode) private var mode
    var showsStatus: Bool
    var openTimer: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if mode == .practice {
                SimTape()
            } else if model.labour.isNotSaving {
                NotSavingBar()
            }
            LabourTopRow()
                .padding(.horizontal, 18)
                .padding(.top, 2)
                .padding(.bottom, 6)
            if showsStatus {
                StatusStrip(onTap: openTimer)
            }
        }
    }
}

/// The prototype's top row: a red dot, "LABOUR MODE · 40+2" and "Baby's here?", with the red 999
/// button added (redesign rule 2). In a practice run: "PRACTICE RUN" and "Real labour? Launch".
/// When the row is too narrow it shortens the label first, then drops it, then wraps.
struct LabourTopRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.missionMode) private var mode

    var body: some View {
        let weeks = model.labour.gestationLabel
        let names = mode == .practice ? ["Practice run", "Practice"] : ["Labour mode", "Labour"]
        ViewThatFits(in: .horizontal) {
            row("\(names[0]) · \(weeks)")
            row("\(names[1]) · \(weeks)")
            row(weeks)
            row(nil)
            VStack(alignment: .leading, spacing: 6) {
                recording("\(names[1]) · \(weeks)")
                HStack(spacing: 8) { pills }
            }
        }
    }

    private func row(_ label: String?) -> some View {
        HStack(spacing: 8) {
            if let label {
                recording(label)
            }
            Spacer(minLength: 0)
            pills
        }
    }

    private func recording(_ label: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(mode == .practice ? LabourTheme.sim : LabourTheme.signal)
                .frame(width: 8, height: 8)
            Text(label.uppercased())
                .font(MissionType.mono())
                .tracking(MissionType.monoTracking())
                .foregroundStyle(LabourTheme.cream)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    @ViewBuilder private var pills: some View {
        QuickEmergencyButton(region: model.labour.region)
            .fixedSize()
        if mode == .practice {
            Button {
                model.launch()
            } label: {
                pill("Real labour? Launch", fill: LabourTheme.hot, border: LabourTheme.hot)
            }
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityHint("Ends the practice run and starts labour mode")
        } else {
            NavigationLink {
                EndLabourView()
            } label: {
                pill("Baby's here?", fill: Self.pillSurface, border: LabourTheme.cream.opacity(0.7))
            }
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityHint("Ends labour mode: the baby's here, or it wasn't labour")
        }
    }

    /// The prototype's rgba(14, 20, 51, 0.6) pill.
    static let pillSurface = Color(red: 14 / 255, green: 20 / 255, blue: 51 / 255).opacity(0.6)

    private func pill(_ title: String, fill: Color, border: Color) -> some View {
        Text(title)
            .font(MissionType.body(13).weight(.semibold))
            .foregroundStyle(LabourTheme.cream)
            .padding(.horizontal, 14)
            .frame(minHeight: LabourTheme.chipSize)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(border, lineWidth: 1.5))
            .contentShape(Capsule())
    }
}

/// The prototype's tab bar: five icons with names, lit sun (cyan in practice) for the current tab.
struct LabourTabBar: View {
    @Environment(\.missionMode) private var mode
    @Binding var tab: LabourTab
    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 11

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LabourTab.allCases, id: \.self) { item in
                Button {
                    tab = item
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 20, weight: .medium))
                            .frame(height: 24)
                        Text(item.title)
                            .font(MissionType.body(11, relativeTo: .caption2).weight(.semibold))
                            .lineLimit(1)
                            // Shrinks only from big text sizes, never under 11 points.
                            .minimumScaleFactor(min(1, 11 / labelSize))
                    }
                    .foregroundStyle(
                        item == tab ? (mode == .practice ? LabourTheme.sim : LabourTheme.sun) : LabourTheme.muted
                    )
                    .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(item == tab ? [.isSelected] : [])
            }
        }
        .padding(.top, 2)
        .background {
            Color(red: 5 / 255, green: 6 / 255, blue: 15 / 255).opacity(0.9)
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(LabourTheme.cream.opacity(0.12)).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Labour mode tabs")
    }
}

/// The practice run's striped tape across the top of every screen.
struct SimTape: View {
    var body: some View {
        Text("Simulation · practice only".uppercased())
            .font(MissionType.mono())
            .tracking(MissionType.minimumSize * 0.16)
            .foregroundStyle(LabourTheme.simInk)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(LabourTheme.simDeep)
            .padding(.leading, 8)
            .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
            .background {
                Canvas { context, size in
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(LabourTheme.simDeep))
                    // The prototype's -45° stripes, 10 points of cyan in every 20.
                    let run = 20 * 2.0.squareRoot()
                    let stripe = 10 * 2.0.squareRoot()
                    var stripes = Path()
                    for start in stride(from: -size.height, through: size.width, by: run) {
                        stripes.move(to: CGPoint(x: start, y: size.height))
                        stripes.addLine(to: CGPoint(x: start + size.height, y: 0))
                        stripes.addLine(to: CGPoint(x: start + size.height + stripe, y: 0))
                        stripes.addLine(to: CGPoint(x: start + stripe, y: size.height))
                        stripes.closeSubpath()
                    }
                    context.fill(stripes, with: .color(LabourTheme.sim))
                }
            }
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Simulation. Practice only. Nothing here is real.")
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

/// 999 in the top row of every labour screen: one tap, always there. In a practice run it says
/// what it would do instead.
struct QuickEmergencyButton: View {
    @Environment(\.missionMode) private var mode
    var region: ContentRegion
    @State private var explainsPractice = false

    var body: some View {
        let number = StateCopy.emergencyNumber(region)
        if mode == .practice {
            Button {
                explainsPractice = true
            } label: {
                label(number, colour: LabourTheme.simDeep, text: LabourTheme.simInk)
            }
            .accessibilityLabel("Practice. \(number)")
            .alert("In a real labour this rings \(number)", isPresented: $explainsPractice) {
                Button("OK", role: .cancel) {}
            }
        } else if let url = EmergencyDial.url(region) {
            Link(destination: url) {
                label(number, colour: LabourTheme.hot, text: LabourTheme.cream)
            }
            .accessibilityLabel("Call \(number)")
        }
    }

    /// Text as well as the icon, so it never reads as the Call tab: a red pill with cream "999".
    private func label(_ number: String, colour: Color, text: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "phone.fill")
            Text(number)
        }
        .font(MissionType.body(14).weight(.bold))
        .foregroundStyle(text)
        .padding(.horizontal, 12)
        .frame(minHeight: LabourTheme.chipSize)
        .background(Capsule().fill(colour))
        .overlay(Capsule().strokeBorder(mode == .practice ? LabourTheme.sim : colour, lineWidth: 1.5))
        .contentShape(Capsule())
    }
}

/// The emergency number's dial link, the same everywhere it appears.
enum EmergencyDial {
    static func url(_ region: ContentRegion) -> URL? {
        PhoneNumber.shortCode(StateCopy.emergencyNumber(region))?.telURL
    }
}

/// A big red button that dials the emergency number. In a practice run it says what it would do.
struct EmergencyCallButton: View {
    @Environment(\.missionMode) private var mode
    var region: ContentRegion

    private var number: String { StateCopy.emergencyNumber(region) }

    var body: some View {
        if mode == .practice {
            PracticeDial(action: "Call \(number)", detail: "In a real emergency this rings \(number).")
        } else if let url = EmergencyDial.url(region) {
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
