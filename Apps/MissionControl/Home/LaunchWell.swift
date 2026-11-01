import MissionCore
import MissionUI
import SwiftUI

/// LAUNCH, as the agreed prototype builds it: a red key in a hazard-striped well under a safety
/// cover. Tap the cover (or drag it up) and it lifts to show the key; tap LAUNCH and labour mode
/// opens. The cover is the "are you sure?": nothing launches from a pocket. LAUNCH is the same
/// full-size key at every week (`LaunchWindow`). While the cover is up, the app says what it does
/// and doesn't do, and from 30 weeks offers the drill beside it. The cover closes itself after a
/// while, as in the prototype, unless he's reading the full disclaimer or the drill question.
struct LaunchWell: View {
    var window: LaunchWindow
    var onLaunch: () -> Void
    @AppStorage("launchDisclaimerSeen") private var disclaimerSeen = false
    /// Read when the cover lifts, so the full text doesn't vanish while he's reading it.
    @State private var showsFullDisclaimer = false
    @State private var isOpen: Bool

    /// `startsOpen` is for picture tests.
    init(window: LaunchWindow, startsOpen: Bool = false, onLaunch: @escaping () -> Void) {
        self.window = window
        self.onLaunch = onLaunch
        _isOpen = State(initialValue: startsOpen)
    }
    @State private var askingAboutDrill = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            well
            if isOpen {
                disclaimer
                if window.drillOnLaunchCard {
                    if askingAboutDrill {
                        DrillStartQuestion()
                    } else {
                        drillKey
                    }
                }
                Button("Not yet") { setOpen(false) }
                    .font(MissionType.body(15).weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: LabourTheme.chipSize)
            }
        }
        .task(id: isOpen && !showsFullDisclaimer && !askingAboutDrill) {
            // The prototype closes the cover again after 7 seconds.
            guard isOpen, !showsFullDisclaimer, !askingAboutDrill else { return }
            try? await Task.sleep(for: .seconds(7))
            if !Task.isCancelled {
                setOpen(false)
            }
        }
    }

    private func setOpen(_ open: Bool) {
        if open {
            showsFullDisclaimer = !disclaimerSeen
            disclaimerSeen = true
        } else {
            askingAboutDrill = false
        }
        withAnimation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.3)) { isOpen = open }
        if open {
            AccessibilityNotification.Announcement("The cover is up. LAUNCH is under it.").post()
        }
    }

    /// The well: hazard stripes, the red key, and the cover over it.
    private var well: some View {
        ZStack {
            HazardStripes()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            Button(action: onLaunch) {
                VStack(spacing: 2) {
                    Text("LAUNCH")
                        .font(MissionType.display(38))
                        .tracking(3)
                    Text("Labour has started".uppercased())
                        .font(MissionType.mono())
                        .tracking(1.7)
                }
                .foregroundStyle(LabourTheme.cream)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Self.keyEdge)
                        .overlay(alignment: .top) {
                            // The prototype's raised key: a darker edge along the bottom.
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LabourTheme.hot)
                                .padding(.bottom, 6)
                        }
                }
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(6)
            .disabled(!isOpen)
            .accessibilityHidden(!isOpen)
            .accessibilityLabel("Launch labour mode. \(window.launchSubtitle)")
            cover
                .padding(6)
        }
        .frame(height: 112)
        .sensoryFeedback(.impact(weight: .medium), trigger: isOpen)
    }

    /// The safety cover. It tips back from its top edge, as the prototype's does.
    private var cover: some View {
        Button {
            setOpen(!isOpen)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(LabourTheme.sun)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lift cover to launch")
                        .font(MissionType.display(23, relativeTo: .title2))
                        .tracking(1.4)
                        .foregroundStyle(LabourTheme.cream)
                    Text(window.launchSubtitle.uppercased())
                        .font(MissionType.mono())
                        .tracking(1.5)
                        .foregroundStyle(LabourTheme.muted)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Self.coverFill))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(LabourTheme.cream.opacity(0.25), lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .highPriorityGesture(
            DragGesture(minimumDistance: 12).onEnded { drag in
                // Up lifts it; down closes it.
                if drag.translation.height < -20 {
                    setOpen(true)
                } else if drag.translation.height > 20 {
                    setOpen(false)
                }
            }
        )
        .rotation3DEffect(.degrees(isOpen ? 80 : 0), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.6)
        .allowsHitTesting(!isOpen)
        .accessibilityHidden(isOpen)
        .accessibilityLabel("Lift the safety cover to reveal the launch button")
        .accessibilityHint(window.launchSubtitle)
    }

    /// What the app does and doesn't do: in full the first time, then one line.
    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsFullDisclaimer {
                Text(
                    "Mission Control times contractions. Its advice on when to call your maternity unit is based on "
                        + "NHS guidance, and it isn't affiliated with or endorsed by the NHS. It doesn't diagnose "
                        + "anything or tell you what stage of labour she's in."
                )
                Text("Your midwife's advice always comes first. In an emergency, call 999.")
                    .fontWeight(.semibold)
                Text("Allow alerts when asked, so it can tell you when to call even with the phone locked.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Based on NHS advice, not a diagnosis. Her midwife's advice comes first. Emergency: 999.")
                    .foregroundStyle(.secondary)
            }
        }
        .font(MissionType.body(15))
        .fixedSize(horizontal: false, vertical: true)
        .transition(.opacity)
    }

    /// The smaller practice key, from 30 to 36+6 weeks and when the weeks aren't known.
    private var drillKey: some View {
        Button {
            withAnimation(reduceMotion ? nil : .default) { askingAboutDrill = true }
        } label: {
            VStack(spacing: 2) {
                Text("Run the drill")
                    .font(MissionType.display(22, relativeTo: .title3))
                    .tracking(1)
                Text("Practice · nothing is real".uppercased())
                    .font(MissionType.mono())
                    .tracking(1.3)
            }
            .foregroundStyle(LabourTheme.simInk)
            .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LabourTheme.simDeep))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(LabourTheme.sim, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Run the drill. Practice: nothing is real.")
    }

    /// The prototype's cover, #1A2046, and the key's darker bottom edge, #A62F1B under the red.
    private static let coverFill = PaletteColor(hex: 0x1A2046).color
    private static let keyEdge = PaletteColor(hex: 0x7E2214).color
}

/// The prototype's yellow-and-navy hazard stripes round the well, still.
struct HazardStripes: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(LabourTheme.navy))
            let run = 22 * 2.0.squareRoot()
            let stripe = 11 * 2.0.squareRoot()
            var stripes = Path()
            for start in stride(from: -size.height, through: size.width, by: run) {
                stripes.move(to: CGPoint(x: start, y: size.height))
                stripes.addLine(to: CGPoint(x: start + size.height, y: 0))
                stripes.addLine(to: CGPoint(x: start + size.height + stripe, y: 0))
                stripes.addLine(to: CGPoint(x: start + stripe, y: size.height))
                stripes.closeSubpath()
            }
            context.fill(stripes, with: .color(LabourTheme.sun))
        }
        .accessibilityHidden(true)
    }
}
