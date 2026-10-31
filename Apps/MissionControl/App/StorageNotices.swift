import MissionUI
import SwiftUI

/// On the home screen when something isn't being kept: what still works and what to do. Labour
/// mode always works, whichever store failed.
struct StorageNotices: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ForEach(notices, id: \.title) { notice in
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(notice.title).font(.headline)
                    Text(notice.detail).font(.subheadline).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.orange.opacity(0.12)))
            .accessibilityElement(children: .combine)
        }
    }

    private var notices: [(title: String, detail: String)] {
        let fix = "Restarting the phone or freeing up some space usually fixes this."
        var notices: [(title: String, detail: String)] = []
        if model.planningUnavailable {
            let numbers =
                model.restoredFromCard
                ? "Labour mode works, using the last saved copy of the hospital and its numbers."
                : "Labour mode works, but add the hospital's number again under Mission profile."
            notices.append(
                ("Your saved details couldn't be opened", "\(numbers) Changes made now won't be kept. \(fix)"))
        } else if model.planningSaveFailed {
            notices.append(
                ("Changes aren't being saved", "Free up some space on this phone, then make the change again."))
        }
        if model.session.storeIsTemporary {
            let detail = "It still times contractions, but write the times down. \(fix)"
            notices.append(("Labour mode can't save on this phone", detail))
        }
        return notices
    }
}

/// On every labour screen while taps aren't being saved. The timer still works.
struct NotSavingBar: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("NOT SAVING · WRITE THE TIMES DOWN")
                    .font(.caption.weight(.heavy).monospaced())
                    .foregroundStyle(LabourTheme.amber)
                Text("The timer still works, but if the app closes these times are lost.")
                    .font(.caption)
                    .foregroundStyle(LabourTheme.primaryText)
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(LabourTheme.amber)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(LabourTheme.raisedSurface)
        .accessibilityElement(children: .combine)
    }
}
