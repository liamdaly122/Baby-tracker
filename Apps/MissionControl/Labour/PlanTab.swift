import MissionCore
import MissionUI
import SwiftUI

/// The birth plan on one screen, large enough to hold up to a midwife.
struct PlanTab: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let plan = model.birthPlan
        let headlines = plan.headlines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let sections = plan.sections
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if plan.isEmpty {
                    emptyState
                } else {
                    if !model.profile.motherName.isEmpty {
                        Text("\(model.profile.motherName)'s birth preferences")
                            .font(.title2.bold())
                            .foregroundStyle(LabourTheme.primaryText)
                    }
                    ForEach(Array(headlines.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.title.bold().monospacedDigit())
                                .foregroundStyle(LabourTheme.amber)
                            Text(line)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(LabourTheme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    ForEach(BirthPlanSection.allCases) { section in
                        if let text = sections[section], !text.trimmingCharacters(in: .whitespaces).isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(section.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(LabourTheme.secondaryText)
                                Text(text)
                                    .font(.title3)
                                    .foregroundStyle(LabourTheme.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                PlanChangedCard()
                NavigationLink("Edit the birth plan") { BirthPlanEditor() }
                    .frame(minHeight: 44)
            }
            .padding(16)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No birth plan yet")
                .font(.title2.bold())
                .foregroundStyle(LabourTheme.primaryText)
            Text("Add the five things that matter most to her. You can do it now; it takes a minute.")
                .foregroundStyle(LabourTheme.secondaryText)
        }
    }
}

/// What to ask when things don't go to plan: induction, an epidural, theatre.
private struct PlanChangedCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let speakUp = model.library.coaching.first { $0.id == "coaching.established.speak-up" }
        let theatre = model.library.coaching.first { $0.id == "coaching.theatre.caesarean" }
        VStack(alignment: .leading, spacing: 10) {
            Text("If the plan changes")
                .font(.headline)
                .foregroundStyle(LabourTheme.amber)
            Text("Plans change for lots of good reasons. It's still her choice at every step.")
                .foregroundStyle(LabourTheme.primaryText)
            ForEach(speakUp?.doThis.prefix(4).map { $0 } ?? [], id: \.self) { line in
                Label(line, systemImage: "bubble.left.fill")
                    .foregroundStyle(LabourTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let theatre {
                Text(theatre.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LabourTheme.secondaryText)
                    .padding(.top, 4)
                ForEach([theatre.doThis.first, theatre.doThis.last].compactMap { $0 }, id: \.self) { line in
                    Text(line)
                        .font(.callout)
                        .foregroundStyle(LabourTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LabourTheme.surface))
    }
}
