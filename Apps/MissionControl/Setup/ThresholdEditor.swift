import MissionContent
import MissionCore
import SwiftUI

/// When to call, within safe bounds. The limits mean the app can never tell you to wait longer
/// than the NHS urgent rules.
struct ThresholdEditor: View {
    @Environment(AppModel.self) private var model
    @State private var notes: [ThresholdField: String] = [:]

    private static let editable: [(ThresholdField, String, Double)] = [
        (.adviceIntervalSec, "Call when contractions come every", 30),
        (.adviceDurationSec, "and last at least", 5),
        (.patternWindowSec, "for", 300),
        (.urgentSingleDurationSec, "Call now if one lasts longer than", 15),
        (.urgentCountIn10Min, "Call now at this many in 10 minutes", 1),
        (.regularityCV, "How even the gaps must be", 0.05),
    ]

    var body: some View {
        let table = model.thresholdTable
        let profile = table.profile(applying: model.profile.thresholdOverrides)
        Form {
            Section {
                ForEach(Self.editable, id: \.0) { field, label, step in
                    let limit = table.limit(for: field)
                    if limit.isEditable {
                        row(field: field, label: label, step: step, limit: limit, value: profile[field])
                    }
                }
            } footer: {
                Text(
                    "Your midwife may give you different advice. Use theirs. The limits stop the app from ever waiting longer than the NHS urgent rules."
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
                    LabeledContent(limit.allowsDisabled ? "Duration" : label, value: display(field, value))
                }
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
