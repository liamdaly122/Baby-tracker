import MissionCore
import SwiftUI

/// Due date, her details for the triage call, and the hospital. Becomes part of onboarding in Phase 6.
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

            Section {
                TextField("Maternity unit", text: $profile.unitName)
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Triage or assessment line", text: $profile.triagePhone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    NumberCheck(result: profile.triageCheck)
                }
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Labour ward (if it's different)", text: $profile.labourWardPhone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    NumberCheck(result: profile.labourWardCheck)
                }
                Stepper(value: travelMinutes, in: 0...180, step: 5) {
                    LabeledContent("Journey time", value: "\(profile.travelMinutes ?? 0) min")
                }
                TextField("Parking and how to pay", text: $profile.parkingNotes, axis: .vertical)
                TextField("Entrance after hours", text: $profile.afterHoursEntrance, axis: .vertical)
                Toggle("A partner can stay overnight", isOn: $profile.partnerCanStayOvernight)
            } header: {
                Text("Hospital")
            } footer: {
                Text(
                    "Copy the numbers from her maternity notes, menu options and all (“option 2”). "
                        + "A journey over 30 minutes means calling earlier."
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

    private var travelMinutes: Binding<Int> {
        Binding(get: { model.profile.travelMinutes ?? 0 }, set: { model.profile.travelMinutes = $0 == 0 ? nil : $0 })
    }
}

/// What a typed number will dial, or what's wrong with it, as he types.
private struct NumberCheck: View {
    var result: Result<PhoneNumber, PhoneNumber.Problem>?

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
            Label(problem.message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.red)
        case nil:
            EmptyView()
        }
    }
}
