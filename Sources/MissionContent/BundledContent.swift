import Foundation
import MissionCore

public enum BundledContentError: Error, Equatable {
    case missingFile(kind: ContentKind, region: ContentRegion)
}

/// Access to the JSON content that ships inside the app, so everything works offline.
public enum BundledContent {
    public static func url(for kind: ContentKind, region: ContentRegion) -> URL? {
        Bundle.module.url(
            forResource: kind.rawValue,
            withExtension: "json",
            subdirectory: "Content/\(region.rawValue)"
        )
    }

    /// The content files present for a region. Kinds are added to the bundle phase by phase.
    public static func availableKinds(for region: ContentRegion) -> [ContentKind] {
        ContentKind.allCases.filter { url(for: $0, region: region) != nil }
    }

    public static func data(for kind: ContentKind, region: ContentRegion) throws -> Data {
        guard let url = url(for: kind, region: region) else {
            throw BundledContentError.missingFile(kind: kind, region: region)
        }
        return try Data(contentsOf: url)
    }

    public static func envelope<Item: Codable & Sendable>(
        _ type: Item.Type,
        kind: ContentKind,
        region: ContentRegion
    ) throws -> ContentEnvelope<Item> {
        try ContentDecoding.envelope(type, from: data(for: kind, region: region), expectedRegion: region)
    }

    /// The region's threshold table from thresholds.json.
    public static func thresholdTable(for region: ContentRegion) throws -> ThresholdTable {
        try ThresholdTable(file: envelope(ThresholdItem.self, kind: .thresholds, region: region))
    }
}
