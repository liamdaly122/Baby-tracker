import MissionCore
import SwiftData
import SwiftUI

/// Where she's booked, and a backup. Each opens its own form.
struct BirthPlacesView: View {
    @Environment(AppModel.self) private var model
    @Query private var places: [BirthPlace]

    var body: some View {
        let booked = places.first { $0.role == .booked }
        let backup = places.first { $0.role == .backup }
        Form {
            Section {
                NavigationLink {
                    BirthPlaceForm(role: .booked)
                } label: {
                    PlaceSummary(place: booked, empty: "Add where she's booked")
                }
            } header: {
                Text("Where she's booked")
            } footer: {
                Text("The Call tab rings this unit first.")
            }
            Section {
                NavigationLink {
                    BirthPlaceForm(role: .backup)
                } label: {
                    PlaceSummary(place: backup, empty: "Add a backup")
                }
            } header: {
                Text("Backup")
            } footer: {
                Text(
                    booked?.kind.needsTransferUnit == true
                        ? "A birth centre on its own has no doctors. Add the hospital it transfers to."
                        : "Another unit nearby, in case they're full and send you elsewhere."
                )
            }
        }
        .navigationTitle("Hospital or birth centre")
    }
}

/// A place's name and whether its numbers have been checked against her notes.
private struct PlaceSummary: View {
    @Environment(AppModel.self) private var model
    var place: BirthPlace?
    var empty: String

    var body: some View {
        if let place, !place.isBlank {
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name.isEmpty ? place.kind.title : place.name)
                CheckStatus(place: place, calendar: model.profile.pregnancyCalendar)
            }
        } else {
            Text(empty).foregroundStyle(.secondary)
        }
    }
}

/// "Checked against her notes on 31 Oct", or a prompt to check them.
struct CheckStatus: View {
    var place: BirthPlace
    var calendar: PregnancyCalendar?

    var body: some View {
        if let checked = place.numbersCheckedAt, !place.numbersNeedChecking(calendar: calendar, now: Date()) {
            Label("Numbers checked \(checked.formatted(date: .abbreviated, time: .omitted))", systemImage: "checkmark")
                .font(.footnote)
                .foregroundStyle(.green)
        } else {
            Label(
                place.numbersCheckedAt == nil
                    ? "Numbers not checked against her notes" : "34 weeks: check the numbers again",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.footnote)
            .foregroundStyle(.orange)
        }
    }
}

/// One place: what kind it is, the numbers from her notes, and getting there.
struct BirthPlaceForm: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let role: BirthPlaceRole
    @State private var place: BirthPlace?
    /// "Remove the backup" was tapped: it's deleted once the screen has gone.
    @State private var isRemoving = false

    var body: some View {
        if let place {
            form(place)
                .navigationTitle(role == .booked ? "Where she's booked" : "Backup")
                .onDisappear {
                    // Removed, or nothing typed in: don't keep it.
                    if isRemoving || place.isBlank {
                        model.removePlace(place)
                    } else {
                        model.savePlanning()
                    }
                    model.labour.refresh()
                }
        } else {
            // Something has to be on screen for onAppear to run.
            Color.clear.onAppear { place = model.editablePlace(role) }
        }
    }

    private func form(_ place: BirthPlace) -> some View {
        @Bindable var place = place
        let region = model.profile.region
        return Form {
            Section {
                Picker("Kind", selection: $place.kind) {
                    ForEach(BirthPlaceKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                TextField("Name, as on her notes", text: $place.name)
                TextField("Address or postcode", text: $place.address, axis: .vertical)
                    .textContentType(.fullStreetAddress)
                if let directions = place.directionsURL {
                    Link(destination: directions) {
                        Label("Check the route in Maps", systemImage: "map")
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel("Triage or assessment line", isShown: !place.triagePhone.isEmpty)
                    TextField("Triage or assessment line", text: $place.triagePhone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    NumberCheck(result: place.triageCheck(region: region))
                }
                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel("Labour ward", isShown: !place.labourWardPhone.isEmpty)
                    TextField("Labour ward (if it's different)", text: $place.labourWardPhone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    NumberCheck(result: place.labourWardCheck(region: region))
                }
                CheckStatus(place: place, calendar: model.profile.pregnancyCalendar)
                Button {
                    place.numbersCheckedAt = Date()
                } label: {
                    Label("I've checked them against her notes", systemImage: "checkmark.seal")
                }
                .disabled(place.triagePhone.isEmpty)
            } header: {
                Text("Numbers")
            } footer: {
                Text(
                    "Copy them from her maternity notes, menu options and all (“option 2”). Not from a web "
                        + "search: a hospital's main number won't put you through to triage. Check them again "
                        + "from 34 weeks, because units do change them."
                )
            }
            .onChange(of: place.triagePhone) { place.numbersCheckedAt = nil }
            .onChange(of: place.labourWardPhone) { place.numbersCheckedAt = nil }

            Section {
                Stepper(value: travelMinutes(place), in: 0...180, step: 5) {
                    LabeledContent("Journey at the busiest time", value: "\(place.travelMinutes ?? 0) min")
                }
                TextField("Parking and how to pay", text: $place.parkingNotes, axis: .vertical)
                TextField("Entrance after hours", text: $place.afterHoursEntrance, axis: .vertical)
                Toggle("A partner can stay overnight", isOn: $place.partnerCanStayOvernight)
            } header: {
                Text("Getting there")
            } footer: {
                Text(role == .booked ? "A journey over 30 minutes means calling earlier." : "")
            }

            if role == .backup {
                Section {
                    Button("Remove the backup", role: .destructive) {
                        isRemoving = true
                        dismiss()
                    }
                }
            }
        }
    }

    private func travelMinutes(_ place: BirthPlace) -> Binding<Int> {
        Binding(get: { place.travelMinutes ?? 0 }, set: { place.travelMinutes = $0 == 0 ? nil : $0 })
    }
}

extension BirthPlace {
    /// Nothing typed in yet.
    var isBlank: Bool {
        name.isEmpty && triagePhone.isEmpty && labourWardPhone.isEmpty && address.isEmpty && travelMinutes == nil
            && parkingNotes.isEmpty && afterHoursEntrance.isEmpty
    }
}

/// A field's name above it once it's filled in, when the placeholder has gone.
struct FieldLabel: View {
    var text: String
    var isShown: Bool

    init(_ text: String, isShown: Bool) {
        self.text = text
        self.isShown = isShown
    }

    var body: some View {
        if isShown {
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// What a typed number will dial, or what's wrong with it, as he types.
struct NumberCheck: View {
    var result: Result<PhoneNumber, PhoneNumber.Problem>?
    /// A person on the call list rather than the unit, so not "check it against her notes".
    var isPerson = false

    var body: some View {
        switch result {
        case .success(let number):
            Label(
                "Dials \(number.display)\(number.afterConnecting.map { ", \($0.lowercased())" } ?? "")",
                systemImage: "checkmark.circle.fill"
            )
            .font(.footnote)
            .foregroundStyle(.green)
        case .failure(let problem):
            Label(isPerson ? problem.personMessage : problem.message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.red)
        case nil:
            EmptyView()
        }
    }
}
