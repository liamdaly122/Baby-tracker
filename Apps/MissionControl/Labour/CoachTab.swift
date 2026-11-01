import MissionCore
import MissionUI
import SwiftUI

/// The stages as stops on a line, as the prototype draws them: done stops filled mint, the current
/// one sun. All six across when they fit; at big text sizes, a list.
struct StageTrack: View {
    var stages: [LabourStage]
    var current: LabourStage
    var pick: (LabourStage) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            stops
            list
        }
    }

    /// One stop under another, for big text sizes.
    private var list: some View {
        let at = stages.firstIndex(of: current) ?? 0
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element) { index, stage in
                Button {
                    pick(stage)
                } label: {
                    HStack(spacing: 10) {
                        dot(index: index, at: at)
                        Text(stage.label)
                            .font(MissionType.body(11, relativeTo: .caption2).weight(.semibold))
                            .foregroundStyle(index == at ? LabourTheme.cream : LabourTheme.muted)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: LabourTheme.chipSize)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(stage.label)
                .accessibilityAddTraits(index == at ? .isSelected : [])
            }
        }
    }

    /// Equal columns, with the line behind the dots.
    private var stops: some View {
        let at = stages.firstIndex(of: current) ?? 0
        return HStack(alignment: .top, spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element) { index, stage in
                Button {
                    pick(stage)
                } label: {
                    VStack(spacing: 6) {
                        dot(index: index, at: at)
                        Text(stage.label)
                            .font(MissionType.body(11, relativeTo: .caption2).weight(.semibold))
                            .foregroundStyle(index == at ? LabourTheme.cream : LabourTheme.muted)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(.horizontal, 3)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(stage.label)
                .accessibilityAddTraits(index == at ? .isSelected : [])
                .background(alignment: .top) {
                    // The line between this stop and the next.
                    if index < stages.count - 1 {
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(LabourPalette.mint.color.opacity(0.3))
                                .frame(width: geometry.size.width, height: 2)
                                .offset(x: geometry.size.width / 2, y: 13)
                        }
                        .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func dot(index: Int, at: Int) -> some View {
        let mint = LabourPalette.mint.color
        return ZStack {
            if index == at {
                // The prototype's soft sun ring round the current stop: a flat ring, no blur.
                Circle().fill(LabourTheme.sun.opacity(0.2)).frame(width: 28, height: 28)
            }
            Circle()
                .fill(index == at ? LabourTheme.sun : (index < at ? mint.opacity(0.55) : Self.unvisited))
                .overlay(Circle().strokeBorder(index == at ? LabourTheme.sun : mint.opacity(0.55), lineWidth: 2))
                .frame(width: 18, height: 18)
        }
        .frame(width: 28, height: 28)
    }

    /// The prototype's #0B2E31 inside a stop not reached yet.
    private static let unvisited = PaletteColor(hex: 0x0B2E31).color
}

/// "Say this, do this" cards for where things are, one under another as in the prototype. He
/// picks the stage: the app never guesses.
struct CoachTab: View {
    @Environment(AppModel.self) private var model
    @Binding var stage: LabourStage

    private static let selfCareID = "coaching.established.self-care"

    var body: some View {
        let stages = LabourStage.allCases.filter { candidate in
            model.library.coaching.contains { $0.stage == candidate }
        }
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    LabourTabHeader(
                        world: .coach, eyebrow: "Coach", title: "What helps now",
                        subtitle: "You pick the stage. The app never guesses."
                    )
                    .id("top")
                    StageTrack(stages: stages, current: stage) { picked in
                        stage = picked
                        reader.scrollTo("top", anchor: .top)
                    }
                    ForEach(cards(for: stage)) { card in
                        CoachingCardView(card: card)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
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

/// One coaching card: the title in the display face, mint dots for what to do, and a red-edged
/// "Avoid" box.
struct CoachingCardView: View {
    var card: CoachingCard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(card.title)
                .font(MissionType.display(28, relativeTo: .title))
                .tracking(0.56)
                .foregroundStyle(LabourTheme.cream)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 7) {
                ForEach(card.doThis, id: \.self) { line in
                    bullet(line, size: 15.5) {
                        Circle().fill(LabourPalette.mint.color).frame(width: 7, height: 7)
                    }
                }
            }
            if !card.avoidThis.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("AVOID")
                        .font(MissionType.mono())
                        .tracking(1.3)
                        .foregroundStyle(LabourPalette.callAccent.color)
                    ForEach(card.avoidThis, id: \.self) { line in
                        bullet(line, size: 15) {
                            Rectangle().fill(LabourTheme.signal).frame(width: 7, height: 7).rotationEffect(.degrees(45))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LabourTheme.signal.opacity(0.12))
                )
                .overlay(alignment: .leading) {
                    UnevenRoundedRectangle(cornerRadii: .init(topLeading: 12, bottomLeading: 12))
                        .fill(LabourTheme.signal)
                        .frame(width: 3)
                }
                .accessibilityElement(children: .combine)
            }
            if let provenance = card.provenance {
                Text("Source: \(provenance.sourceTitle)".uppercased())
                    .font(MissionType.mono())
                    .foregroundStyle(LabourTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LabourWorld.coach.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(LabourPalette.mint.color.opacity(0.28), lineWidth: 1.5)
        )
    }

    private func bullet(_ text: String, size: CGFloat, @ViewBuilder mark: () -> some View) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            mark()
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 2 }
            Text(text)
                .font(MissionType.body(size))
                .lineSpacing(3)
                .foregroundStyle(LabourTheme.cream)
                .fixedSize(horizontal: false, vertical: true)
        }
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
