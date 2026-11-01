import MissionCore
import MissionUI
import SwiftUI

/// "What did the midwife just say?" Offline search over the glossary, box pinned at the top.
struct DecoderTab: View {
    @Environment(AppModel.self) private var model
    var stage: LabourStage
    @State private var query = ""
    @State private var expanded: String?
    @State private var index: GlossaryIndex?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            LabourTabHeader(
                world: .decoder, eyebrow: "Decoder", title: "What did they just say?",
                subtitle: "\(model.library.glossary.count) terms in plain English, with a question to ask."
            )
            .padding(.horizontal, 18)
            .padding(.top, 4)
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(LabourTheme.muted)
                    .accessibilityHidden(true)
                TextField(
                    "", text: $query,
                    prompt: Text("What did they say? “the drip”, “she's 6”").foregroundStyle(LabourTheme.muted)
                )
                .font(MissionType.body(16))
                .foregroundStyle(LabourTheme.cream)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($searchFocused)
                .submitLabel(.search)
                .accessibilityLabel("Search the decoder")
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(LabourTheme.muted)
                            .frame(minWidth: LabourTheme.chipSize, minHeight: LabourTheme.chipSize)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: LabourTheme.minimumControlSize)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Self.searchFill))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(LabourTheme.blueprint.opacity(0.5), lineWidth: 1.5)
            )
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 6)

            let results = (index ?? GlossaryIndex(entries: model.library.glossary)).search(
                query, stage: stage, limit: 100)
            if results.isEmpty {
                Text("Nothing found. Ask them: “Can you explain that in plain English?”")
                    .font(MissionType.body(14.5))
                    .foregroundStyle(LabourTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { entry in
                            GlossaryRow(entry: entry, isExpanded: expanded == entry.id || results.count == 1) {
                                withAnimation { expanded = expanded == entry.id ? nil : entry.id }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.immediately)
            }
        }
        .onAppear {
            if index == nil {
                index = GlossaryIndex(entries: model.library.glossary)
            }
        }
    }

    /// The prototype's rgba(10, 20, 48, 0.9) behind the search box.
    private static let searchFill = LabourPalette.decoderBlue.color.opacity(0.9)
}

/// One term, as the prototype sets it: the word in the display face with how much to worry
/// beside it, what it means, and a question to ask. Tap for other names for it and the source.
struct GlossaryRow: View {
    var entry: GlossaryEntry
    var isExpanded: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 10) {
                        term
                        Spacer(minLength: 0)
                        WorryBadge(level: entry.worryLevel)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        term
                        WorryBadge(level: entry.worryLevel)
                    }
                }
                Text(entry.plainEnglish)
                    .font(MissionType.body(14.5))
                    .lineSpacing(3)
                    .foregroundStyle(LabourTheme.cream.opacity(0.82))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("ASK")
                        .font(MissionType.mono())
                        .tracking(1.3)
                    Text("“\(entry.questionToAsk)”")
                        .font(MissionType.body(14.5))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(LabourTheme.blueprint)
                if isExpanded {
                    if !entry.aliases.isEmpty {
                        Text("Also: \(entry.aliases.joined(separator: ", "))")
                            .font(MissionType.body(13, relativeTo: .footnote))
                            .foregroundStyle(LabourTheme.muted)
                    }
                    Text("Source: \(entry.provenance.sourceTitle)".uppercased())
                        .font(MissionType.mono())
                        .foregroundStyle(LabourTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                Line()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(LabourTheme.blueprint.opacity(0.35))
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(isExpanded ? "" : "Shows other names for it and the source")
    }

    private var term: some View {
        Text(entry.term)
            .font(MissionType.display(27, relativeTo: .title2))
            .tracking(0.54)
            .foregroundStyle(LabourTheme.cream)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A straight line across, for the dashed rule between terms.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

/// How much to worry, in words as well as colour (redesign rule 8): the prototype's small tinted
/// label, with the app's four levels.
struct WorryBadge: View {
    var level: Int

    /// Seriousness, not an instruction: most of these he can't act on himself.
    static func label(_ level: Int) -> String {
        switch level {
        case ...0: "Routine"
        case 1: "Worth asking about"
        case 2: "Staff will watch closely"
        default: "Serious: the team acts fast"
        }
    }

    /// The text colour and the tint behind it, each pair tested for contrast in `LabourPalette`.
    private var colours: (text: Color, tint: Color) {
        switch level {
        case ...0: (LabourPalette.paleMint.color, LabourPalette.mint.color.opacity(0.16))
        case 1: (LabourTheme.blueprint, LabourTheme.blueprint.opacity(0.16))
        case 2: (LabourTheme.sun, LabourTheme.sun.opacity(0.18))
        default: (LabourPalette.callAccent.color, LabourTheme.signal.opacity(0.22))
        }
    }

    var body: some View {
        Text(Self.label(level).uppercased())
            .font(MissionType.mono())
            .tracking(1.1)
            .foregroundStyle(colours.text)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 4).fill(colours.tint))
    }
}
