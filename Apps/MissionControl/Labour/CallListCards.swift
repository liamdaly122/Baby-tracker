import MissionCore
import MissionUI
import SwiftUI

/// The Call tab's lower cards: getting there, the backup unit and the people on his call list.

/// Journey, parking, the night entrance and directions for where she's booked.
struct GettingThereCard: View {
    var place: BirthPlace

    var body: some View {
        let rows: [(String, String)] = [
            ("Journey", place.travelMinutes.map { "About \($0) min at the busiest time" } ?? ""),
            ("Parking", place.parkingNotes),
            ("After hours", place.afterHoursEntrance),
            ("Overnight", place.partnerCanStayOvernight ? "One partner can stay" : ""),
        ].filter { !$0.1.isEmpty }
        if !rows.isEmpty || place.directionsURL != nil {
            CallSection(title: "GETTING THERE") {
                ForEach(rows, id: \.0) { label, value in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label).font(.subheadline).foregroundStyle(LabourTheme.secondaryText)
                        Text(value).font(.body).foregroundStyle(LabourTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let directions = place.directionsURL {
                    Link(destination: directions) {
                        Label("Directions", systemImage: "map.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(LabourTheme.primaryText)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(LabourTheme.primaryText.opacity(0.1)))
                    }
                }
            }
        }
    }
}

/// Another unit, or where a birth centre transfers to. Below the booked unit, never above it.
struct BackupPlaceCard: View {
    var place: BirthPlace
    var booked: BirthPlace?
    var region: ContentRegion

    var body: some View {
        let numbers = [
            ("Triage", place.triageNumber(region: region)), ("Labour ward", place.labourWardNumber(region: region)),
        ].compactMap { label, number in number.map { (label, $0) } }
        CallSection(title: "BACKUP") {
            Text(place.name.isEmpty ? place.kind.title : place.name)
                .font(.headline)
                .foregroundStyle(LabourTheme.primaryText)
            Text(
                booked?.kind.needsTransferUnit == true
                    ? "Where \(booked?.displayName ?? "the birth centre") transfers to if she needs a doctor."
                    : "If your unit is full and sends you somewhere else."
            )
            .font(.subheadline)
            .foregroundStyle(LabourTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            ForEach(numbers, id: \.0) { label, number in
                HStack {
                    Text(label).font(.subheadline).foregroundStyle(LabourTheme.secondaryText)
                    Spacer(minLength: 8)
                    CallCapsule(number: number)
                }
            }
            if let directions = place.directionsURL {
                Link("Directions", destination: directions)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}

/// The people to ring once the unit knows what's happening. Smaller than the unit on purpose.
struct CrewCard: View {
    var crew: [CrewContact]
    var region: ContentRegion

    var body: some View {
        CallSection(title: "PEOPLE") {
            Text("Once the unit knows what's happening.")
                .font(.subheadline)
                .foregroundStyle(LabourTheme.secondaryText)
            ForEach(crew) { person in
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.name.isEmpty ? person.role.title : person.name)
                            .font(.headline)
                            .foregroundStyle(LabourTheme.primaryText)
                        Text([person.role.title, person.note].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(LabourTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    if case .success(let number) = person.phoneCheck(region: region) {
                        CallCapsule(number: number, textURL: person.textURL(region: region))
                    }
                }
                .accessibilityElement(children: .contain)
            }
        }
    }
}

/// A heading and a top rule, as the Call tab's other sections have.
private struct CallSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold).monospaced())
                .tracking(1)
                .foregroundStyle(LabourWorld.call.accent)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(LabourTheme.primaryText.opacity(0.14)).frame(height: 1) }
    }
}

/// A small call button, with a text button beside it when there's a text link. In a practice run
/// it shows the number and dials nothing.
private struct CallCapsule: View {
    @Environment(\.missionMode) private var mode
    var number: PhoneNumber
    var textURL: URL?

    var body: some View {
        if mode == .practice {
            Text(number.display)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(LabourTheme.blueprint)
                .accessibilityLabel("Practice. In a real labour this rings \(number.display).")
        } else {
            HStack(spacing: 8) {
                if let textURL {
                    Link(destination: textURL) {
                        Image(systemName: "message.fill")
                            .frame(width: 44, height: 44)
                            .foregroundStyle(LabourTheme.primaryText)
                            .background(Circle().fill(LabourTheme.primaryText.opacity(0.1)))
                    }
                    .accessibilityLabel("Text \(number.display)")
                }
                if let url = number.telURL {
                    Link(destination: url) {
                        Label(number.display, systemImage: "phone.fill")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .lineLimit(1)
                            .fixedSize()
                            .foregroundStyle(LabourTheme.primaryText)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(LabourTheme.primaryText.opacity(0.1)))
                            .overlay(Capsule().strokeBorder(LabourTheme.primaryText.opacity(0.3), lineWidth: 1))
                    }
                }
            }
        }
    }
}
