import MissionCore
import MissionUI
import SwiftUI

/// The birth plan as the agreed prototype draws it: one printed sheet on a dark desk, large enough
/// to hold up to a midwife, with a stamp saying whether she's checked it, and a yellow sticky note
/// for him. Read-only: there's no editor in labour mode, so nothing can be changed by mistake.
struct PlanTab: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let plan = model.birthPlan
        let content = plan.content
        let changes = plan.changesSinceConfirmed(in: model.planning.mainContext) ?? []
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                LabourTabHeader(
                    world: .plan, eyebrow: "Her plan", title: "Show the midwife",
                    subtitle: "Read-only in labour. Turn the phone round.")
                if !content.isEmpty {
                    CheckedWithHerLine(confirmedAt: plan.herConfirmedAt, changes: changes.map(\.description))
                }
                PlanSheet(
                    content: content, motherName: model.profile.motherName,
                    unchecked: Set(content.uncheckedAnswers(herConfirmedAt: plan.herConfirmedAt).map(\.sectionID)),
                    stamp: content.isEmpty ? nil : PlanStamp(confirmedAt: plan.herConfirmedAt))
                AdvocateNote(branches: PlanScenario.allCases.compactMap(content.branch(for:)))
                LabourSettingsLink()
                    .padding(.top, 8)
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }
}

/// Above the sheet, only when something needs saying: she hasn't checked it, or it has changed
/// since she did. So he never shows a midwife something she hasn't seen as if it were hers.
struct CheckedWithHerLine: View {
    var confirmedAt: Date?
    var changes: [String]

    var body: some View {
        if confirmedAt == nil {
            Label("Not checked with her yet. Ask her before you show it.", systemImage: "exclamationmark.triangle")
                .font(MissionType.body(14).weight(.semibold))
                .foregroundStyle(LabourTheme.sun)
                .fixedSize(horizontal: false, vertical: true)
        } else if !changes.isEmpty {
            Label("Changed since she checked it: \(changes.joined(separator: ", ")).", systemImage: "pencil")
                .font(MissionType.body(14).weight(.semibold))
                .foregroundStyle(LabourTheme.sun)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The rubber stamp on the sheet: "Checked with her · 12 Oct", or "Not checked with her".
struct PlanStamp: View {
    var confirmedAt: Date?

    var body: some View {
        let colour = confirmedAt == nil ? LabourPalette.amberText.color : LabourPalette.redInk.color
        Text(
            (confirmedAt.map { "Checked with her · \($0.formatted(.dateTime.day().month(.abbreviated)))" }
                ?? "Not checked with her").uppercased()
        )
        .font(MissionType.mono())
        .tracking(1.1)
        .foregroundStyle(colour)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(colour, lineWidth: 2))
        .rotationEffect(.degrees(-7))
        .opacity(0.9)
    }
}

/// The plan on paper: her top five, then each section, then what she wants if plans change. Used in
/// labour and when he reads it through with her, so she agrees exactly what the midwife will see.
struct PlanSheet: View {
    var content: BirthPlanContent
    var motherName: String
    /// Sections that are his draft and not checked with her.
    var unchecked: Set<String> = []
    var stamp: PlanStamp?

    static let paper = LabourPalette.paperHi.color
    static let ink = LabourTheme.paperInk
    static let muted = LabourTheme.paperMuted
    static let edge = LabourPalette.paperEdge.color
    static let redInk = LabourPalette.redInk.color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BIRTH PLAN")
                Spacer(minLength: 8)
                Text(motherName.isEmpty ? "HER PREFERENCES" : motherName.uppercased())
            }
            .font(MissionType.mono())
            .tracking(1.3)
            .foregroundStyle(LabourTheme.cream)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(Self.ink)
            VStack(alignment: .leading, spacing: 10) {
                if let stamp {
                    // On its own line: at 11 points it's too wide to sit beside the heading.
                    stamp
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 8)
                }
                if content.isEmpty {
                    heading("No plan saved")
                    Text(
                        "When there's a calm moment, ask her for the one or two things that matter most, "
                            + "and tell the midwife."
                    )
                    .font(MissionType.body(15))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    if !content.filledTopFive.isEmpty {
                        heading("What matters most to her")
                        topFive(content.filledTopFive)
                    }
                    let answers = BirthPlanSection.allCases.compactMap { content.answer(for: $0.id) }
                    if !answers.isEmpty {
                        fields(answers)
                    }
                    let changes = PlanScenario.allCases.compactMap(content.branch(for:)).filter { !$0.wishes.isEmpty }
                    if !changes.isEmpty {
                        ifPlansChange(changes)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .foregroundStyle(Self.ink)
        .background(Self.paper)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityElement(children: .contain)
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(MissionType.display(30, relativeTo: .title))
            .tracking(0.6)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, stamp == nil ? 8 : 0)
            .accessibilityAddTraits(.isHeader)
    }

    private func topFive(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1)")
                        .font(MissionType.display(32, relativeTo: .title))
                        .foregroundStyle(LabourTheme.signal)
                        .frame(minWidth: 26, alignment: .leading)
                    Text(line)
                        .font(MissionType.body(18, relativeTo: .title3).weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .overlay(alignment: .top) { Rectangle().fill(Self.edge).frame(height: 1.5) }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func fields(_ answers: [PlanAnswer]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(answers.enumerated()), id: \.element.sectionID) { index, answer in
                VStack(alignment: .leading, spacing: 2) {
                    (Text("\(index + 1) · \(BirthPlanSection.title(for: answer.sectionID))".uppercased())
                        + Text(answer.decidedBy == .onTheDay ? " · DECIDE ON THE DAY" : "")
                        + Text(unchecked.contains(answer.sectionID) ? " · NOT CHECKED WITH HER" : "")
                        .foregroundStyle(Self.redInk))
                        .font(MissionType.mono())
                        .foregroundStyle(Self.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(answer.text.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(MissionType.body(15))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .overlay(alignment: .top) {
                    if index > 0 {
                        Rectangle().fill(Self.edge).frame(height: 1)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Self.ink, lineWidth: 1.5))
    }

    /// Her wishes if things change, boxed in red ink.
    private func ifPlansChange(_ branches: [PlanBranch]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("IF PLANS CHANGE")
                .font(MissionType.mono())
                .foregroundStyle(Self.redInk)
            ForEach(branches, id: \.scenario) { branch in
                VStack(alignment: .leading, spacing: 1) {
                    Text(branch.scenario.title)
                        .font(MissionType.body(15).weight(.bold))
                    Text(branch.wishes)
                        .font(MissionType.body(15))
                        .lineSpacing(2)
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Self.redInk, lineWidth: 2))
    }
}

/// His sticky note, as the prototype puts it beside the sheet: his job if plans change, how to
/// ask questions, and theatre. From the plan and the coaching content.
private struct AdvocateNote: View {
    @Environment(AppModel.self) private var model
    var branches: [PlanBranch]

    var body: some View {
        let speakUp = model.library.coaching.first { $0.id == "coaching.established.speak-up" }
        let theatre = model.library.coaching.first { $0.id == "coaching.theatre.caesarean" }
        let jobs = branches.filter { !$0.hisJob.isEmpty }
        VStack(alignment: .leading, spacing: 6) {
            Text("IF THE PLAN CHANGES")
                .font(MissionType.mono())
                .tracking(1.3)
                .foregroundStyle(LabourTheme.navy.opacity(0.7))
            Text("Plans change for lots of good reasons. It's still her choice at every step.")
                .font(MissionType.body(14).weight(.semibold))
            ForEach(jobs, id: \.scenario) { branch in
                Text("\(branch.scenario.title). Your job: \(branch.hisJob)")
                    .font(MissionType.body(14))
            }
            ForEach(speakUp?.doThis.prefix(4).map { $0 } ?? [], id: \.self) { line in
                Text("• \(line)")
                    .font(MissionType.body(14))
            }
            if let theatre {
                Text(theatre.title)
                    .font(MissionType.body(14).weight(.bold))
                    .padding(.top, 4)
                ForEach([theatre.doThis.first, theatre.doThis.last].compactMap { $0 }, id: \.self) { line in
                    Text(line)
                        .font(MissionType.body(14))
                }
            }
        }
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(LabourTheme.navy)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Rectangle().fill(LabourTheme.sun))
        .rotationEffect(.degrees(1.2))
        .padding(.leading, 30)
        .accessibilityElement(children: .combine)
    }
}

/// Labour settings, at the foot of the plan: when to call (a midwife's own numbers), the hospital
/// and her details. The prototype's top row has no room for it next to 999.
private struct LabourSettingsLink: View {
    var body: some View {
        NavigationLink {
            LabourSettingsView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Labour settings")
                        .font(MissionType.body(15).weight(.semibold))
                    Text("When to call, the hospital, her details")
                        .font(MissionType.body(13, relativeTo: .footnote))
                        .foregroundStyle(LabourTheme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(LabourTheme.muted)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(LabourTheme.cream)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize + 8)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(LabourTheme.cream.opacity(0.3), lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
