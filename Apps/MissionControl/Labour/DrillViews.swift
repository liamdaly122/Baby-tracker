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

/// Asked before a drill: practice must never time a real labour. Yes goes to real labour mode.
struct DrillStartQuestion: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Drill.startQuestion)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                model.launch()
            } label: {
                Text(Drill.startYes)
                    .font(.headline)
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LabourTheme.amber))
            }
            .buttonStyle(.plain)
            Button {
                model.startDrill()
            } label: {
                Text(Drill.startNo)
                    .font(.headline)
                    .foregroundStyle(LabourTheme.blueprint)
                    .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(LabourTheme.blueprint, lineWidth: 2)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            Text("To time real tightenings, always use LAUNCH.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
