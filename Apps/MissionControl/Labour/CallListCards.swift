import MissionCore
import MissionUI
import SwiftUI

/// The Call tab's lower sections, in the prototype's comms rows: getting there, the backup unit
/// and the people on his call list.

/// The address and journey, the night entrance, parking and directions for where she's booked.
struct GettingThereSection: View {
    var place: BirthPlace

    var body: some View {
        let journey = place.travelMinutes.map { "About \($0) min at the busiest time" }
        let notes = [
            place.afterHoursEntrance, place.parkingNotes,
            place.partnerCanStayOvernight ? "One partner can stay overnight." : "",
        ].filter { !$0.isEmpty }
        let address = place.address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.isEmpty || journey != nil || !notes.isEmpty || place.directionsURL != nil {
            CommsSection("Getting there") {
                if !address.isEmpty || journey != nil {
                    // "1 Northgate Road · About 25 min at the busiest time", the address in cream.
                    (Text(address).foregroundStyle(LabourTheme.cream).fontWeight(.semibold)
                        + Text((address.isEmpty ? "" : " · ") + (journey ?? "")).foregroundStyle(LabourTheme.muted))
                        .font(MissionType.body(14))
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(notes, id: \.self) { note in
                    Text(note)
                        .font(MissionType.body(14))
                        .lineSpacing(2)
                        .foregroundStyle(LabourTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let directions = place.directionsURL {
                    Link(destination: directions) {
                        GhostButtonLabel(title: "Directions", systemImage: "map")
                    }
                    .padding(.top, 2)
                }
            }
        }
    }
}

/// Another unit, or where a birth centre transfers to. Below the booked unit, never above it.
struct BackupSection: View {
    var place: BirthPlace
    var booked: BirthPlace?
    var region: ContentRegion

    var body: some View {
        let numbers = [
            ("Triage", place.triageNumber(region: region)), ("Labour ward", place.labourWardNumber(region: region)),
        ].compactMap { label, number in number.map { (label, $0) } }
        let name = place.name.isEmpty ? place.kind.title : place.name
        CommsSection("Backup") {
            Text(name)
                .font(MissionType.body(15).weight(.semibold))
                .foregroundStyle(LabourTheme.cream)
            Text(
                booked?.kind.needsTransferUnit == true
                    ? "Where \(booked?.displayName ?? "the birth centre") transfers to if she needs a doctor."
                    : "If your unit is full and sends you somewhere else."
            )
            .font(MissionType.body(14))
            .foregroundStyle(LabourTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
            ForEach(numbers, id: \.0) { label, number in
                HStack {
                    Text(label.uppercased())
                        .font(MissionType.mono())
                        .foregroundStyle(LabourTheme.muted)
                    Spacer(minLength: 8)
                    SmallDial(number: number, accessibilityName: "\(name) \(label.lowercased())")
                }
                .padding(.vertical, 4)
            }
            if let directions = place.directionsURL {
                Link(destination: directions) {
                    GhostButtonLabel(title: "Directions", systemImage: "map")
                }
            }
        }
    }
}

/// The people to ring once the unit knows what's happening: the prototype's crew rows.
struct CrewSection: View {
    @Environment(\.missionMode) private var mode
    @Environment(\.dynamicTypeSize) private var typeSize
    var crew: [CrewContact]
    var region: ContentRegion

    var body: some View {
        CommsSection("People · after the unit") {
            VStack(spacing: 0) {
                ForEach(Array(crew.enumerated()), id: \.element.id) { index, person in
                    let name = person.name.isEmpty ? person.role.title : person.name
                    // Buttons beside the name, or under it at the biggest text sizes.
                    let layout =
                        typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                        : AnyLayout(HStackLayout(alignment: .center, spacing: 10))
                    layout {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(MissionType.body(15).weight(.bold))
                                .foregroundStyle(LabourTheme.cream)
                            Text(
                                [person.role.title, person.note].filter { !$0.isEmpty }.joined(separator: " · ")
                                    .uppercased()
                            )
                            .font(MissionType.mono())
                            .foregroundStyle(LabourTheme.muted)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if case .success(let number) = person.phoneCheck(region: region) {
                            HStack(spacing: 10) {
                                if mode == .live, let textURL = person.textURL(region: region) {
                                    Link(destination: textURL) {
                                        Image(systemName: "message")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(LabourTheme.cream)
                                            .frame(width: LabourTheme.chipSize, height: LabourTheme.chipSize)
                                            .background(Circle().fill(LabourTheme.cream.opacity(0.1)))
                                    }
                                    .accessibilityLabel("Text \(name)")
                                }
                                SmallDial(number: number, title: "Call", accessibilityName: name)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .overlay(alignment: .top) {
                        if index > 0 {
                            Rectangle().fill(CallLook.rule).frame(height: 1)
                        }
                    }
                    .accessibilityElement(children: .contain)
                }
            }
        }
    }
}
