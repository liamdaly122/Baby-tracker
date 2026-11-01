import MissionCore
import MissionUI
import SwiftData
import SwiftUI

/// Who to ring, laid out like the agreed prototype's comms panel, in the order redesign rule 2
/// sets: 999 first when it's a 999 situation, the unit, after the call, "If nobody answers", the
/// script, getting there, the backup unit, the people, and 999 again last. Every call control
/// dials, except in a practice run.
struct CallTab: View {
    @Environment(AppModel.self) private var model
    @Environment(\.missionMode) private var mode
    @Query private var places: [BirthPlace]
    @Query(sort: \CrewContact.sortOrder) private var crew: [CrewContact]

    var body: some View {
        let labour = model.labour
        let region = model.profile.region
        let booked = places.first { $0.role == .booked }
        let backup = places.first { $0.role == .backup }
        let isEmergency = labour.output?.state == .call999
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                LabourTabHeader(
                    world: .call, eyebrow: "Comms", title: "Who to ring",
                    subtitle: mode == .practice
                        ? "In this order. In a drill, nothing dials."
                        : isEmergency ? "999 first. Then your unit." : "In this order. Every button dials.")
                if isEmergency {
                    EmergencyPlate(region: labour.region)
                }
                UnitPlate(place: booked, region: region)
                AfterCallSection()
                FallbackLadder(
                    steps: CallFallback.steps(
                        region: labour.region, unit: booked?.triageNumber(region: region),
                        labourWard: booked?.labourWardNumber(region: region))
                )
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    if let script = labour.triageScript() {
                        NotepadCard(opening: script.opening, lines: script.lines)
                    }
                }
                if let booked {
                    GettingThereSection(place: booked)
                }
                if let backup, !backup.isBlank {
                    BackupSection(place: backup, booked: booked, region: region)
                }
                if !crew.isEmpty {
                    CrewSection(crew: crew, region: region)
                }
                if !isEmergency {
                    EmergencyPlate(region: labour.region)
                }
                Text("NHS advice: phone before you go in. They may advise staying at home for a while longer.")
                    .font(MissionType.body(13, relativeTo: .footnote))
                    .foregroundStyle(LabourTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }
}

/// 999 on a red plate, with when to ring it in the app's own words.
private struct EmergencyPlate: View {
    var region: ContentRegion

    var body: some View {
        let number = StateCopy.emergencyNumber(region)
        let when = CallFallback.steps(region: region, unit: nil, labourWard: nil).last?.detail
        CallPlate(isEmergency: true, label: "Emergency") {
            if let phone = PhoneNumber.shortCode(number) {
                BigDial(number: phone, title: "Call \(number)", detail: nil, style: .hot)
            }
            if let when {
                // Solid cream: faded, it would drop under 4.5:1 on the red.
                Text(when)
                    .font(MissionType.body(13, relativeTo: .footnote))
                    .foregroundStyle(LabourTheme.cream)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The booked unit on its plate: what kind of place, its name, the big "Call triage", the number
/// to copy, "press 2", and when the numbers were last checked against her notes. With no usable
/// number, what to do instead.
private struct UnitPlate: View {
    @Environment(AppModel.self) private var model
    var place: BirthPlace?
    var region: ContentRegion

    var body: some View {
        switch place?.triageCheck(region: region) {
        case .success(let number):
            CallPlate(label: place?.kind.title ?? "Your maternity unit", title: place?.displayName) {
                let then = number.afterConnecting.map { $0.prefix(1).lowercased() + $0.dropFirst() }
                BigDial(
                    number: number, title: "Call triage",
                    detail: [number.display, then].compactMap { $0 }.joined(separator: " · "))
                NumberRow(number: number)
                PlateNote("\(checkedNote) Have her notes ready when they answer.")
            }
        case .failure(let problem):
            noNumber(
                title: "The saved number needs checking",
                detail: "“\(place?.triagePhone ?? "")”: \(problem.message)", action: "Fix the number")
        case nil:
            noNumber(
                title: "No number saved",
                detail: "The triage number is on her maternity notes, often on the front.", action: "Add the number")
        }
    }

    /// "Checked against her notes in week 34.", or that they need checking.
    private var checkedNote: String {
        guard let place, let checked = place.numbersCheckedAt else { return "Not checked against her notes yet." }
        let calendar = model.profile.pregnancyCalendar
        if place.numbersNeedChecking(calendar: calendar, now: model.labour.currentTime) {
            return "Checked before 34 weeks: check them against her notes again."
        }
        if let calendar {
            return "Checked against her notes in week \(calendar.gestationalAgeDays(at: checked, in: .current) / 7)."
        }
        return "Checked against her notes on \(checked.formatted(date: .abbreviated, time: .omitted))."
    }

    private func noNumber(title: String, detail: String, action: String) -> some View {
        CallPlate(label: "Your maternity unit", title: title) {
            PlateNote("\(detail) Until then, NHS 111 can help.")
            if let nhs = CallFallback.steps(region: region, unit: nil, labourWard: nil)
                .first(where: { $0.number?.display == "111" }), let phone = nhs.number
            {
                BigDial(number: phone, title: nhs.title, detail: nhs.detail)
            }
            NavigationLink {
                BirthPlaceForm(role: .booked)
            } label: {
                GhostButtonLabel(title: action, systemImage: "pencil")
            }
            .buttonStyle(.plain)
        }
    }
}

/// "I've called them": what they said. While nothing new happens, the advice says so; anything
/// new after it says call them back.
private struct AfterCallSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Asked before logging: a stray tap would otherwise replace "call now" with what they said.
    @State private var confirming: CallOutcome?

    var body: some View {
        let labour = model.labour
        let last = labour.log.lastCall
        CommsSection("After the call") {
            if let last {
                Text(
                    "Logged at \(last.at.formatted(date: .omitted, time: .shortened)): \(Self.said(last.note.outcome))."
                )
                .font(MissionType.body(15).weight(.semibold))
                .foregroundStyle(LabourTheme.cream)
                if case .callBack = labour.output?.call {
                    Label("Something has changed since. Call them back.", systemImage: "phone.arrow.up.right.fill")
                        .font(MissionType.body(14).weight(.semibold))
                        .foregroundStyle(CallLook.label)
                }
            }
            Text(last == nil ? "What did they say?" : "Called again? What did they say?")
                .font(MissionType.body(14))
                .foregroundStyle(LabourTheme.muted)
            // Side by side, words wrapping, until the text is very large.
            if typeSize.isAccessibilitySize {
                VStack(spacing: 6) { buttons() }
            } else {
                HStack(spacing: 6) { buttons() }
            }
        }
        .confirmationDialog(
            confirming.map { "Log that \(Self.said($0))?" } ?? "",
            isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
            titleVisibility: .visible, presenting: confirming
        ) { outcome in
            Button("Log the call") { labour.logCall(outcome) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("The advice on screen changes to what they told you, until something new happens.")
        }
    }

    @ViewBuilder
    private func buttons() -> some View {
        ForEach(CallOutcome.allCases, id: \.self) { outcome in
            Button {
                confirming = outcome
            } label: {
                Text(Self.button(outcome))
                    .font(MissionType.body(13.5).weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: LabourTheme.minimumControlSize)
                    .foregroundStyle(LabourTheme.cream)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LabourTopRow.pillSurface))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(LabourTheme.cream.opacity(0.4), lineWidth: 1.5)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    static func button(_ outcome: CallOutcome) -> String {
        switch outcome {
        case .comeIn: "Come in"
        case .stayHome: "Stay at home for now"
        case .other: "Something else"
        }
    }

    static func said(_ outcome: CallOutcome) -> String {
        switch outcome {
        case .comeIn: "they said come in"
        case .stayHome: "they said stay at home for now"
        case .other: "you called them"
        }
    }
}

/// The prototype's outlined pill, for things that aren't calls: directions, fixing a number.
struct GhostButtonLabel: View {
    var title: String
    var systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(MissionType.body(13).weight(.semibold))
            .foregroundStyle(LabourTheme.cream)
            .padding(.horizontal, 14)
            .frame(minHeight: LabourTheme.chipSize)
            .overlay(Capsule().strokeBorder(LabourTheme.cream.opacity(0.5), lineWidth: 1.5))
            .contentShape(Capsule())
    }
}
