import SwiftUI

/// A simple editor for the five headline preferences and the NHS sections. The guided builder and
/// printable PDF arrive in Phase 6.
struct BirthPlanEditor: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let plan = model.birthPlan
        Form {
            Section {
                ForEach(0..<5, id: \.self) { index in
                    TextField("Preference \(index + 1)", text: headline(index), axis: .vertical)
                }
            } header: {
                Text("The five that matter most")
            } footer: {
                Text(
                    "A birth plan is a list of preferences, not a contract. "
                        + "Things can change, and it's still her choice."
                )
            }
            ForEach(BirthPlanSection.allCases) { section in
                Section(section.title) {
                    TextField(section.prompt, text: sectionText(section), axis: .vertical)
                }
            }
        }
        .navigationTitle("Birth plan")
        .onDisappear {
            plan.updatedAt = Date()
            model.savePlanning()
        }
    }

    private func headline(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                let headlines = model.birthPlan.headlines
                return index < headlines.count ? headlines[index] : ""
            },
            set: { newValue in
                var headlines = model.birthPlan.headlines
                while headlines.count <= index {
                    headlines.append("")
                }
                headlines[index] = newValue
                model.birthPlan.headlines = headlines
            }
        )
    }

    private func sectionText(_ section: BirthPlanSection) -> Binding<String> {
        Binding(
            get: { model.birthPlan.sections[section] ?? "" },
            set: { newValue in
                var sections = model.birthPlan.sections
                sections[section] = newValue
                model.birthPlan.sections = sections
            }
        )
    }
}
