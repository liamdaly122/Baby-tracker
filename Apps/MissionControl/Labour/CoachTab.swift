import MissionCore
import MissionUI
import SwiftUI

/// The stages as stops on a line, so where things are reads as a place on a journey.
private struct StageTrack: View {
    var stages: [LabourStage]
    var current: LabourStage
    var pick: (LabourStage) -> Void

    var body: some View {
        let at = stages.firstIndex(of: current) ?? 0
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(Array(stages.enumerated()), id: \.element) { index, candidate in
                    Button {
                        pick(candidate)
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(fill(index: index, at: at))
                                .overlay(Circle().strokeBorder(LabourWorld.coach.accent.opacity(0.6), lineWidth: 2))
                                .frame(width: 22, height: 22)
                                .background(alignment: .center) {
                                    if index < stages.count - 1 {
                                        Rectangle()
                                            .fill(LabourWorld.coach.accent.opacity(0.3))
                                            .frame(width: 78, height: 2)
                                            .offset(x: 39)
                                    }
                                }
                            Text(candidate.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(index == at ? LabourTheme.primaryText : LabourTheme.secondaryText)
                        }
                        .frame(width: 78, height: 60)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(candidate.label)
                    .accessibilityAddTraits(index == at ? .isSelected : [])
                }
            }
            .padding(.horizontal, 8)
        }
        .scrollIndicators(.hidden)
    }

    private func fill(index: Int, at: Int) -> Color {
        if index == at { return LabourTheme.amber }
        return index < at ? LabourWorld.coach.accent.opacity(0.6) : LabourWorld.coach.surface
    }
}

/// "Say this, do this" cards for where things are. The partner picks the stage: the app never guesses.
struct CoachTab: View {
    @Environment(AppModel.self) private var model
    @Binding var stage: LabourStage
    @State private var page = 0

    private static let selfCareID = "coaching.established.self-care"

    var body: some View {
        let stages = LabourStage.allCases.filter { candidate in
            model.library.coaching.contains { $0.stage == candidate }
        }
        let cards = cards(for: stage)
        VStack(spacing: 12) {
            LabourTabHeader(
                world: .coach, eyebrow: "Coach", title: "What helps now",
                subtitle: "You pick the stage. The app never guesses."
            )
            .padding(.horizontal, 16)
            StageTrack(stages: stages, current: stage) { picked in
                stage = picked
                page = 0
            }
            TabView(selection: $page) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    ScrollView {
                        CoachingCardView(card: card)
                            .padding(.horizontal, 16)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
        .padding(.top, 8)
    }

    /// The stage's cards, with partner self-care at the end of every stage.
    private func cards(for stage: LabourStage) -> [CoachingCard] {
        var cards = model.library.coachingCards(for: stage)
        if !cards.contains(where: { $0.id == Self.selfCareID }),
            let selfCare = model.library.coaching.first(where: { $0.id == Self.selfCareID })
        {
            cards.append(selfCare)
        }
        return cards
    }
}

private struct CoachingCardView: View {
    var card: CoachingCard

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(card.title)
                .font(.title.bold())
                .foregroundStyle(LabourTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(card.doThis, id: \.self) { line in
                Label {
                    Text(line).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(LabourWorld.coach.accent)
                }
                .font(.title3)
                .foregroundStyle(LabourTheme.primaryText)
            }
            if !card.avoidThis.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AVOID")
                        .font(.caption.weight(.semibold).monospaced())
                        .tracking(1)
                        .foregroundStyle(LabourWorld.call.accent)
                    ForEach(card.avoidThis, id: \.self) { line in
                        Label {
                            Text(line).fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(LabourTheme.urgent)
                        }
                        .font(.body)
                        .foregroundStyle(LabourTheme.primaryText)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LabourTheme.urgent.opacity(0.12))
                )
                .overlay(alignment: .leading) { Rectangle().fill(LabourTheme.urgent).frame(width: 3) }
            }
            if let provenance = card.provenance {
                Text("Source: \(provenance.sourceTitle)")
                    .font(.footnote)
                    .foregroundStyle(LabourTheme.secondaryText)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(LabourWorld.coach.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(LabourWorld.coach.accent.opacity(0.3), lineWidth: 1.5)
        )
        .padding(.bottom, 40)
    }
}

extension LabourStage {
    var label: String {
        switch self {
        case .latent: "Early"
        case .established: "Established"
        case .transition: "Transition"
        case .pushing: "Pushing"
        case .thirdStage: "Placenta"
        case .theatre: "Theatre"
        case .goldenHour: "First hour"
        case .postnatal: "After"
        }
    }
}
