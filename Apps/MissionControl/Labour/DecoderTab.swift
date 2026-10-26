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
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(LabourTheme.secondaryText)
                TextField("What did they say? “the drip”, “she's 6”", text: $query)
                    .font(.title3)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($searchFocused)
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(LabourTheme.secondaryText)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: LabourTheme.minimumControlSize)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LabourTheme.surface))
            .padding(16)

            let results = (index ?? GlossaryIndex(entries: model.library.glossary)).search(
                query, stage: stage, limit: 100)
            if results.isEmpty {
                Text("Nothing found. Ask them: “Can you explain that in plain English?”")
                    .foregroundStyle(LabourTheme.secondaryText)
                    .padding(16)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(results) { entry in
                            GlossaryRow(entry: entry, isExpanded: expanded == entry.id || results.count == 1) {
                                withAnimation { expanded = expanded == entry.id ? nil : entry.id }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.immediately)
            }
        }
        .onAppear {
            if index == nil {
                index = GlossaryIndex(entries: model.library.glossary)
            }
        }
    }
}

private struct GlossaryRow: View {
    var entry: GlossaryEntry
    var isExpanded: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.term)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(LabourTheme.primaryText)
                    Spacer()
                    WorryBadge(level: entry.worryLevel)
                }
                Text(entry.plainEnglish)
                    .font(.body)
                    .foregroundStyle(LabourTheme.primaryText.opacity(0.9))
                    .lineLimit(isExpanded ? nil : 2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if isExpanded {
                    Label {
                        Text("Ask: “\(entry.questionToAsk)”").fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "bubble.left.fill").foregroundStyle(LabourTheme.amber)
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(LabourTheme.primaryText)
                    if !entry.aliases.isEmpty {
                        Text("Also: \(entry.aliases.joined(separator: ", "))")
                            .font(.footnote)
                            .foregroundStyle(LabourTheme.secondaryText)
                    }
                    Text("Source: \(entry.provenance.sourceTitle)")
                        .font(.footnote)
                        .foregroundStyle(LabourTheme.secondaryText)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LabourTheme.surface))
        }
        .buttonStyle(.plain)
    }
}

/// How much to worry, in words as well as colour.
private struct WorryBadge: View {
    var level: Int

    private var text: String {
        switch level {
        case 0: "Normal"
        case 1: "Worth asking"
        case 2: "Pay attention"
        default: "Act now"
        }
    }

    private var colour: Color {
        switch level {
        case 0: LabourTheme.secondaryText
        case 1: LabourTheme.primaryText
        case 2: LabourTheme.amber
        default: LabourTheme.urgent
        }
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(colour)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(Capsule().strokeBorder(colour.opacity(0.7), lineWidth: 1))
    }
}
