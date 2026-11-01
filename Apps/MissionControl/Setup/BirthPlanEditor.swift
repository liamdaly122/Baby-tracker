import MissionCore
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
                .navigationTitle("Birth plan")
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
        Form {
            CheckedSection(hasChanges: hasChanges, isReadingWithHer: $isReadingWithHer)
            Section {
                ForEach(0..<BirthPlanContent.maxTopFive, id: \.self) { index in
                    TextField("Preference \(index + 1)", text: topFive(index), axis: .vertical)
                }
            } header: {
                Text("The five that matter most")
            } footer: {
                Text(
                    "A birth plan is a list of preferences, not a contract. Things can change, and it's still "
                        + "her choice. Write it together."
                )
            }
            ForEach(BirthPlanSection.allCases) { section in
                Section(section.title) {
                    TextField(section.prompt, text: answerText(section), axis: .vertical)
                    if !(draft.answers.first { $0.sectionID == section.id }?.text.isEmpty ?? true) {
                        Picker("Whose decision", selection: decider(section)) {
                            ForEach(PlanDecider.allCases, id: \.self) { decider in
                                Text(decider.title).tag(decider)
                            }
                        }
                    }
                }
            }
            Section {
                ForEach(PlanScenario.allCases, id: \.self) { scenario in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(scenario.title).font(.headline)
                        TextField(scenario.prompt, text: branchWishes(scenario), axis: .vertical)
                        TextField("Your job: what you'll do or ask", text: branchJob(scenario), axis: .vertical)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("If plans change")
            } footer: {
                Text(
                    "Talk these through around 32 weeks. To ask about any change: Benefits, Risks, Alternatives, "
                        + "Intuition, and what if we do Nothing for now?"
                )
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

/// Whether she has seen it: when she last agreed it, what changed since, and the ways to check.
private struct CheckedSection: View {
    @Environment(AppModel.self) private var model
    var hasChanges: Bool
    @Binding var isReadingWithHer: Bool

    var body: some View {
        let plan = model.birthPlan
        let content = plan.content
        let changes = plan.changesSinceConfirmed(in: model.planning.mainContext)
        let unchecked = content.uncheckedAnswers(herConfirmedAt: plan.herConfirmedAt)
        Section {
            if let confirmed = plan.herConfirmedAt {
                Label(
                    "Checked with her on \(confirmed.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "checkmark.seal.fill"
                )
                .foregroundStyle(.green)
                if let changes, !changes.isEmpty {
                    Text("Changed since: \(changes.map(\.description).joined(separator: ", ")).")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            } else if !content.isEmpty {
                Label("Not checked with her yet", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            if !unchecked.isEmpty {
                let titles = unchecked.map { BirthPlanSection.title(for: $0.sectionID) }
                Text("Your drafts: \(titles.joined(separator: ", ")).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button {
                isReadingWithHer = true
            } label: {
                Label("Read it through with her", systemImage: "person.2")
            }
            .disabled(hasChanges || content.isEmpty)
            if plan.herConfirmedAt != nil {
                Button {
                    plan.markReviewed(in: model.planning.mainContext)
                    model.savePlanning()
                } label: {
                    Label("Looked at it again: still right", systemImage: "checkmark")
                }
                .disabled(hasChanges)
            }
            ShareLink(item: content.plainText(motherName: model.profile.motherName)) {
                Label("Send it to her as text", systemImage: "square.and.arrow.up")
            }
            .disabled(hasChanges || content.isEmpty)
        } header: {
            Text("Checked with her")
        } footer: {
            if hasChanges {
                Text("Save your changes first.")
            } else if let reviewed = plan.reviewedAt {
                Text("Last looked at \(reviewed.formatted(date: .abbreviated, time: .omitted)).")
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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Hand her the phone. This is what the midwife will see.")
                        .font(.headline)
                    let content = model.birthPlan.content
                    PlanSheet(content: content, motherName: model.profile.motherName)
                    let branches = PlanScenario.allCases.compactMap(content.branch(for:))
                    if !branches.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("If plans change").font(.title3.bold())
                            ForEach(branches, id: \.scenario) { branch in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(branch.scenario.title).font(.headline)
                                    if !branch.wishes.isEmpty {
                                        Text(branch.wishes)
                                    }
                                    if !branch.hisJob.isEmpty {
                                        Text("His job: \(branch.hisJob)").italic()
                                    }
                                }
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    Button {
                        onFinish(true)
                    } label: {
                        Text("She's happy with it")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        onFinish(false)
                    } label: {
                        Text("She wants changes")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(16)
            }
            .navigationTitle("Read it with her")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
