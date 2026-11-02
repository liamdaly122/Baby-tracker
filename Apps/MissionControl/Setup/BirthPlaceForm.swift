import MissionCore
import MissionUI
import SwiftData
import SwiftUI

/// Where she's booked, and a backup, as the prototype's Ground control shows them: the booked
/// place on its teal card, the backup under it. Each opens its own form.
struct BirthPlacesView: View {
    @Environment(AppModel.self) private var model
    @Query private var places: [BirthPlace]

    var body: some View {
        let booked = places.first { $0.role == .booked }
        let backup = places.first { $0.role == .backup }
        PaperPage("Hospital or birth centre", subtitle: "Where she's giving birth, and a backup") {
            PaperSection("Where she's booked", note: "The Call tab rings this unit first.") {
                PlaceLink(place: booked, role: .booked, empty: "Add where she's booked")
            }
            PaperSection(
                "Backup",
                note: booked?.kind.needsTransferUnit == true
                    ? "A birth centre on its own has no doctors. Add the hospital it transfers to."
                    : "Another unit nearby, in case they're full and send you elsewhere."
            ) {
                PlaceLink(place: backup, role: .backup, empty: "Add a backup")
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A saved place on the teal card, with whether its numbers are checked; or a dashed box to add one.
private struct PlaceLink: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    var place: BirthPlace?
    var role: BirthPlaceRole
    var empty: String

    var body: some View {
        NavigationLink {
            BirthPlaceForm(role: role)
        } label: {
            if let place, !place.isBlank {
                VStack(alignment: .leading, spacing: 8) {
                    PlaceCard(
                        kind: place.kind.title, name: place.name.isEmpty ? place.kind.title : place.name,
                        detail: place.address.isEmpty ? nil : place.address,
                        facts: place.travelMinutes.map { [("\($0) min", "At the busiest time")] } ?? []
                    ) {
                        Text("Change")
                            .font(MissionType.body(13).weight(.semibold))
                            .foregroundStyle(LabourTheme.paperInk)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 34)
                            .background(Capsule().fill(LabourPalette.paperHi.color))
                    }
                    CheckStatus(place: place, calendar: model.profile.pregnancyCalendar)
                }
                .multilineTextAlignment(.leading)
            } else {
                let colours = PaperColors.for(scheme)
                Label(empty, systemImage: "plus")
                    .font(MissionType.body(15).weight(.semibold))
                    .foregroundStyle(colours.ink)
                    .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize + 8)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(colours.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(colours.edge, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

/// "Numbers checked 31 Oct", or a prompt to check them.
struct CheckStatus: View {
    var place: BirthPlace
    var calendar: PregnancyCalendar?

    var body: some View {
        if let checked = place.numbersCheckedAt, !place.numbersNeedChecking(calendar: calendar, now: Date()) {
            PaperNote(
                "Numbers checked \(checked.formatted(date: .abbreviated, time: .omitted))".uppercased(), tone: .good)
        } else {
            PaperNote(
                (place.numbersCheckedAt == nil
                    ? "Numbers not checked against her notes" : "34 weeks: check the numbers again").uppercased(),
                tone: .warn)
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
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
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
        let checked = Binding(
            get: { place.numbersCheckedAt != nil },
            set: { place.numbersCheckedAt = $0 ? Date() : nil })
        return PaperPage(
            role == .booked ? "Where she's booked" : "Backup", subtitle: "The numbers come from her maternity notes"
        ) {
            PaperSection("The place") {
                PaperLabel("Kind")
                PaperChips(
                    BirthPlaceKind.allCases, title: \.title, isPicked: { $0 == place.kind }, pick: { place.kind = $0 })
                PaperField("Name, as on her notes") {
                    TextField("", text: $place.name, axis: .vertical)
                }
                PaperField("Address or postcode") {
                    TextField("", text: $place.address, axis: .vertical)
                        .textContentType(.fullStreetAddress)
                }
                if let directions = place.directionsURL {
                    Link(destination: directions) {
                        Label("Check the route in Maps", systemImage: "map")
                    }
                    .buttonStyle(PaperButtonStyle(.ghost))
                }
            }
            PaperSection(
                "Numbers",
                note: "Copy them from her maternity notes, menu options and all (“option 2”). Not from a web "
                    + "search: a hospital's main number won't put you through to triage. Check them again from 34 "
                    + "weeks, because units do change them."
            ) {
                VStack(alignment: .leading, spacing: 5) {
                    PaperField("Triage or assessment line") {
                        TextField("", text: $place.triagePhone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                    }
                    NumberCheck(result: place.triageCheck(region: region))
                }
                VStack(alignment: .leading, spacing: 5) {
                    PaperField("Labour ward (if it's different)") {
                        TextField("", text: $place.labourWardPhone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                    }
                    NumberCheck(result: place.labourWardCheck(region: region))
                }
                PaperTick("I've checked the triage number against her maternity notes", isOn: checked)
                    .disabled(place.triagePhone.isEmpty)
                CheckStatus(place: place, calendar: model.profile.pregnancyCalendar)
            }
            .onChange(of: place.triagePhone) { place.numbersCheckedAt = nil }
            .onChange(of: place.labourWardPhone) { place.numbersCheckedAt = nil }
            PaperSection(
                "Getting there", note: role == .booked ? "A journey over 30 minutes means calling earlier." : nil
            ) {
                PaperStepper(
                    "Journey at the busiest time", value: "\(place.travelMinutes ?? 0) min",
                    canDecrease: (place.travelMinutes ?? 0) > 0, canIncrease: (place.travelMinutes ?? 0) < 180,
                    decrease: { setTravel(place, by: -5) }, increase: { setTravel(place, by: 5) })
                PaperField("Parking and how to pay") {
                    TextField("", text: $place.parkingNotes, axis: .vertical)
                }
                PaperField("Entrance after hours") {
                    TextField("", text: $place.afterHoursEntrance, axis: .vertical)
                }
                PaperTick("A partner can stay overnight", isOn: $place.partnerCanStayOvernight)
            }
            if role == .backup {
                Button("Remove the backup") {
                    isRemoving = true
                    dismiss()
                }
                .buttonStyle(PaperButtonStyle(.danger))
                .padding(.top, 8)
            }
        }
    }

    private func setTravel(_ place: BirthPlace, by minutes: Int) {
        let value = min(180, max(0, (place.travelMinutes ?? 0) + minutes))
        place.travelMinutes = value == 0 ? nil : value
    }
}

extension BirthPlace {
    /// Nothing typed in yet.
    var isBlank: Bool {
        name.isEmpty && triagePhone.isEmpty && labourWardPhone.isEmpty && address.isEmpty && travelMinutes == nil
            && parkingNotes.isEmpty && afterHoursEntrance.isEmpty
    }
}

/// What a typed number will dial, or what's wrong with it, as he types: the prototype's green
/// "Dials 01632 960118 · then press 2", or the problem in red.
struct NumberCheck: View {
    var result: Result<PhoneNumber, PhoneNumber.Problem>?
    /// A person on the call list rather than the unit, so not "check it against her notes".
    var isPerson = false

    var body: some View {
        switch result {
        case .success(let number):
            PaperNote(
                "Dials \(number.display)\(number.afterConnecting.map { " · \($0.lowercased())" } ?? "")", tone: .good)
        case .failure(let problem):
            PaperNote(isPerson ? problem.personMessage : problem.message, tone: .bad)
        case nil:
            EmptyView()
        }
    }
}
