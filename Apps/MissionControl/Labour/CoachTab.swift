import MissionCore
import MissionUI
import SwiftUI

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
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(stages, id: \.self) { candidate in
                        Button {
                            stage = candidate
                            page = 0
                        } label: {
                            Text(candidate.label)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background(
                                    Capsule().fill(candidate == stage ? LabourTheme.amber : LabourTheme.surface)
                                )
                                .foregroundStyle(candidate == stage ? Color.black : LabourTheme.primaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            Text("Pick where things are. The app doesn't guess.")
                .font(.footnote)
                .foregroundStyle(LabourTheme.secondaryText)
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
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(LabourTheme.amber)
                }
                .font(.title3)
                .foregroundStyle(LabourTheme.primaryText)
            }
            if !card.avoidThis.isEmpty {
                Text("Avoid")
                    .font(.headline)
                    .foregroundStyle(LabourTheme.secondaryText)
                    .padding(.top, 4)
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
            if let provenance = card.provenance {
                Text("Source: \(provenance.sourceTitle)")
                    .font(.footnote)
                    .foregroundStyle(LabourTheme.secondaryText)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(LabourTheme.surface))
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
