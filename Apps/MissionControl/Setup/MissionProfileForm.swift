import MissionCore
import SwiftUI

/// Due date and her details for the triage call. The hospital has its own screen (`BirthPlacesView`).
/// Becomes part of onboarding in Phase 6.
struct MissionProfileForm: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var profile = model.profile
        Form {
            Section {
                DatePicker("Due date", selection: dueDate, displayedComponents: .date)
                Stepper(value: $profile.parity, in: 0...10) {
                    LabeledContent("Previous births", value: "\(profile.parity)")
                }
                Toggle("Fast labour last time", isOn: $profile.previousFastLabour)
                Picker("Region", selection: region) {
                    Text("UK (NHS)").tag(ContentRegion.uk)
                    Text("US").tag(ContentRegion.us)
                }
            } header: {
                Text("Pregnancy")
            } footer: {
                Text("Second and later babies, or a fast labour last time, mean calling earlier.")
            }

            Section {
                TextField("Her name", text: $profile.motherName)
                    .textContentType(.givenName)
                TextField("Hospital number (from her notes)", text: $profile.hospitalNumber)
                Toggle("GBS positive (group B strep)", isOn: $profile.gbsPositive)
                Toggle("A caesarean is planned", isOn: $profile.plannedCaesarean)
                TextField("Anything else they should know", text: $profile.notes, axis: .vertical)
            } header: {
                Text("For the triage call")
            } footer: {
                Text(
                    "With GBS, call the unit as soon as labour starts or her waters go: antibiotics should "
                        + "start then. With a caesarean planned, call them as soon as labour seems to start."
                )
            }

            Section("Tone") {
                Picker("Humour", selection: humour) {
                    Text("Off").tag(HumourLevel.off)
                    Text("Mild").tag(HumourLevel.mild)
                    Text("Full CAPCOM").tag(HumourLevel.full)
                }
                Text("Labour mode is always plain, whatever you choose here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Mission profile")
        .onDisappear {
            model.savePlanning()
            model.reloadLibrary()
            model.labour.refresh()
        }
    }

    private var dueDate: Binding<Date> {
        Binding(
            get: {
                model.profile.dueDate?.startDate(in: .current)
                    ?? Calendar.current.date(byAdding: .day, value: 140, to: Date()) ?? Date()
            },
            set: { model.profile.dueDate = CalendarDay($0, in: .current) }
        )
    }

    private var region: Binding<ContentRegion> {
        Binding(get: { model.profile.region }, set: { model.profile.region = $0 })
    }

    private var humour: Binding<HumourLevel> {
        Binding(get: { model.profile.humour }, set: { model.profile.humour = $0 })
    }
}
