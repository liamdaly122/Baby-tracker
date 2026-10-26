import Foundation

/// The editable fields of the go/no-go threshold profile.
public enum ThresholdField: String, Codable, Sendable, CaseIterable {
    /// Call for advice when the median start-to-start interval is at or below this.
    case adviceIntervalSec
    /// Median duration needed for the call-for-advice rule. 0 switches the rule off (UK default).
    case adviceDurationSec
    /// How long the pattern must hold before "Time to call". 0 switches the hold off (UK default:
    /// the NHS gives no time). When on, 30 to 60 minutes; it can never be longer than an hour.
    case patternWindowSec
    /// Any contraction longer than this means call now. Can be tightened, never relaxed.
    case urgentSingleDurationSec
    /// This many contraction starts inside any 10 minutes means call now.
    case urgentCountIn10Min
    /// How far over the advice interval the upper quartile of gaps may run for a pattern at the
    /// limit to count as regular (0.35: median at or under 5 minutes, three in four at or under 6:45).
    /// Frequent contractions meet the call rule whatever their spread. Also used to describe a
    /// pattern as regular or uneven (interquartile range over the median).
    case regularityCV
    /// Shorter required window for second and later babies, a fast previous labour or a long trip.
    case earlyCallerWindowSec
    /// A journey longer than this makes the user an early caller.
    case travelEarlyCallMinutes

    /// Whether a higher value makes the app suggest calling sooner. A change in the other direction
    /// delays the advice and should only be made on a midwife's instructions.
    public var higherCallsSooner: Bool {
        switch self {
        case .adviceIntervalSec, .regularityCV: true
        case .adviceDurationSec, .patternWindowSec, .urgentSingleDurationSec, .urgentCountIn10Min,
            .earlyCallerWindowSec, .travelEarlyCallMinutes:
            false
        }
    }
}

/// The thresholds the engine runs with. Always built through `ThresholdTable` so values are clamped.
public struct ThresholdProfile: Codable, Sendable, Hashable {
    public var adviceIntervalSec: Double
    public var adviceDurationSec: Double
    public var patternWindowSec: Double
    public var urgentSingleDurationSec: Double
    public var urgentCountIn10Min: Int
    public var regularityCV: Double
    public var earlyCallerWindowSec: Double
    public var travelEarlyCallMinutes: Double

    public subscript(field: ThresholdField) -> Double {
        get {
            switch field {
            case .adviceIntervalSec: adviceIntervalSec
            case .adviceDurationSec: adviceDurationSec
            case .patternWindowSec: patternWindowSec
            case .urgentSingleDurationSec: urgentSingleDurationSec
            case .urgentCountIn10Min: Double(urgentCountIn10Min)
            case .regularityCV: regularityCV
            case .earlyCallerWindowSec: earlyCallerWindowSec
            case .travelEarlyCallMinutes: travelEarlyCallMinutes
            }
        }
        set {
            switch field {
            case .adviceIntervalSec: adviceIntervalSec = newValue
            case .adviceDurationSec: adviceDurationSec = newValue
            case .patternWindowSec: patternWindowSec = newValue
            case .urgentSingleDurationSec: urgentSingleDurationSec = newValue
            case .urgentCountIn10Min: urgentCountIn10Min = Int(newValue.rounded())
            case .regularityCV: regularityCV = newValue
            case .earlyCallerWindowSec: earlyCallerWindowSec = newValue
            case .travelEarlyCallMinutes: travelEarlyCallMinutes = newValue
            }
        }
    }
}

/// Default and safe bounds for one threshold field.
public struct ThresholdLimit: Codable, Sendable, Hashable {
    public var defaultValue: Double
    public var min: Double
    public var max: Double
    public var allowsDisabled: Bool

    public init(defaultValue: Double, min: Double, max: Double, allowsDisabled: Bool = false) {
        self.defaultValue = defaultValue
        self.min = min
        self.max = max
        self.allowsDisabled = allowsDisabled
    }

    /// A field whose min equals its max cannot be changed in settings.
    public var isEditable: Bool { min < max || allowsDisabled }

    public func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return defaultValue }
        if allowsDisabled && value <= 0 { return 0 }
        return Swift.min(Swift.max(value, min), max)
    }
}

public enum ThresholdTableError: Error, Equatable {
    case missingField(ThresholdField)
    case duplicateField(ThresholdField)
}

/// Region defaults plus safe bounds. Overrides from settings (or a midwife's advice) are clamped here.
public struct ThresholdTable: Sendable, Hashable {
    public let region: ContentRegion
    public let limits: [ThresholdField: ThresholdLimit]

    public init(region: ContentRegion, limits: [ThresholdField: ThresholdLimit]) throws {
        for field in ThresholdField.allCases where limits[field] == nil {
            throw ThresholdTableError.missingField(field)
        }
        self.init(validatedRegion: region, limits: limits)
    }

    private init(validatedRegion region: ContentRegion, limits: [ThresholdField: ThresholdLimit]) {
        self.region = region
        self.limits = limits
    }

    /// Builds the table from a decoded thresholds.json.
    public init(file: ContentEnvelope<ThresholdItem>) throws {
        var limits: [ThresholdField: ThresholdLimit] = [:]
        for item in file.items {
            guard limits[item.id] == nil else { throw ThresholdTableError.duplicateField(item.id) }
            limits[item.id] = ThresholdLimit(
                defaultValue: item.defaultValue,
                min: item.min,
                max: item.max,
                allowsDisabled: item.allowsDisabled
            )
        }
        try self.init(region: file.region, limits: limits)
    }

    public func limit(for field: ThresholdField) -> ThresholdLimit {
        // The initialisers guarantee every field is present; the fallback is unreachable.
        limits[field] ?? ThresholdTable.builtIn(for: region).limit(for: field)
    }

    public var defaults: ThresholdProfile {
        profile(applying: [:])
    }

    /// `profile` with every field clamped to its safe bounds.
    public func clamped(_ profile: ThresholdProfile) -> ThresholdProfile {
        var result = profile
        for field in ThresholdField.allCases {
            result[field] = limit(for: field).clamp(profile[field])
        }
        return result
    }

    /// True if `value` makes the advice come later than the default does, so the editor can say
    /// "only if your midwife told you".
    public func delaysAdvice(_ field: ThresholdField, value: Double) -> Bool {
        let clamped = limit(for: field).clamp(value)
        let defaultValue = limit(for: field).defaultValue
        return field.higherCallsSooner ? clamped < defaultValue : clamped > defaultValue
    }

    /// The defaults with any overrides applied, each clamped to its safe bounds.
    public func profile(applying overrides: [ThresholdField: Double]) -> ThresholdProfile {
        var profile = ThresholdProfile(
            adviceIntervalSec: 0,
            adviceDurationSec: 0,
            patternWindowSec: 0,
            urgentSingleDurationSec: 0,
            urgentCountIn10Min: 0,
            regularityCV: 0,
            earlyCallerWindowSec: 0,
            travelEarlyCallMinutes: 0
        )
        for field in ThresholdField.allCases {
            let limit = limit(for: field)
            profile[field] = limit.clamp(overrides[field] ?? limit.defaultValue)
        }
        return profile
    }
}

extension ThresholdTable {
    /// Compiled-in copy of thresholds.json, used if the bundled file cannot be read so the timer
    /// still works. A test keeps it identical to the JSON.
    public static func builtIn(for region: ContentRegion) -> ThresholdTable {
        let adviceDuration: ThresholdLimit =
            switch region {
            case .uk: ThresholdLimit(defaultValue: 0, min: 30, max: 90, allowsDisabled: true)
            case .us: ThresholdLimit(defaultValue: 60, min: 30, max: 90, allowsDisabled: true)
            }
        let patternWindow: ThresholdLimit =
            switch region {
            case .uk: ThresholdLimit(defaultValue: 0, min: 1800, max: 3600, allowsDisabled: true)
            case .us: ThresholdLimit(defaultValue: 3600, min: 1800, max: 3600)
            }
        let limits: [ThresholdField: ThresholdLimit] = [
            .adviceIntervalSec: ThresholdLimit(defaultValue: 300, min: 180, max: 420),
            .adviceDurationSec: adviceDuration,
            .patternWindowSec: patternWindow,
            .urgentSingleDurationSec: ThresholdLimit(defaultValue: 120, min: 90, max: 120),
            .urgentCountIn10Min: ThresholdLimit(defaultValue: 6, min: 5, max: 6),
            .regularityCV: ThresholdLimit(defaultValue: 0.35, min: 0.25, max: 0.5),
            .earlyCallerWindowSec: ThresholdLimit(defaultValue: 1800, min: 1800, max: 1800),
            .travelEarlyCallMinutes: ThresholdLimit(defaultValue: 30, min: 30, max: 30),
        ]
        return ThresholdTable(validatedRegion: region, limits: limits)
    }
}
