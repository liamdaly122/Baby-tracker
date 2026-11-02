import MissionContent
import MissionCore
import MissionUI
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
        PaperPage("When to call", subtitle: "NHS defaults, or your midwife's advice") {
            PaperNote(
                "Your midwife may give you different advice. Use theirs. The limits stop the app from ever waiting "
                    + "longer than the NHS urgent rules.")
            ForEach(Self.editable, id: \.field) { item in
                let limit = table.limit(for: item.field)
                if limit.isEditable {
                    row(field: item.field, label: item.label, step: item.step, limit: limit, value: profile[item.field])
                }
            }
            if model.labour.isActive {
                Button("Use these for this labour") {
                    model.labour.applyThresholds(model.currentThresholds)
                    model.savePlanning()
                }
                .buttonStyle(PaperButtonStyle(.solid))
                PaperNote("Changes apply to the next labour unless you choose to use them now.")
            }
            Button("Reset to defaults") {
                model.profile.thresholdOverrides = [:]
                model.savePlanning()
            }
            .buttonStyle(PaperButtonStyle(.danger))
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let file = try? BundledContent.envelope(ThresholdItem.self, kind: .thresholds, region: model.profile.region)
            notes = Dictionary(uniqueKeysWithValues: (file?.items ?? []).map { ($0.id, $0.note) })
        }
    }

    /// One threshold on its card: on or off where it can be off, the value with − and +, a
    /// warning if it makes the app suggest calling later, and the source's note.
    private func row(field: ThresholdField, label: String, step: Double, limit: ThresholdLimit, value: Double)
        -> some View
    {
        PaperCard {
            if limit.allowsDisabled {
                PaperTick(
                    label,
                    isOn: Binding(get: { value > 0 }, set: { setOverride(field, $0 ? limit.min : 0) }))
            }
            if !limit.allowsDisabled || value > 0 {
                PaperStepper(
                    limit.allowsDisabled ? "For" : label, value: display(field, value),
                    canDecrease: value - step >= limit.min - 0.0001, canIncrease: value + step <= limit.max + 0.0001,
                    decrease: { setOverride(field, value - step) }, increase: { setOverride(field, value + step) })
            }
            if model.thresholdTable.delaysAdvice(field, value: value) {
                PaperNote("Only if your midwife told you to: this makes the app suggest calling later.", tone: .warn)
            }
            if let note = notes[field] {
                PaperNote(note)
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
