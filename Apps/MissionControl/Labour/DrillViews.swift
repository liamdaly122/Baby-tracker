import MissionCore
import MissionUI
import SwiftUI

/// At the top of the timer in a practice run: what to do next, "Skip ahead", and the debrief. The
/// prototype's cyan drill strip, with "End practice" in its corner, where labour mode's old menu was.
struct DrillGuideCard: View {
    @Environment(AppModel.self) private var model
    var drill: DrillController

    var body: some View {
        let step = drill.step
        let plan = drill.plan ?? Drill.SkipPlan(every: 240, lasting: 65, span: 45 * 60)
        let guide = Drill.guide(step, plan: plan, region: drill.labour.region)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("PRACTICE · \(guide.title)".uppercased())
                    .font(MissionType.mono())
                    .tracking(MissionType.monoTracking())
                    .foregroundStyle(LabourTheme.sim)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                NavigationLink("End practice") { EndLabourView() }
                    .font(MissionType.body(13).weight(.semibold))
                    .foregroundStyle(LabourTheme.simInk)
                    .underline()
                    .frame(minHeight: LabourTheme.chipSize)
            }
            Text(guide.detail)
                .font(MissionType.body(14))
                .lineSpacing(2)
                .foregroundStyle(LabourTheme.simInk)
                .fixedSize(horizontal: false, vertical: true)
            switch step {
            case .skipAhead:
                simButton("Skip ahead \(plan.minutes) min", systemImage: "forward.fill") {
                    withAnimation { drill.skipAhead() }
                }
            case .debrief:
                if let debrief = drill.debrief() {
                    ForEach(
                        Drill.debriefLines(debrief, plan: plan, region: drill.labour.region),
                        id: \.self
                    ) { line in
                        Label(line, systemImage: "checkmark.circle")
                            .font(MissionType.body(14))
                            .foregroundStyle(LabourTheme.simInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                simButton("End the drill", systemImage: "flag.checkered") { model.endDrill() }
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LabourTheme.simDeep))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(LabourTheme.sim, lineWidth: 1.5))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Practice run")
    }

    private func simButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(MissionType.body(15).weight(.bold))
                .foregroundStyle(LabourTheme.simDeep)
                .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(LabourTheme.sim))
        }
        .buttonStyle(.plain)
    }
}

/// The prototype's practice-run card: deep teal with a cyan edge, a small cyan label and a big
/// cream heading. Used before, during and at the end of a drill, so practice always looks like
/// practice.
struct SimCard<Content: View>: View {
    var label: String
    var title: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label.uppercased())
                .font(MissionType.mono())
                .tracking(MissionType.monoTracking())
                .foregroundStyle(LabourTheme.sim)
            if let title {
                Text(title)
                    .font(MissionType.display(46))
                    .tracking(0.9)
                    .foregroundStyle(LabourTheme.cream)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            content()
        }
        .foregroundStyle(LabourTheme.simInk)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(LabourTheme.simDeep))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(LabourTheme.sim, lineWidth: 1.5))
    }
}

/// A button on a practice card: cyan, the darker red for "this is real", or outlined.
struct SimButton: View {
    enum Style {
        case sim
        case real
        case ghost
    }

    var title: String
    var style: Style = .sim
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MissionType.body(15).weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .foregroundStyle(text)
                .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
                .overlay {
                    if style == .ghost {
                        RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(
                            LabourTheme.sim, lineWidth: 1.5)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var fill: Color {
        switch style {
        case .sim: LabourTheme.sim
        case .real: LabourTheme.hot
        case .ghost: .clear
        }
    }

    private var text: Color {
        switch style {
        case .sim: LabourTheme.simDeep
        case .real: LabourTheme.cream
        case .ghost: LabourTheme.simInk
        }
    }
}

/// Asked before a drill: practice must never time a real labour. Yes goes to real labour mode.
struct DrillStartQuestion: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        DrillStartCard(onYes: { model.launch() }, onNo: { model.startDrill() })
    }
}

/// The question on its practice card: yes in the darker red, because yes is real.
struct DrillStartCard: View {
    var onYes: () -> Void
    var onNo: () -> Void

    var body: some View {
        SimCard(label: "Before the drill") {
            VStack(alignment: .leading, spacing: 10) {
                Text(Drill.startQuestion)
                    .font(MissionType.body(16).weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                SimButton(title: Drill.startYes, style: .real, action: onYes)
                SimButton(title: Drill.startNo, style: .sim, action: onNo)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LabourTheme.sim.opacity(0.08)))
            Text("To time real tightenings, always use LAUNCH.")
                .font(MissionType.body(13, relativeTo: .footnote))
        }
    }
}
