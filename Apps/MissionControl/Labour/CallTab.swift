import MissionCore
import MissionUI
import SwiftUI

/// One tap to the triage line, and everything they'll ask on one card.
struct CallTab: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let profile = model.profile
        let labour = model.labour
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if labour.output?.state == .call999 {
                    EmergencyCallButton(region: labour.region)
                }
                callButton(profile: profile)
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    if let script = labour.triageScript() {
                        ScriptCard(script: script)
                    }
                }
                hospitalCard(profile: profile)
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
    private func callButton(profile: MissionProfile) -> some View {
        if let url = profile.triageURL {
            Link(destination: url) {
                VStack(spacing: 4) {
                    Label("Call \(profile.unitDisplayName)", systemImage: "phone.fill")
                        .font(.title3.bold())
                    Text(profile.triagePhone)
                        .font(.headline.monospacedDigit())
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 88)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LabourTheme.amber))
            }
        } else {
            NavigationLink {
                MissionProfileForm()
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Add the triage number")
                        .font(.title3.bold())
                    Text("Your maternity unit's assessment line, so it's one tap away.")
                        .foregroundStyle(LabourTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(LabourTheme.amber, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func hospitalCard(profile: MissionProfile) -> some View {
        let rows: [(String, String)] = [
            ("Parking", profile.parkingNotes),
            ("After hours", profile.afterHoursEntrance),
            ("Overnight", profile.partnerCanStayOvernight ? "One partner can stay" : ""),
        ].filter { !$0.1.isEmpty }
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Getting there")
                    .font(.headline)
                    .foregroundStyle(LabourTheme.secondaryText)
                ForEach(rows, id: \.0) { label, value in
                    ScriptRow(label: label, value: value, isUrgent: false)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LabourTheme.surface))
        }
    }
}

private struct ScriptCard: View {
    var script: TriageScript

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Say")
                .font(.headline)
                .foregroundStyle(LabourTheme.secondaryText)
            Text("“\(script.opening)”")
                .font(.title3.weight(.semibold))
                .foregroundStyle(LabourTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Divider().overlay(LabourTheme.raisedSurface)
            ForEach(script.lines, id: \.self) { line in
                ScriptRow(label: line.label, value: line.value, isUrgent: line.isUrgent)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LabourTheme.surface))
        .accessibilityElement(children: .contain)
    }
}

private struct ScriptRow: View {
    var label: String
    var value: String
    var isUrgent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(isUrgent ? LabourTheme.urgent : LabourTheme.secondaryText)
            Text(value)
                .font(.title3)
                .foregroundStyle(isUrgent ? LabourTheme.urgent : LabourTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
