import MissionCore
import MissionUI
import SwiftUI

/// Her birth plan, edited as a draft: nothing changes until Save, and Discard leaves it as it was.
/// Each answer says whose decision it is, and anything he writes alone is his draft until she has
/// read it. The guided builder, the PDF and the review nudges come in Phase 6.
struct BirthPlanEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BirthPlanContent?
    @State private var isConfirmingDiscard = false
    @State private var isReadingWithHer = false

    var body: some View {
        if let draft {
            let hasChanges = !draft.changes(since: model.birthPlan.content).isEmpty
            form(draft, hasChanges: hasChanges)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(hasChanges)
                .toolbar {
                    if hasChanges {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Discard") { isConfirmingDiscard = true }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") { save(draft) }
                        }
                    }
                }
                .confirmationDialog(
                    "Discard your changes?", isPresented: $isConfirmingDiscard, titleVisibility: .visible
                ) {
                    Button("Discard changes", role: .destructive) { dismiss() }
                    Button("Keep editing", role: .cancel) {}
                }
                .sheet(isPresented: $isReadingWithHer) {
                    ReadWithHer { confirmed in
                        if confirmed {
                            model.birthPlan.confirmWithHer(in: model.planning.mainContext)
                            model.savePlanning()
                        }
                        isReadingWithHer = false
                    }
                }
        } else {
            // Something has to be on screen for onAppear to run.
            Color.clear.onAppear { draft = model.birthPlan.content }
        }
    }

    private func form(_ draft: BirthPlanContent, hasChanges: Bool) -> some View {
        PaperPage("Birth plan", subtitle: "Her plan, written together") {
            CheckedSection(hasChanges: hasChanges, isReadingWithHer: $isReadingWithHer)
            PaperSection(
                "The five that matter most",
                note: "A birth plan is a list of preferences, not a contract. Things can change, and it's still her "
                    + "choice. Write it together."
            ) {
                ForEach(0..<BirthPlanContent.maxTopFive, id: \.self) { index in
                    PaperField("\(index + 1)") {
                        TextField("", text: topFive(index), prompt: Text("Preference \(index + 1)"), axis: .vertical)
                    }
                }
            }
            PaperSection("Her plan") {
                ForEach(BirthPlanSection.allCases) { section in
                    PaperCard {
                        PaperLabel(section.title)
                        TextField("", text: answerText(section), prompt: Text(section.prompt), axis: .vertical)
                            .paperBox()
                            .accessibilityLabel(section.title)
                        if !(draft.answers.first { $0.sectionID == section.id }?.text.isEmpty ?? true) {
                            PaperLabel("Whose decision")
                            PaperChips(
                                PlanDecider.allCases, title: \.title,
                                isPicked: { $0 == decider(section).wrappedValue },
                                pick: { decider(section).wrappedValue = $0 })
                        }
                    }
                }
            }
            PaperSection(
                "If plans change",
                note: "Talk these through around 32 weeks. To ask about any change: Benefits, Risks, Alternatives, "
                    + "Intuition, and what if we do Nothing for now?"
            ) {
                ForEach(PlanScenario.allCases, id: \.self) { scenario in
                    PaperCard {
                        Text(scenario.title)
                            .font(MissionType.body(16).weight(.bold))
                        TextField("", text: branchWishes(scenario), prompt: Text(scenario.prompt), axis: .vertical)
                            .paperBox()
                            .accessibilityLabel(scenario.title)
                        TextField(
                            "", text: branchJob(scenario), prompt: Text("Your job: what you'll do or ask"),
                            axis: .vertical
                        )
                        .paperBox()
                        .accessibilityLabel("\(scenario.title): your job")
                    }
                }
            }
        }
    }

    private func save(_ draft: BirthPlanContent) {
        model.birthPlan.save(draft, in: model.planning.mainContext)
        model.savePlanning()
        self.draft = model.birthPlan.content
    }

    // MARK: Bindings into the draft

    private func topFive(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                let lines = draft?.topFive ?? []
                return index < lines.count ? lines[index] : ""
            },
            set: { newValue in
                var lines = draft?.topFive ?? []
                while lines.count <= index {
                    lines.append("")
                }
                lines[index] = newValue
                draft?.topFive = lines
            }
        )
    }

    private func answerText(_ section: BirthPlanSection) -> Binding<String> {
        Binding(
            get: { draft?.answers.first { $0.sectionID == section.id }?.text ?? "" },
            set: { newValue in
                // He's typing, so a new answer starts as his draft until she's seen it.
                let decidedBy = draft?.answers.first { $0.sectionID == section.id }?.decidedBy ?? .hisDraft
                draft?.setAnswer(section.id, text: newValue, decidedBy: decidedBy, at: Date())
            }
        )
    }

    private func decider(_ section: BirthPlanSection) -> Binding<PlanDecider> {
        Binding(
            get: { draft?.answers.first { $0.sectionID == section.id }?.decidedBy ?? .hisDraft },
            set: { newValue in
                let text = draft?.answers.first { $0.sectionID == section.id }?.text ?? ""
                draft?.setAnswer(section.id, text: text, decidedBy: newValue, at: Date())
            }
        )
    }

    private func branchWishes(_ scenario: PlanScenario) -> Binding<String> {
        Binding(
            get: { draft?.branches.first { $0.scenario == scenario }?.wishes ?? "" },
            set: { newValue in
                let job = draft?.branches.first { $0.scenario == scenario }?.hisJob ?? ""
                draft?.setBranch(scenario, wishes: newValue, hisJob: job, at: Date())
            }
        )
    }

    private func branchJob(_ scenario: PlanScenario) -> Binding<String> {
        Binding(
            get: { draft?.branches.first { $0.scenario == scenario }?.hisJob ?? "" },
            set: { newValue in
                let wishes = draft?.branches.first { $0.scenario == scenario }?.wishes ?? ""
                draft?.setBranch(scenario, wishes: wishes, hisJob: newValue, at: Date())
            }
        )
    }
}

/// Whether she has seen it, as the prototype's status line: when she last agreed it and what has
/// changed since, then the ways to check.
private struct CheckedSection: View {
    @Environment(AppModel.self) private var model
    var hasChanges: Bool
    @Binding var isReadingWithHer: Bool

    var body: some View {
        let plan = model.birthPlan
        let content = plan.content
        let changes = plan.changesSinceConfirmed(in: model.planning.mainContext)
        let unchecked = content.uncheckedAnswers(herConfirmedAt: plan.herConfirmedAt)
        VStack(alignment: .leading, spacing: 8) {
            if let confirmed = plan.herConfirmedAt {
                PaperNote(
                    "Checked with her on \(confirmed.formatted(date: .abbreviated, time: .omitted))".uppercased(),
                    tone: .good)
                if let changes, !changes.isEmpty {
                    PaperNote("Changed since: \(changes.map(\.description).joined(separator: ", ")).", tone: .warn)
                }
            } else if !content.isEmpty {
                PaperNote("Not checked with her yet".uppercased(), tone: .warn)
            }
            if !unchecked.isEmpty {
                let titles = unchecked.map { BirthPlanSection.title(for: $0.sectionID) }
                PaperNote("Your drafts: \(titles.joined(separator: ", ")).")
            }
            Button {
                isReadingWithHer = true
            } label: {
                Label("Read it through with her", systemImage: "person.2")
            }
            .buttonStyle(PaperButtonStyle(.solid))
            .disabled(hasChanges || content.isEmpty)
            HStack(spacing: 8) {
                if plan.herConfirmedAt != nil {
                    Button("Still right") {
                        plan.markReviewed(in: model.planning.mainContext)
                        model.savePlanning()
                    }
                    .buttonStyle(PaperButtonStyle(.ghost))
                    .disabled(hasChanges)
                    .accessibilityLabel("Looked at it again: still right")
                }
                ShareLink(item: content.plainText(motherName: model.profile.motherName)) {
                    Label("Send it to her", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PaperButtonStyle(.ghost))
                .disabled(hasChanges || content.isEmpty)
            }
            if hasChanges {
                PaperNote("Save your changes first.")
            } else if let reviewed = plan.reviewedAt {
                PaperNote("Last looked at \(reviewed.formatted(date: .abbreviated, time: .omitted)).")
            }
        }
    }
}

/// The plan exactly as the midwife will see it, for her to read. Only she can say it's right.
private struct ReadWithHer: View {
    @Environment(AppModel.self) private var model
    var onFinish: (_ confirmed: Bool) -> Void

    var body: some View {
        NavigationStack {
            PaperPage("Read it with her", subtitle: "Hand her the phone") {
                Text("This is what the midwife will see.")
                    .font(MissionType.body(16).weight(.semibold))
                let content = model.birthPlan.content
                PlanSheet(content: content, motherName: model.profile.motherName)
                let jobs = PlanScenario.allCases.compactMap(content.branch(for:)).filter { !$0.hisJob.isEmpty }
                if !jobs.isEmpty {
                    PaperSection("His jobs if plans change") {
                        ForEach(jobs, id: \.scenario) { branch in
                            PaperNote("\(branch.scenario.title): \(branch.hisJob)")
                        }
                    }
                }
                Button("She's happy with it") { onFinish(true) }
                    .buttonStyle(PaperButtonStyle(.solid))
                    .padding(.top, 6)
                Button("She wants changes") { onFinish(false) }
                    .buttonStyle(PaperButtonStyle(.ghost))
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
