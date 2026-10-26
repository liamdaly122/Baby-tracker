import MissionCore
import SwiftUI

/// The advice at the top of the timer: headline, the reasons behind it, and a source.
public struct StateBanner: View {
    public var state: LabourState
    public var headline: String
    public var detail: String
    public var reasonLines: [String]
    public var source: String?
    public var isExpanded: Bool

    public init(
        state: LabourState,
        headline: String,
        detail: String,
        reasonLines: [String],
        source: String? = nil,
        isExpanded: Bool = false
    ) {
        self.state = state
        self.headline = headline
        self.detail = detail
        self.reasonLines = reasonLines
        self.source = source
        self.isExpanded = isExpanded
    }

    private var filled: Bool { LabourTheme.isFilled(state) }
    private var accent: Color { LabourTheme.color(for: state) }
    private var textColor: Color { filled ? .white : LabourTheme.primaryText }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headline)
                .font(.title2.weight(.bold))
                .foregroundStyle(filled ? .white : accent)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(reasonLines, id: \.self) { line in
                Text(line)
                    .font(.body)
                    .foregroundStyle(textColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if isExpanded {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(textColor.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                if let source {
                    Text("Source: \(source)")
                        .font(.footnote)
                        .foregroundStyle(textColor.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: LabourTheme.cornerRadius, style: .continuous)
                .fill(filled ? accent : LabourTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LabourTheme.cornerRadius, style: .continuous)
                .strokeBorder(filled ? Color.clear : accent.opacity(0.7), lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
