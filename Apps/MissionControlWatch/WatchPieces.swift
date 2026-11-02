import MissionCore
import MissionUI
import SwiftUI

/// The watch's pieces in the prototype's look, each built from plain values so the screens can use
/// them with live data and the picture tests can draw them.

/// The advice as a small mono pill: quiet, then sun, then the darker red.
struct WatchStatePill: View {
    var text: String
    var state: LabourState

    var body: some View {
        let (fill, ink): (Color, Color) =
            switch state {
            case .early: (LabourTheme.cream.opacity(0.1), LabourTheme.cream)
            case .establishing, .callTriage: (LabourTheme.sun, LabourTheme.navy)
            case .callNow, .call999: (LabourTheme.hot, LabourTheme.cream)
            }
        HStack {
            Text(text.uppercased())
                .font(MissionType.mono())
                .tracking(0.7)
                .foregroundStyle(ink)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(fill))
            Spacer()
        }
    }
}

/// The prototype's watch button: a sun ring round a soft sun centre, the time in the display face.
struct WatchBurnButton: View {
    var isRunning: Bool
    var elapsed: TimeInterval
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [LabourTheme.sun.opacity(0.16), Self.face], center: .center, startRadius: 0,
                            endRadius: 41))
                Circle()
                    .strokeBorder(LabourTheme.sun, lineWidth: isRunning ? 5 : 3)
                VStack(spacing: 2) {
                    Text(isRunning ? clockText(elapsed) : "Start")
                        .font(.custom(MissionType.displayFamily, fixedSize: 34))
                        .monospacedDigit()
                        .foregroundStyle(LabourTheme.cream)
                    Text((isRunning ? "Tap to stop" : "Contraction").uppercased())
                        .font(MissionType.mono())
                        .foregroundStyle(LabourTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 10)
            }
            .frame(width: 118, height: 118)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRunning ? "Stop contraction, running \(clockText(elapsed))" : "Start contraction")
    }

    /// The prototype's rgba(10, 14, 38, 0.9) at the button's edge.
    private static let face = Color(red: 10 / 255, green: 14 / 255, blue: 38 / 255).opacity(0.9)
}

/// "4 min apart" and "15 in hour" under the button.
struct WatchStatsLine: View {
    var every: String
    var lastHour: Int

    var body: some View {
        HStack {
            Text(every)
            Spacer()
            Text("\(lastHour) in hour")
        }
        .font(MissionType.mono())
        .monospacedDigit()
        .foregroundStyle(LabourTheme.muted)
    }
}

/// The face of the watch's call button: sun at "time to call", the darker red from "call now".
struct WatchCallFace: View {
    var title: String
    var warm: Bool
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "phone.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(MissionType.display(22, relativeTo: .headline))
                .tracking(0.6)
                // One line, as the prototype's, so the big button stays on screen. VoiceOver reads
                // the whole name.
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: compact ? 44 : 50)
        .foregroundStyle(warm ? LabourTheme.navy : LabourTheme.cream)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(warm ? LabourTheme.sun : LabourTheme.hot))
    }
}

/// The phone's cream question card, first answer filled.
struct WatchAskCard: View {
    var question: String
    var answers: [(String, () -> Void)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question)
                .font(MissionType.body(14).weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(answers.enumerated()), id: \.offset) { index, answer in
                Button(action: answer.1) {
                    Text(answer.0)
                        .font(MissionType.body(14).weight(.semibold))
                        .foregroundStyle(index == 0 ? LabourTheme.cream : LabourTheme.paperInk)
                        .frame(maxWidth: .infinity, minHeight: LabourTheme.chipSize)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(index == 0 ? LabourTheme.paperInk : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(LabourTheme.paperInk, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(LabourTheme.paperInk)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LabourTheme.cream))
    }
}

/// One rung of "If nobody answers" on the watch: the phone's small call button, a faint cream fill
/// rather than the watch's grey, which left the number under 4.5:1.
struct WatchCallRow: View {
    var title: String
    var number: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(MissionType.body(14).weight(.semibold))
                .foregroundStyle(LabourTheme.cream)
            Text(number)
                .font(MissionType.mono())
                .foregroundStyle(LabourTheme.muted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: LabourTheme.chipSize, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LabourTheme.cream.opacity(0.1)))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(LabourTheme.cream.opacity(0.3), lineWidth: 1.5))
    }
}

/// The phone's red LAUNCH key, round on the wrist, with a cream ring that fills while it's held.
struct WatchLaunchKey: View {
    /// How much of the ring is filled, from 0 to 1.
    var progress: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(LabourTheme.hot)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(LabourTheme.cream, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(4)
            VStack(spacing: 0) {
                Text("LAUNCH")
                    .font(.custom(MissionType.displayFamily, fixedSize: 30))
                    .tracking(2)
                Text("HOLD")
                    .font(MissionType.mono())
                    .tracking(1.3)
            }
            .foregroundStyle(LabourTheme.cream)
        }
        .frame(width: 110, height: 110)
    }
}
