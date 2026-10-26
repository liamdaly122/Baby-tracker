import MissionContent
import MissionCore
import SwiftUI

/// When to call, within safe bounds. The limits mean the app can never tell you to wait longer
/// than the NHS urgent rules.
struct ThresholdEditor: View {
    @Environment(AppModel.self) private var model
    @State private var notes: [ThresholdField: String] = [:]

    private struct Editable {
        var field: ThresholdField
        var label: String
        var step: Double
    }

    private static let editable: [Editable] = [
        Editable(field: .adviceIntervalSec, label: "Call when contractions come every", step: 30),
        Editable(field: .adviceDurationSec, label: "and last at least", step: 5),
        Editable(field: .patternWindowSec, label: "Wait at that rate before calling", step: 300),
        Editable(field: .urgentSingleDurationSec, label: "Call now if one lasts longer than", step: 15),
        Editable(field: .urgentCountIn10Min, label: "Call now at this many in 10 minutes", step: 1),
        Editable(field: .regularityCV, label: "How even the gaps must be", step: 0.05),
    ]

    var body: some View {
        let table = model.thresholdTable
        let profile = table.profile(applying: model.profile.thresholdOverrides)
        Form {
            Section {
                ForEach(Self.editable, id: \.field) { item in
                    let limit = table.limit(for: item.field)
                    if limit.isEditable {
                        row(
                            field: item.field, label: item.label, step: item.step, limit: limit,
                            value: profile[item.field])
                    }
                }
            } footer: {
                Text(
                    "Your midwife may give you different advice. Use theirs. "
                        + "The limits stop the app from ever waiting longer than the NHS urgent rules."
                )
            }
            Section {
                Button("Reset to defaults", role: .destructive) {
                    model.profile.thresholdOverrides = [:]
                    model.savePlanning()
                }
                if model.labour.isActive {
                    Button("Use these for this labour") {
                        model.labour.applyThresholds(model.currentThresholds)
                        model.savePlanning()
                    }
                }
            } footer: {
                if model.labour.isActive {
                    Text("Changes apply to the next labour unless you choose to use them now.")
                }
            }
        }
        .navigationTitle("When to call")
        .task {
            let file = try? BundledContent.envelope(ThresholdItem.self, kind: .thresholds, region: model.profile.region)
            notes = Dictionary(uniqueKeysWithValues: (file?.items ?? []).map { ($0.id, $0.note) })
        }
    }

    @ViewBuilder
    private func row(field: ThresholdField, label: String, step: Double, limit: ThresholdLimit, value: Double)
        -> some View
    {
        VStack(alignment: .leading, spacing: 6) {
            if limit.allowsDisabled {
                Toggle(
                    label,
                    isOn: Binding(
                        get: { value > 0 },
                        set: { setOverride(field, $0 ? limit.min : 0) }
                    )
                )
            }
            if !limit.allowsDisabled || value > 0 {
                Stepper(
                    value: Binding(get: { value }, set: { setOverride(field, $0) }),
                    in: limit.min...limit.max,
                    step: step
                ) {
                    LabeledContent(limit.allowsDisabled ? "For" : label, value: display(field, value))
                }
            }
            if model.thresholdTable.delaysAdvice(field, value: value) {
                Label(
                    "Only if your midwife told you to: this makes the app suggest calling later.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }
            if let note = notes[field] {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func setOverride(_ field: ThresholdField, _ value: Double) {
        var overrides = model.profile.thresholdOverrides
        overrides[field] = model.thresholdTable.limit(for: field).clamp(value)
        model.profile.thresholdOverrides = overrides
        model.savePlanning()
    }

    private func display(_ field: ThresholdField, _ value: Double) -> String {
        switch field {
        case .urgentCountIn10Min: "\(Int(value))"
        case .regularityCV: String(format: "%.2f", value)
        default: StateCopy.phrase(seconds: value)
        }
    }
}
