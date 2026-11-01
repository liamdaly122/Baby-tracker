import MissionCore
import MissionUI
import SwiftUI

/// The birth plan as one printed sheet, large enough to hold up to a midwife. Read-only: there's
/// no editor in labour mode, so nothing in it can be changed by mistake mid-labour.
struct PlanTab: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let plan = model.birthPlan
        let content = plan.content
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LabourTabHeader(
                    world: .plan, eyebrow: "Her plan", title: "Show the midwife",
                    subtitle: "Read-only in labour. Turn the phone round.")
                if !content.isEmpty {
                    CheckedWithHerLine(plan: plan)
                }
                PlanSheet(
                    content: content, motherName: model.profile.motherName,
                    unchecked: Set(content.uncheckedAnswers(herConfirmedAt: plan.herConfirmedAt).map(\.sectionID)))
                PlanChangedCard(branches: PlanScenario.allCases.compactMap(content.branch(for:)))
            }
            .padding(16)
        }
    }
}

/// When she last agreed the plan, and what has changed since, so he never shows a midwife
/// something she hasn't seen as if it were hers.
private struct CheckedWithHerLine: View {
    @Environment(AppModel.self) private var model
    var plan: BirthPlan

    var body: some View {
        let changes = plan.changesSinceConfirmed(in: model.planning.mainContext) ?? []
        VStack(alignment: .leading, spacing: 4) {
            if let confirmed = plan.herConfirmedAt {
                Label(
                    "Checked with her on \(confirmed.formatted(date: .abbreviated, time: .omitted)).",
                    systemImage: "checkmark.seal.fill"
                )
                .font(.headline)
                if !changes.isEmpty {
                    Text("Changed since: \(changes.map(\.description).joined(separator: ", ")).")
                        .font(.subheadline)
                        .foregroundStyle(LabourTheme.amber)
                }
            } else {
                Label("Not checked with her yet. Ask her before you show it.", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundStyle(LabourTheme.amber)
            }
        }
        .foregroundStyle(LabourTheme.primaryText)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

/// The plan on paper: her top five, then each section. Used in labour and when he reads it
/// through with her, so she agrees exactly what the midwife will see.
struct PlanSheet: View {
    var content: BirthPlanContent
    var motherName: String
    /// Sections that are his draft and not checked with her.
    var unchecked: Set<String> = []

    static let paper = LabourPalette.paper.color
    static let ink = LabourPalette.ink.color
    static let redInk = LabourPalette.redInk.color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("BIRTH PLAN")
                Spacer()
                Text(motherName.isEmpty ? "HER PREFERENCES" : motherName.uppercased())
            }
            .font(.caption2.weight(.semibold).monospaced())
            .tracking(1)
            .foregroundStyle(Self.paper)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Self.ink)
            if content.isEmpty {
                Text("No plan saved")
                    .font(.title.bold())
                    .padding(.horizontal, 16)
                Text(
                    "When there's a calm moment, ask her for the one or two things that matter most, "
                        + "and tell the midwife."
                )
                .font(.title3)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            } else {
                if !content.filledTopFive.isEmpty {
                    topFive(content.filledTopFive)
                }
                let answers = BirthPlanSection.allCases.compactMap { content.answer(for: $0.id) }
                if !answers.isEmpty {
                    fields(answers)
                }
                Spacer(minLength: 4)
            }
        }
        .padding(.bottom, 12)
        .foregroundStyle(Self.ink)
        .background(RoundedRectangle(cornerRadius: 4).fill(Self.paper))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.45), radius: 14, y: 10)
        .accessibilityElement(children: .contain)
    }

    private func topFive(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What matters most to her")
                .font(.title2.bold())
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.title.bold().monospacedDigit())
                            .foregroundStyle(Self.redInk)
                            .frame(width: 26, alignment: .leading)
                        Text(line)
                            .font(.title3.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .overlay(alignment: .top) { Rectangle().fill(Self.ink.opacity(0.15)).frame(height: 1) }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func fields(_ answers: [PlanAnswer]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(answers, id: \.sectionID) { answer in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(BirthPlanSection.title(for: answer.sectionID).uppercased())
                            .foregroundStyle(Self.ink.opacity(0.6))
                        if answer.decidedBy == .onTheDay {
                            Text("· DECIDE ON THE DAY").foregroundStyle(Self.ink.opacity(0.6))
                        }
                        if unchecked.contains(answer.sectionID) {
                            Text("· NOT CHECKED WITH HER").foregroundStyle(Self.redInk)
                        }
                    }
                    .font(.caption2.weight(.semibold).monospaced())
                    Text(answer.text.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .overlay(alignment: .top) { Rectangle().fill(Self.ink.opacity(0.15)).frame(height: 1) }
                .accessibilityElement(children: .combine)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Self.ink, lineWidth: 1.5))
        .padding(.horizontal, 16)
    }
}

/// What to do when things don't go to plan: her own wishes for each change first, then how to
/// ask questions, and theatre.
private struct PlanChangedCard: View {
    @Environment(AppModel.self) private var model
    var branches: [PlanBranch]

    var body: some View {
        let speakUp = model.library.coaching.first { $0.id == "coaching.established.speak-up" }
        let theatre = model.library.coaching.first { $0.id == "coaching.theatre.caesarean" }
        VStack(alignment: .leading, spacing: 10) {
            Text("IF THE PLAN CHANGES")
                .font(.caption.weight(.bold).monospaced())
                .tracking(1)
            Text("Plans change for lots of good reasons. It's still her choice at every step.")
                .font(.body.weight(.semibold))
            ForEach(branches, id: \.scenario) { branch in
                VStack(alignment: .leading, spacing: 2) {
                    Text(branch.scenario.title)
                        .font(.subheadline.weight(.bold))
                    if !branch.wishes.isEmpty {
                        Text(branch.wishes)
                            .font(.callout)
                    }
                    if !branch.hisJob.isEmpty {
                        Text("Your job: \(branch.hisJob)")
                            .font(.callout.italic())
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
            }
            ForEach(speakUp?.doThis.prefix(4).map { $0 } ?? [], id: \.self) { line in
                Label(line, systemImage: "bubble.left.fill")
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let theatre {
                Text(theatre.title)
                    .font(.subheadline.weight(.bold))
                    .padding(.top, 4)
                ForEach([theatre.doThis.first, theatre.doThis.last].compactMap { $0 }, id: \.self) { line in
                    Text(line)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(PlanSheet.ink)
        .background(Rectangle().fill(LabourTheme.amber))
        .rotationEffect(.degrees(0.8))
        .shadow(color: .black.opacity(0.35), radius: 8, y: 6)
    }
}
