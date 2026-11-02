import MissionCore
import MissionUI
import SwiftUI

/// "Your data": what the app keeps and where, in plain words, and "Delete everything". From the
/// home screen only, never in labour mode. The full policy is drafted in `docs/privacy-policy.md`;
/// a link to it goes here once it's online.
struct YourDataView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var asking = false
    @State private var askingAgain = false
    @State private var failed = false

    var body: some View {
        PaperPage("Your data", subtitle: "On this phone and watch only") {
            PrivacySummary()
            PaperSection("Delete everything", note: DeleteEverything.note) {
                Button("Delete everything") { asking = true }
                    .buttonStyle(PaperButtonStyle(.danger))
                    // On the button, so the question opens from it rather than the top of the page.
                    .confirmationDialog("Delete everything?", isPresented: $asking, titleVisibility: .visible) {
                        Button("Delete everything", role: .destructive) { askingAgain = true }
                        Button("Keep it", role: .cancel) {}
                    } message: {
                        Text(DeleteEverything.note)
                    }
                if failed {
                    PaperNote("Couldn't delete everything. Try again, or delete the app.", tone: .bad)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // Asked twice: there's no getting any of it back.
        .alert("Are you sure?", isPresented: $askingAgain) {
            Button("Delete", role: .destructive, action: delete)
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("It can't be undone.")
        }
    }

    private func delete() {
        do {
            try model.deleteEverything()
            dismiss()
        } catch {
            failed = true
        }
    }
}

/// What "Delete everything" removes, as he reads it before deciding.
enum DeleteEverything {
    static let note =
        "Deletes the due date, her details, the hospitals, the people to call, her birth plan, how things "
        + "ended and every labour log, from this phone and your Apple Watch. Copies in old backups stay "
        + "until those backups are deleted."
}

/// The privacy promise in a few lines: what's kept, where, and what leaves the phone.
struct PrivacySummary: View {
    var body: some View {
        PaperSection("Where it's kept") {
            line(
                "Everything you add stays on this iPhone and your Apple Watch. There are no accounts, servers, "
                    + "adverts or tracking, and the app itself never goes online.")
            line(
                "Her details, the hospitals, the people to call and her birth plan are in your iPhone's backup, if "
                    + "backups are on. The labour log isn't.")
        }
        PaperSection("What leaves the phone", note: "Only when you tap:") {
            line("Calls and texts, through your phone's own apps.")
            line("Directions, through Apple Maps.")
            line("Her birth plan or a message, when you share it.")
            line("NHS and charity pages, in your web browser.")
        }
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .font(MissionType.body(15))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
