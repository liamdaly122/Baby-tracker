import MissionCore
import MissionUI
import SwiftUI

/// Due date and her details for the triage call. The hospital has its own screen (`BirthPlacesView`).
/// Becomes part of onboarding in Phase 6.
struct MissionProfileForm: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var profile = model.profile
        PaperPage("Mission profile", subtitle: "Due date and her details for the call") {
            PaperSection(
                "Pregnancy", note: "Second and later babies, or a fast labour last time, mean calling earlier."
            ) {
                PaperField("Due date") {
                    DatePicker("Due date", selection: dueDate, displayedComponents: .date)
                        .labelsHidden()
                }
                PaperStepper(
                    "Previous births", value: "\(profile.parity)", canDecrease: profile.parity > 0,
                    canIncrease: profile.parity < 10, decrease: { profile.parity -= 1 },
                    increase: { profile.parity += 1 })
                PaperTick("Fast labour last time", isOn: $profile.previousFastLabour)
                PaperLabel("Region")
                PaperChips(
                    [ContentRegion.uk, .us], title: { $0 == .uk ? "UK (NHS)" : "US" },
                    isPicked: { $0 == model.profile.region }, pick: { model.profile.region = $0 })
            }
            PaperSection(
                "For the triage call",
                note: "With GBS, call the unit as soon as labour starts or her waters go: antibiotics should start "
                    + "then. With a caesarean planned, call them as soon as labour seems to start."
            ) {
                PaperField("Her name") {
                    TextField("", text: $profile.motherName)
                        .textContentType(.givenName)
                }
                PaperField("Hospital number (from her notes)") {
                    TextField("", text: $profile.hospitalNumber)
                }
                PaperTick("GBS positive (group B strep)", isOn: $profile.gbsPositive)
                PaperTick("A caesarean is planned", isOn: $profile.plannedCaesarean)
                PaperField("Anything else they should know") {
                    TextField("", text: $profile.notes, axis: .vertical)
                }
            }
            PaperSection("Tone", note: "Labour mode is always plain, whatever you choose here.") {
                PaperChips(
                    [HumourLevel.off, .mild, .full],
                    title: {
                        switch $0 {
                        case .off: "Off"
                        case .mild: "Mild"
                        case .full: "Full CAPCOM"
                        }
                    },
                    isPicked: { $0 == model.profile.humour }, pick: { model.profile.humour = $0 })
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
}
