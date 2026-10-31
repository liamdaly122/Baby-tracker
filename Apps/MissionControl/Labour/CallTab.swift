import MissionCore
import MissionUI
import SwiftData
import SwiftUI

/// Who to ring, in order: 999 first when it's a 999 situation, then the unit, "Can't get
/// through?", everything they'll ask on one card, getting there, the backup unit, and last the
/// people on his call list. Every call control dials, except in a practice run.
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LabourTabHeader(
                    world: .call, eyebrow: "Comms", title: "Who to ring",
                    subtitle: mode == .practice
                        ? "In this order. In a drill, nothing dials."
                        : labour.output?.state == .call999
                            ? "999 first. Then your unit." : "In this order. Every button dials.")
                if labour.output?.state == .call999 {
                    EmergencyCallButton(region: labour.region)
                }
                unitCard(place: booked, region: region)
                AfterCallCard()
                FallbackList(
                    steps: CallFallback.steps(
                        region: labour.region, unit: booked?.triageNumber(region: region),
                        labourWard: booked?.labourWardNumber(region: region))
                )
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    if let script = labour.triageScript() {
                        ScriptCard(script: script)
                    }
                }
                if let booked {
                    GettingThereCard(place: booked)
                }
                if let backup, !backup.isBlank {
                    BackupPlaceCard(place: backup, booked: booked, region: region)
                }
                if !crew.isEmpty {
                    CrewCard(crew: crew, region: region)
                }
                if labour.output?.state != .call999 {
                    EmergencyCallButton(region: labour.region)
                        .opacity(0.85)
                }
                Text("NHS advice: phone before you go in. They may advise staying at home for a while longer.")
                    .font(.footnote)
                    .foregroundStyle(LabourTheme.secondaryText)
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func unitCard(place: BirthPlace?, region: ContentRegion) -> some View {
        let name = place?.displayName ?? "your maternity unit"
        switch place?.triageCheck(region: region) {
        case .success(let number):
            // The dial plate: the one number that matters most, on its own panel.
            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR MATERNITY UNIT")
                    .font(.caption.weight(.semibold).monospaced())
                    .tracking(1)
                    .foregroundStyle(LabourWorld.call.accent)
                if mode == .practice {
                    PracticeDial(
                        action: "Call \(name)",
                        detail: "In a real labour this rings \(number.display).")
                } else if let url = number.telURL {
                    Link(destination: url) {
                        HStack(spacing: 12) {
                            Image(systemName: "phone.fill")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Call \(name)")
                                    .font(.title3.bold())
                                    .multilineTextAlignment(.leading)
                                Text(number.display)
                                    .font(.headline.monospacedDigit())
                            }
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(Color(red: 0.7, green: 0.19, blue: 0.11))
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: 88)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Self.cream))
                    }
                }
                if let after = number.afterConnecting {
                    Label(after, systemImage: "number")
                        .font(.headline)
                        .foregroundStyle(LabourTheme.primaryText)
                }
                Text("Have her notes ready when they answer.")
                    .font(.subheadline)
                    .foregroundStyle(LabourTheme.secondaryText)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(LabourWorld.call.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(LabourTheme.urgent.opacity(0.55), lineWidth: 1.5)
            )
        case .failure(let problem):
            fixNumberCard(
                title: "The saved number needs checking",
                detail: "“\(place?.triagePhone ?? "")”: \(problem.message) Until it's fixed, use NHS 111 below.")
        case nil:
            fixNumberCard(
                title: "Add the triage number",
                detail: "It's on her maternity notes, often on the front. Until then, use NHS 111 below.")
        }
    }

    static let cream = Color(red: 0.96, green: 0.91, blue: 0.82)

    private func fixNumberCard(title: String, detail: String) -> some View {
        NavigationLink {
            BirthPlaceForm(role: .booked)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.bold())
                Text(detail)
                    .foregroundStyle(LabourTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(LabourTheme.amber, lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// "I've called them": what they said. While nothing new happens, the advice says so; anything
/// new after it says call them back.
private struct AfterCallCard: View {
    @Environment(AppModel.self) private var model
    /// Asked before logging: a stray tap would otherwise replace "call now" with what they said.
    @State private var confirming: CallOutcome?

    var body: some View {
        let labour = model.labour
        let last = labour.log.lastCall
        VStack(alignment: .leading, spacing: 10) {
            Text("AFTER THE CALL")
                .font(.caption.weight(.semibold).monospaced())
                .tracking(1)
                .foregroundStyle(LabourWorld.call.accent)
            if let last {
                Text(
                    "Logged at \(last.at.formatted(date: .omitted, time: .shortened)): \(Self.said(last.note.outcome))."
                )
                .font(.headline)
                .foregroundStyle(LabourTheme.primaryText)
                if case .callBack = labour.output?.call {
                    Label("Something has changed since. Call them back.", systemImage: "phone.arrow.up.right.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LabourTheme.urgent)
                }
            }
            Text(last == nil ? "What did they say?" : "Called again? What did they say?")
                .font(.subheadline)
                .foregroundStyle(LabourTheme.secondaryText)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { buttons() }
                VStack(spacing: 8) { buttons() }
            }
        }
        .padding(.vertical, 4)
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
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 8)
                    .foregroundStyle(LabourTheme.primaryText)
                    .background(Capsule().fill(LabourTheme.primaryText.opacity(0.1)))
                    .overlay(Capsule().strokeBorder(LabourTheme.primaryText.opacity(0.3), lineWidth: 1))
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

/// "Can't get through?" as a numbered ladder: try again, the labour ward, NHS 111, then 999 in an
/// emergency. Always open, because it's the order to work down.
private struct FallbackList: View {
    @Environment(\.missionMode) private var mode
    var steps: [CallStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("IF NOBODY ANSWERS")
                .font(.caption.weight(.semibold).monospaced())
                .tracking(1)
                .foregroundStyle(LabourWorld.call.accent)
                .padding(.bottom, 6)
            ForEach(Array(steps.enumerated()), id: \.element) { index, step in
                HStack(alignment: .center, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(LabourWorld.call.accent)
                        .frame(width: 28, height: 28)
                        .overlay(Circle().strokeBorder(LabourTheme.urgent, lineWidth: 1.5))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.headline)
                            .foregroundStyle(LabourTheme.primaryText)
                        Text(step.detail)
                            .font(.subheadline)
                            .foregroundStyle(LabourTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    if let number = step.number, mode == .practice {
                        Text(number.display)
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .lineLimit(1)
                            .fixedSize()
                            .foregroundStyle(LabourTheme.blueprint)
                            .accessibilityLabel("Practice. In a real labour this rings \(number.display).")
                    } else if let number = step.number, let url = number.telURL {
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
                .padding(.vertical, 10)
                .overlay(alignment: .top) { Rectangle().fill(LabourTheme.primaryText.opacity(0.14)).frame(height: 1) }
            }
            Text("Source: \(CallFallback.source.title)")
                .font(.footnote)
                .foregroundStyle(LabourTheme.secondaryText)
                .padding(.top, 6)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Can't get through? Work down this list.")
    }
}

private struct ScriptCard: View {
    var script: TriageScript
    static let ink = Color(red: 0.11, green: 0.13, blue: 0.28)
    static let redInk = Color(red: 0.7, green: 0.19, blue: 0.11)

    var body: some View {
        // A notepad: what to read out, with the urgent lines in red ink.
        VStack(alignment: .leading, spacing: 12) {
            Text("SAY")
                .font(.caption.weight(.semibold).monospaced())
                .tracking(1)
                .foregroundStyle(Self.redInk)
            Text("“\(script.opening)”")
                .font(.title2.weight(.bold))
                .foregroundStyle(Self.ink)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(script.lines, id: \.self) { line in
                ScriptRow(label: line.label, value: line.value, isUrgent: line.isUrgent)
            }
        }
        .padding(.vertical, 16)
        .padding(.leading, 30)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 6, bottomLeading: 6, bottomTrailing: 20, topTrailing: 20)
            ).fill(CallTab.cream)
        )
        .overlay(alignment: .leading) {
            Rectangle().fill(Self.redInk.opacity(0.6)).frame(width: 1.5).padding(.leading, 18)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct ScriptRow: View {
    var label: String
    var value: String
    var isUrgent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold).monospaced())
                .foregroundStyle(isUrgent ? ScriptCard.redInk : ScriptCard.ink.opacity(0.6))
            Text(value)
                .font(.title3.weight(isUrgent ? .semibold : .regular))
                .foregroundStyle(isUrgent ? ScriptCard.redInk : ScriptCard.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
