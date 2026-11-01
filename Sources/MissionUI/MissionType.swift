import CoreText
import MissionCore
import SwiftUI

/// The agreed prototype's three typefaces, bundled in Fonts/ with their SIL Open Font License:
/// League Gothic for big headlines and numbers, Martian Mono for small capital labels, and
/// Instrument Sans for everything he reads. Sizes are the prototype's, in points, and grow with
/// Dynamic Type. Nothing goes under 11 points, where the prototype used 8.5 (redesign rule 5).
public enum MissionType {
    public static let displayFamily = "League Gothic"
    public static let monoFamily = "Martian Mono"
    public static let bodyFamily = "Instrument Sans"
    /// The smallest text in labour mode: caption 2.
    public static let minimumSize: CGFloat = 11

    /// Makes the bundled fonts available to this app. Call once at launch; later calls do nothing.
    /// Returns whether all three are ready.
    @discardableResult
    public static func registerFonts() -> Bool { registered }

    /// The bundle with the fonts and their licences.
    static let bundle = Bundle.module

    private static let registered: Bool = {
        let urls = bundle.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
        guard urls.count == 3 else { return false }
        return urls.allSatisfy { url in
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) { return true }
            // Already registered, say by a test host, is fine.
            let code = error.map { CFErrorGetCode($0.takeRetainedValue()) }
            return code == CTFontManagerError.alreadyRegistered.rawValue
        }
    }()

    /// Headlines and big numbers. Only at 22 points and over (redesign rule 5).
    public static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom(displayFamily, size: max(22, size), relativeTo: style)
    }

    /// Small labels such as "TELEMETRY · LAST 60 MIN".
    public static func mono(_ size: CGFloat = minimumSize, relativeTo style: Font.TextStyle = .caption2) -> Font {
        .custom(monoFamily, size: max(minimumSize, size), relativeTo: style)
    }

    /// Everything he reads: the reasons, the flags, the questions.
    public static func body(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(bodyFamily, size: max(minimumSize, size), relativeTo: style)
    }

    /// The prototype's letter spacing for capital labels, 0.12 em.
    public static func monoTracking(_ size: CGFloat = minimumSize) -> CGFloat { size * 0.12 }
}

/// The five advice levels as a strip, with the current one lit: sun, or red from "Call now" up.
/// Read as one element by VoiceOver. At big text sizes it shows the current level alone.
public struct LevelStrip: View {
    public var state: LabourState
    @Environment(\.missionMode) private var mode

    public init(state: LabourState) {
        self.state = state
    }

    public static func label(_ state: LabourState) -> String {
        switch state {
        case .early: "Early"
        case .establishing: "Building"
        case .callTriage: "Call"
        case .callNow: "Call now"
        case .call999: "999"
        }
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                ForEach(LabourState.allCases, id: \.self) { level in
                    chip(level, isOn: level == state)
                }
            }
            HStack(spacing: 4) {
                ForEach(LabourState.allCases, id: \.self) { level in
                    if level == state {
                        chip(level, isOn: true).layoutPriority(1)
                    } else {
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(LabourTheme.levelChip)
                            .frame(width: 16)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Advice level: \(Self.label(state)), \(state.rawValueIndex + 1) of \(LabourState.allCases.count)")
    }

    private func chip(_ level: LabourState, isOn: Bool) -> some View {
        let hot = level >= .callNow
        return Text(Self.label(level))
            .font(MissionType.mono().weight(isOn ? .semibold : .regular))
            .fixedSize()
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity)
            .foregroundStyle(isOn ? (hot ? LabourTheme.cream : onText) : LabourTheme.muted)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isOn ? (hot ? LabourTheme.hot : onFill) : LabourTheme.levelChip)
            )
    }

    private var onFill: Color { mode == .practice ? LabourTheme.sim : LabourTheme.sun }
    private var onText: Color { mode == .practice ? LabourTheme.simDeep : LabourTheme.navy }
}

extension LabourState {
    var rawValueIndex: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

/// The last hour as a line: each contraction a hump as long as it lasted, a dot at the end while
/// one is running, and a dashed tick where a missed tap was counted. The prototype's trace, without
/// its glow or its idle wobble.
public struct ContractionTrace: View {
    public var contractions: [Contraction]
    public var missedTaps: [MissedTapGap]
    public var now: Date
    public var window: TimeInterval
    @Environment(\.missionMode) private var mode

    public init(contractions: [Contraction], missedTaps: [MissedTapGap], now: Date, window: TimeInterval = 3600) {
        self.contractions = contractions
        self.missedTaps = missedTaps
        self.now = now
        self.window = window
    }

    public var body: some View {
        Canvas { context, size in
            let width = size.width
            let base = size.height - 10
            let amplitude = size.height * (size.height < 64 ? 0.48 : 0.62)
            func x(_ date: Date) -> CGFloat { width - 1 - CGFloat(now.timeIntervalSince(date) / window) * (width - 2) }

            var grid = Path()
            for minutes in stride(from: 0, through: Int(window / 60), by: 10) {
                let gridX = width - CGFloat(minutes * 60) / CGFloat(window) * (width - 2) - 1
                grid.move(to: CGPoint(x: gridX, y: 0))
                grid.addLine(to: CGPoint(x: gridX, y: base + 2))
            }
            context.stroke(grid, with: .color(LabourTheme.cream.opacity(0.1)), lineWidth: 1)

            let recent = contractions.filter { ($0.end ?? now) >= now.addingTimeInterval(-window) }
            var line = Path()
            for column in stride(from: CGFloat(0), through: width, by: 1) {
                let time = now.addingTimeInterval(-Double((width - 1 - column) / (width - 2)) * window)
                var level = base
                for contraction in recent where time >= contraction.start && time <= (contraction.end ?? now) {
                    let elapsed = now.timeIntervalSince(contraction.start)
                    let length = contraction.end.map { $0.timeIntervalSince(contraction.start) } ?? max(50, elapsed)
                    let share = min(1, time.timeIntervalSince(contraction.start) / max(1, length))
                    // An open contraction rises over its first 25 seconds.
                    let height = contraction.end == nil ? min(1, elapsed / 25) : 1
                    level = base - amplitude * height * pow(sin(Double.pi * share), 2)
                }
                if column == 0 {
                    line.move(to: CGPoint(x: column, y: level))
                } else {
                    line.addLine(to: CGPoint(x: column, y: level))
                }
            }
            context.stroke(line, with: .color(colour), style: StrokeStyle(lineWidth: 1.75, lineJoin: .round))

            var ticks = Path()
            for gap in missedTaps {
                for index in 1...max(1, gap.estimatedMissed) {
                    let share = Double(index) / Double(gap.estimatedMissed + 1)
                    let tickX = x(gap.after.addingTimeInterval(gap.before.timeIntervalSince(gap.after) * share))
                    guard tickX >= 0 else { continue }
                    ticks.move(to: CGPoint(x: tickX, y: base))
                    ticks.addLine(to: CGPoint(x: tickX, y: base - amplitude * 0.7))
                }
            }
            context.stroke(
                ticks, with: .color(LabourTheme.cream.opacity(0.45)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))

            if let open = recent.last(where: { $0.end == nil }) {
                let rise = min(1, now.timeIntervalSince(open.start) / 25)
                let dot = CGRect(x: width - 5, y: base - amplitude * rise - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: dot), with: .color(mode == .practice ? LabourTheme.simInk : Self.glow))
            }
        }
        .accessibilityElement()
        .accessibilityLabel(summary)
    }

    private var colour: Color { mode == .practice ? LabourTheme.sim : LabourTheme.sun }
    private static let glow = PaletteColor(hex: 0xFFE2A3).color

    /// What VoiceOver reads instead of the drawing.
    private var summary: String {
        let count = contractions.filter { now.timeIntervalSince($0.start) <= window }.count
        let running = contractions.contains { $0.end == nil } ? " One is going now." : ""
        return count == 1
            ? "1 contraction in the last hour.\(running)" : "\(count) contractions in the last hour.\(running)"
    }
}

/// The big round START/STOP button, the prototype's "burn" button. While a contraction runs it
/// shows the time and a breathing cue, and its rings breathe on a 10-second cycle, in on the
/// first 4 seconds and out on the next 6. The rings move with the one labour clock, and stay
/// still under Reduce Motion or Low Power Mode.
public struct BurnButton: View {
    public var isRunning: Bool
    public var elapsed: TimeInterval?
    /// Over this, it asks "still going?", as the engine treats it as urgent.
    public var urgentAfter: TimeInterval
    /// Smaller type while the advice is "Call now" or 999, as in the prototype.
    public var isCompact: Bool
    public var action: () -> Void
    @Environment(\.missionMode) private var mode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 11 points at the current text size, so the small labels can grow and still fit the circle.
    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = MissionType.minimumSize

    public init(
        isRunning: Bool, elapsed: TimeInterval?, urgentAfter: TimeInterval, isCompact: Bool = false,
        action: @escaping () -> Void
    ) {
        self.isRunning = isRunning
        self.elapsed = elapsed
        self.urgentAfter = urgentAfter
        self.isCompact = isCompact
        self.action = action
    }

    /// The line above the big word.
    public static func top(isRunning: Bool, elapsed: TimeInterval?, urgentAfter: TimeInterval) -> String {
        guard isRunning else { return "Contraction" }
        let over = (elapsed ?? 0) > urgentAfter
        return over ? "Over \(StateCopy.phrase(seconds: urgentAfter)) · still going?" : "Contraction · tap to stop"
    }

    /// The same line for a button under 175 points, where the long one would cross the ring.
    public static func shortTop(isRunning: Bool, elapsed: TimeInterval?, urgentAfter: TimeInterval) -> String {
        guard isRunning else { return "Contraction" }
        return (elapsed ?? 0) > urgentAfter ? "Still going?" : "Tap to stop"
    }

    /// The line under it: a breathing cue while running, on a 10-second cycle.
    public static func cue(isRunning: Bool, elapsed: TimeInterval?) -> String {
        guard isRunning else { return "when one begins" }
        return Int(elapsed ?? 0) % 10 < 4 ? "Breathe in with her" : "Long breath out"
    }

    /// How big the breathing rings are at a moment: 0.76 to 1 over 4 seconds, then back over 6.
    public static func ringScale(elapsed: TimeInterval) -> CGFloat {
        let phase = elapsed.truncatingRemainder(dividingBy: 10)
        return phase < 4 ? 0.76 + 0.24 * phase / 4 : 1 - 0.24 * (phase - 4) / 6
    }

    private var ring: Color { mode == .practice ? LabourTheme.sim : LabourTheme.sun }
    private var isLong: Bool { isRunning && (elapsed ?? 0) > urgentAfter }
    private var moves: Bool { isRunning && !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled }

    public var body: some View {
        Button(action: action) {
            GeometryReader { geometry in
                let side = min(geometry.size.width, geometry.size.height)
                let unit = side / 232
                ZStack {
                    Circle().fill(Self.face)
                    Circle().strokeBorder(Self.edge, lineWidth: 1).padding(-1)
                    if isLong {
                        Circle().strokeBorder(LabourTheme.signal, lineWidth: 3).padding(-3)
                    }
                    Circle().strokeBorder(ring.opacity(0.18), lineWidth: 2 * unit).padding(3 * unit)
                    ZStack {
                        Circle().fill(ring.opacity(0.08)).padding(24 * unit)
                        Circle().stroke(ring, lineWidth: 5 * unit).padding(12 * unit)
                    }
                    .scaleEffect(moves ? Self.ringScale(elapsed: elapsed ?? 0) : 1)
                    .animation(moves ? .linear(duration: 1) : nil, value: Int(elapsed ?? 0))
                    label(side: side)
                }
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            (mode == .practice ? "Practice. " : "") + (isRunning ? "Stop contraction" : "Start contraction")
        )
        .accessibilityValue(isRunning ? "Running for \(clockText(elapsed ?? 0))" : "")
    }

    private func label(side: CGFloat) -> some View {
        let size = side * (isCompact ? 0.255 : 0.33)
        return VStack(spacing: 4) {
            let top = side >= 175 ? Self.top : Self.shortTop
            // One part to a line: "CONTRACTION", then "TAP TO STOP".
            Text(top(isRunning, elapsed, urgentAfter).uppercased().replacingOccurrences(of: " · ", with: "\n"))
                .font(MissionType.mono())
                .tracking(0.6)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                // Grows with the text size while it fits, and never shrinks under 11 points.
                .minimumScaleFactor(min(1, MissionType.minimumSize / labelSize))
                .foregroundStyle(isLong ? LabourPalette.callAccent.color : LabourTheme.muted)
            // Sized by the button, which is already the biggest thing on screen.
            Text(isRunning ? clockText(elapsed ?? 0) : "Start")
                .font(.custom(MissionType.displayFamily, fixedSize: size))
                .monospacedDigit()
                .tracking(size * 0.04)
                .foregroundStyle(LabourTheme.cream)
                .lineLimit(1)
                .layoutPriority(1)
            // The prototype drops the cue when the button is under 175 points.
            if side >= 175 {
                Text(Self.cue(isRunning: isRunning, elapsed: elapsed))
                    .font(MissionType.body(15).weight(.semibold))
                    .foregroundStyle(LabourTheme.sun)
                    .lineLimit(1)
                    .minimumScaleFactor(min(1, MissionType.minimumSize / labelSize * 15 / 11))
            }
        }
        // Inside the ring: at big text sizes the small lines shrink before the clock does.
        .frame(maxWidth: side * 0.68, maxHeight: side * 0.7)
    }

    /// The prototype's button face, rgba(10, 14, 38, 0.82), and its thin pale-blue edge.
    private static let face = Color(red: 10 / 255, green: 14 / 255, blue: 38 / 255).opacity(0.82)
    private static let edge = LabourTheme.blueprint.opacity(0.25)
}
