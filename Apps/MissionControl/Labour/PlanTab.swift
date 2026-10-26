import MissionCore
import MissionUI
import SwiftUI

/// The birth plan as one printed sheet, large enough to hold up to a midwife. Read-only here.
struct PlanTab: View {
    @Environment(AppModel.self) private var model
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.89)
    static let ink = Color(red: 0.11, green: 0.13, blue: 0.28)
    static let redInk = Color(red: 0.7, green: 0.19, blue: 0.11)

    var body: some View {
        let plan = model.birthPlan
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LabourTabHeader(
                    world: .plan, eyebrow: "Her plan", title: "Show the midwife",
                    subtitle: "Read-only in labour. Turn the phone round.")
                sheet(plan)
                PlanChangedCard()
                NavigationLink("Edit the birth plan") { BirthPlanEditor() }
                    .frame(minHeight: 44)
                    .foregroundStyle(LabourWorld.plan.accent)
            }
            .padding(16)
        }
    }

    private func sheet(_ plan: BirthPlanRecord) -> some View {
        let headlines = plan.headlines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let sections = BirthPlanSection.allCases.compactMap { section -> (BirthPlanSection, String)? in
            guard let text = plan.sections[section], !text.trimmingCharacters(in: .whitespaces).isEmpty else {
                return nil
            }
            return (section, text)
        }
        let name = model.profile.motherName
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("BIRTH PLAN")
                Spacer()
                Text(name.isEmpty ? "HER PREFERENCES" : name.uppercased())
            }
            .font(.caption2.weight(.semibold).monospaced())
            .tracking(1)
            .foregroundStyle(Self.paper)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Self.ink)
            if plan.isEmpty {
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
                if !headlines.isEmpty {
                    topFive(headlines)
                }
                if !sections.isEmpty {
                    fields(sections)
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

    private func topFive(_ headlines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What matters most to her")
                .font(.title2.bold())
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(headlines.enumerated()), id: \.offset) { index, line in
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

    private func fields(_ sections: [(BirthPlanSection, String)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(sections, id: \.0) { section, text in
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title.uppercased())
                        .font(.caption2.weight(.semibold).monospaced())
                        .foregroundStyle(Self.ink.opacity(0.6))
                    Text(text)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .overlay(alignment: .top) { Rectangle().fill(Self.ink.opacity(0.15)).frame(height: 1) }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Self.ink, lineWidth: 1.5))
        .padding(.horizontal, 16)
    }
}

/// What to ask when things don't go to plan: induction, an epidural, theatre.
private struct PlanChangedCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let speakUp = model.library.coaching.first { $0.id == "coaching.established.speak-up" }
        let theatre = model.library.coaching.first { $0.id == "coaching.theatre.caesarean" }
        VStack(alignment: .leading, spacing: 10) {
            Text("IF THE PLAN CHANGES")
                .font(.caption.weight(.bold).monospaced())
                .tracking(1)
            Text("Plans change for lots of good reasons. It's still her choice at every step.")
                .font(.body.weight(.semibold))
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
        .foregroundStyle(PlanTab.ink)
        .background(Rectangle().fill(LabourTheme.amber))
        .rotationEffect(.degrees(0.8))
        .shadow(color: .black.opacity(0.35), radius: 8, y: 6)
    }
}
