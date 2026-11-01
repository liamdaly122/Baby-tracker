import MissionCore
import SwiftUI

/// On the home screen once he has said how things ended: the baby's details, or after a loss only
/// support. Plain words, no countdown and no LAUNCH.
struct OutcomeHome: View {
    @Environment(AppModel.self) private var model
    var record: OutcomeRecord
    @State private var confirmingUndo = false

    var body: some View {
        let outcome = record.outcome
        let heading = SupportDirectory.heading(for: outcome)
        VStack(alignment: .leading, spacing: 16) {
            if outcome == .loss {
                Text(heading.title).font(.largeTitle.bold())
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.babyName.isEmpty ? "Your baby" : record.babyName)
                        .font(.largeTitle.bold())
                    if let born = record.birthAt {
                        Text("Born \(born.formatted(date: .long, time: .shortened))")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                if outcome != .allWell {
                    Text(heading.title).font(.title2.bold())
                }
            }
            if !heading.detail.isEmpty, outcome != .allWell {
                Text(heading.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            SupportList(
                items: SupportDirectory.items(
                    for: outcome, region: model.profile.region, gestationalAgeDays: model.gestationalAgeDaysAtOutcome))
            Button("Recorded this by mistake?") { confirmingUndo = true }
                .font(.footnote)
                .confirmationDialog(
                    "Take this away?", isPresented: $confirmingUndo, titleVisibility: .visible
                ) {
                    Button("Take it away", role: .destructive) { model.clearOutcome() }
                    Button("Keep it", role: .cancel) {}
                } message: {
                    Text("The countdown and LAUNCH come back.")
                }
        }
    }
}

/// Support lines and pages, each with what it's for. Calls and links only when he taps them.
struct SupportList: View {
    var items: [SupportItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title).font(.headline)
                    Text(item.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 16) {
                        if let number = item.number, let url = number.telURL {
                            Link(destination: url) {
                                Label(number.display, systemImage: "phone")
                            }
                        }
                        if let link = item.link {
                            Link(destination: link) {
                                Label("Website", systemImage: "safari")
                            }
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .overlay(alignment: .top) { Divider() }
                .accessibilityElement(children: .contain)
            }
        }
    }
}

/// From home at any week: the baby has arrived, or something has happened.
struct SomethingHappenedView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var outcome: PregnancyOutcome?
    @State private var bornAt = Date()
    @State private var babyName = ""

    var body: some View {
        Form {
            if let outcome {
                if outcome == .loss {
                    Section {
                        Text("We're so sorry.").font(.title2.bold())
                        Text(
                            "This turns off the countdown, LAUNCH and the practice run, and shows support you can "
                                + "call, for when you want it. Nothing else changes, and you can undo it."
                        )
                        .foregroundStyle(.secondary)
                        Button("Turn them off") { record(.loss, birthAt: nil) }
                    }
                } else {
                    Section {
                        DatePicker("Born at", selection: $bornAt, in: ...Date())
                        TextField("Baby's name (optional)", text: $babyName)
                    } footer: {
                        Text("This turns off the countdown and LAUNCH.")
                    }
                    Section {
                        Button("Save") { record(outcome, birthAt: bornAt) }
                    }
                }
            } else {
                Section("How is everyone?") {
                    ForEach(PregnancyOutcome.allCases, id: \.self) { choice in
                        Button(choice.choice) { outcome = choice }
                    }
                }
            }
        }
        .navigationTitle("Something's happened")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func record(_ outcome: PregnancyOutcome, birthAt: Date?) {
        model.recordOutcome(outcome, birthAt: birthAt, babyName: babyName.trimmingCharacters(in: .whitespaces))
        dismiss()
    }
}
