import Foundation

/// A number he can tap to call, checked when it's saved rather than discovered wrong in labour.
///
/// UK numbers are stored in E.164 form (+441133926731), which iOS dials reliably, and the usual ways
/// of writing or pasting them all work: spaces, dashes of any kind, brackets, "+44 (0)113…",
/// "0044…", "Tel:", and the invisible marks iOS adds when copying from Contacts. Menu options and
/// extensions ("option 2", "ext 4", "*2#") become a note to read once connected, because iOS won't
/// dial a number containing * or #. Letters, two numbers in one field, numbers a digit short and
/// overseas numbers (unless allowed) are rejected, so the mistake shows up at setup, not at 3am.
public struct PhoneNumber: Codable, Sendable, Hashable {
    public enum Problem: String, Error, Codable, Sendable, CaseIterable {
        case empty
        case letters
        case twoNumbers
        case tooShort
        case tooLong
        /// Not a valid number for its country.
        case invalid
        /// A country other than the UK or US, when overseas numbers aren't allowed.
        case overseas
    }

    /// What was typed or pasted.
    public private(set) var raw: String
    /// What gets dialled: E.164 such as +441133926731, or a short code such as 999.
    public private(set) var dialable: String
    /// How to show it: "0113 392 6731".
    public private(set) var display: String
    /// What to do once connected: "Then press 2" or "Ask for extension 4".
    public private(set) var afterConnecting: String?

    /// A tel: link, only if the dialable form is digits with an optional leading +.
    public var telURL: URL? {
        Self.isDialable(dialable) ? URL(string: "tel:\(dialable)") : nil
    }

    public var isShortCode: Bool { Self.shortCodes[dialable] != nil }

    init(raw: String, dialable: String, display: String, afterConnecting: String?) {
        self.raw = raw
        self.dialable = dialable
        self.display = display
        self.afterConnecting = afterConnecting
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        raw = try container.decode(String.self, forKey: .raw)
        dialable = try container.decode(String.self, forKey: .dialable)
        display = try container.decode(String.self, forKey: .display)
        afterConnecting = try container.decodeIfPresent(String.self, forKey: .afterConnecting)
        // A saved number must still parse to itself, so it can't show one number and dial another.
        guard let checked = Self.recheck(dialable) else {
            throw DecodingError.dataCorruptedError(
                forKey: .dialable, in: container, debugDescription: "Not a valid number")
        }
        display = checked.display
    }

    /// Parses a stored dialable form again: a short code, +44, +1, or (only if it was allowed when
    /// saved) another country. Nil unless it comes back unchanged.
    static func recheck(_ dialable: String) -> PhoneNumber? {
        guard isDialable(dialable) else { return nil }
        if let short = shortCode(dialable) { return short }
        let region: ContentRegion = dialable.hasPrefix("+1") ? .us : .uk
        let parsed = try? parse(dialable, region: region, allowOverseas: true).get()
        return parsed?.dialable == dialable ? parsed : nil
    }

    static func isDialable(_ text: String) -> Bool {
        let digits = text.hasPrefix("+") ? text.dropFirst() : Substring(text)
        return (3...15).contains(digits.count) && digits.allSatisfy(\.isASCIIDigitCharacter)
    }

    /// 999, 111 and the other numbers dialled exactly as they are.
    public static func shortCode(_ digits: String) -> PhoneNumber? {
        guard let display = shortCodes[digits] else { return nil }
        return PhoneNumber(raw: digits, dialable: digits, display: display, afterConnecting: nil)
    }

    static let shortCodes = [
        "999": "999", "111": "111", "112": "112", "911": "911", "116123": "116 123", "116117": "116 117",
    ]

    public static func parse(
        _ text: String,
        region: ContentRegion,
        allowOverseas: Bool = false
    ) -> Result<PhoneNumber, Problem> {
        let cleaned = normalised(text)
        guard !cleaned.isEmpty else { return .failure(.empty) }
        let split: Split
        switch Split.make(cleaned) {
        case .success(let value): split = value
        case .failure(let problem): return .failure(problem)
        }
        guard !split.number.isEmpty else { return .failure(.letters) }

        var compact = split.number
        // "+44 (0)113…", "(+353) (0)87…": the bracketed 0 after a country code isn't dialled.
        if let plus = compact.firstIndex(of: "+") ?? (compact.hasPrefix("00") ? compact.startIndex : nil),
            let range = compact.range(of: "(0)", range: plus..<compact.endIndex)
        {
            compact.removeSubrange(range)
        }
        compact = compact.filter { !"()-.".contains($0) }
        if compact.hasPrefix("00") {
            compact = "+" + compact.dropFirst(2)
        } else if region == .us && compact.hasPrefix("011") {
            // An international call from the US needs a full-length number after 011.
            guard compact.count - 3 >= 10 else { return .failure(.tooShort) }
            compact = "+" + compact.dropFirst(3)
        }
        let digits = compact.hasPrefix("+") ? String(compact.dropFirst()) : compact
        guard !digits.isEmpty, digits.allSatisfy(\.isASCIIDigitCharacter) else { return .failure(.letters) }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !compact.hasPrefix("+"), let short = shortCode(digits) {
            return .success(
                PhoneNumber(
                    raw: trimmed, dialable: short.dialable, display: short.display,
                    afterConnecting: split.afterConnecting))
        }
        let parsed: Result<(dialable: String, display: String), Problem>
        if compact.hasPrefix("+") {
            parsed = international(digits, allowOverseas: allowOverseas)
        } else {
            switch region {
            // UK numbers are written with their leading 0; ten digits without one are probably a US number.
            case .uk: parsed = digits.hasPrefix("0") ? uk(significant: String(digits.dropFirst())) : .failure(.invalid)
            case .us: parsed = digits.hasPrefix("0") ? .failure(.invalid) : nanp(digits)
            }
        }
        return parsed.map {
            PhoneNumber(
                raw: trimmed, dialable: $0.dialable, display: $0.display, afterConnecting: split.afterConnecting)
        }
    }

    /// Removes invisible marks and maps look-alike dashes, spaces and full-width digits.
    static func normalised(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x200B...0x200F, 0x202A...0x202E, 0x2060...0x2064, 0xFEFF:
                continue
            case 0x2010...0x2015, 0x2212, 0xFE58, 0xFE63, 0xFF0D:
                result.append("-")
            case 0x00A0, 0x2007, 0x2009, 0x202F, 0x000A, 0x000D, 0x0009:
                result.append(" ")
            case 0xFF10...0xFF19:
                result.append(Character(UnicodeScalar(scalar.value - 0xFF10 + 0x30) ?? "0"))
            default:
                result.unicodeScalars.append(scalar)
            }
        }
        var trimmed = result.trimmingCharacters(in: .whitespaces)
        while let last = trimmed.last, last == "." || last == "," || last == ";" {
            trimmed.removeLast()
        }
        return trimmed
    }

    private static func international(
        _ digits: String,
        allowOverseas: Bool
    ) -> Result<(dialable: String, display: String), Problem> {
        if digits.hasPrefix("44") {
            var national = String(digits.dropFirst(2))
            // "+44 0113…": the 0 doesn't belong after the country code.
            if national.hasPrefix("0") { national.removeFirst() }
            return uk(significant: national)
        }
        if digits.hasPrefix("1") {
            return nanp(String(digits.dropFirst()))
        }
        guard allowOverseas else { return .failure(.overseas) }
        if digits.count < 8 { return .failure(.tooShort) }
        if digits.count > 15 { return .failure(.tooLong) }
        return .success(("+" + digits, "+" + digits))
    }

    /// UK numbers have 10 digits after the leading 0, starting 1, 2, 3, 5, 7, 8 or 9. A few have 9:
    /// some 0800 numbers, and areas with five-digit local numbers (01xxx and 01xxxx codes, but never
    /// the big-city 011x or 01x1 codes). Any other 9-digit number is almost certainly missing a digit.
    private static func uk(significant: String) -> Result<(dialable: String, display: String), Problem> {
        if significant.count > 10 { return .failure(.tooLong) }
        if significant.count < 9 { return .failure(.tooShort) }
        let digits = Array(significant)
        guard "1235789".contains(digits[0]) else { return .failure(.invalid) }
        if significant.count == 9 {
            let mixedArea = digits[0] == "1" && digits[1] != "1" && digits[2] != "1"
            guard significant.hasPrefix("800") || mixedArea else { return .failure(.tooShort) }
        }
        return .success(("+44" + significant, ukDisplay(significant)))
    }

    /// US and Canadian numbers: 10 digits, with the area code and exchange starting 2 to 9.
    private static func nanp(_ digits: String) -> Result<(dialable: String, display: String), Problem> {
        let national = digits.count == 11 && digits.hasPrefix("1") ? String(digits.dropFirst()) : digits
        if national.count < 10 { return .failure(.tooShort) }
        if national.count > 10 { return .failure(.tooLong) }
        let characters = Array(national)
        guard "23456789".contains(characters[0]), "23456789".contains(characters[3]) else {
            return .failure(.invalid)
        }
        return .success(("+1" + national, usDisplay(national)))
    }

    /// Area codes with six digits, written 01xxxx xxxxx.
    static let sixDigitAreaCodes: Set<String> = [
        "13873", "15242", "15394", "15395", "15396", "16973", "16974", "16977", "17683", "17684",
        "17687", "19467", "19755", "19756",
    ]

    /// "0113 392 6731", "020 7946 0000", "07700 900123", "0800 123 4567", "01234 567890",
    /// "016977 12345", "0800 123 456", "056 1234 5678".
    static func ukDisplay(_ significant: String) -> String {
        let national = Array("0" + significant)
        let first = Array(significant)
        let sizes: [Int]
        if sixDigitAreaCodes.contains(String(significant.prefix(5))) {
            sizes = [6, 5]
        } else if significant.count == 9 && first[0] == "1" {
            sizes = [5, 5]
        } else if significant.count == 9 {
            sizes = significant.hasPrefix("800") ? [4, 3, 3] : [5, 5]
        } else if first[0] == "7" {
            sizes = [5, 6]
        } else if first[0] == "2" || first[0] == "5" {
            sizes = [3, 4, 4]
        } else if first[0] == "1" && (first[1] == "1" || first[2] == "1") {
            sizes = [4, 3, 4]
        } else if "389".contains(first[0]) {
            sizes = [4, 3, 4]
        } else {
            sizes = [5, 6]
        }
        var groups: [String] = []
        var index = 0
        for size in sizes where index < national.count {
            groups.append(String(national[index..<min(index + size, national.count)]))
            index += size
        }
        if index < national.count {
            groups.append(String(national[index...]))
        }
        return groups.joined(separator: " ")
    }

    static func usDisplay(_ national: String) -> String {
        let digits = Array(national)
        return "(\(String(digits[0..<3]))) \(String(digits[3..<6]))-\(String(digits[6...]))"
    }
}

/// The number part of a field, and anything to do after connecting.
private struct Split {
    var number: String
    var afterConnecting: String?

    static let pressWords = ["option", "opt", "press"]
    static let extensionWords = ["extension", "ext", "x"]
    static let separators: Set<String> = ["/", ",", ";", "&", "|", "or", "and"]
    static let labels: Set<String> = [
        "tel", "tel:", "tel.", "telephone", "telephone:", "phone", "phone:", "mobile", "mobile:", "t", "t:",
        "call", "triage", "triage:",
    ]
    static let numberCharacters = Set("0123456789+()-.")

    static func make(_ text: String) -> Result<Split, PhoneNumber.Problem> {
        var spaced = text
        for mark in ["/", ",", ";", "&", "|"] {
            spaced = spaced.replacingOccurrences(of: mark, with: " \(mark) ")
        }
        var tokens = spaced.split(whereSeparator: \.isWhitespace).map(String.init)
        if let first = tokens.first, first.lowercased().hasPrefix("tel:"), first.count > 4 {
            tokens[0] = String(first.dropFirst(4))
        }
        var number = ""
        var sawSeparator = false
        var keyword: String?
        var rest: [String] = []
        for token in tokens {
            let lower = token.lowercased()
            let bare = lower.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            if keyword != nil {
                rest.append(token.trimmingCharacters(in: CharacterSet(charactersIn: "()")))
                continue
            }
            if number.isEmpty && labels.contains(lower) {
                continue
            }
            if !number.isEmpty, let (word, inline) = instruction(bare) {
                keyword = word
                if !inline.isEmpty { rest.append(inline) }
                continue
            }
            if !number.isEmpty && !token.isEmpty && token.allSatisfy({ "0123456789*#".contains($0) })
                && token.contains(where: { $0 == "*" || $0 == "#" })
            {
                keyword = "press"
                rest.append(token)
                continue
            }
            if separators.contains(lower) || lower == "-" {
                sawSeparator = sawSeparator || (!number.isEmpty && lower != "-")
                continue
            }
            if token.allSatisfy({ numberCharacters.contains($0) }) {
                if sawSeparator { return .failure(.twoNumbers) }
                number += token
                continue
            }
            return .failure(.letters)
        }
        let detailTokens = rest.filter { !separators.contains($0.lowercased()) && !$0.isEmpty }
        // A second phone number hidden in the note ("option 2 or 0113 206 5781").
        if detailTokens.joined().filter(\.isASCIIDigitCharacter).count >= 7 {
            return .failure(.twoNumbers)
        }
        var note: String?
        let detail = detailTokens.joined(separator: " ")
        if let keyword, !detail.isEmpty {
            note = extensionWords.contains(keyword) ? "Ask for extension \(detail)" : "Then press \(detail)"
        }
        return .success(Split(number: number, afterConnecting: note))
    }

    /// "option", "ext 4", "x4", "opt.2": the word and anything stuck to it.
    static func instruction(_ token: String) -> (String, String)? {
        for word in pressWords + extensionWords where token.hasPrefix(word) {
            let inline = token.dropFirst(word.count).drop { $0 == "." || $0 == ":" }
            if inline.isEmpty || inline.allSatisfy({ "0123456789*#".contains($0) }) {
                return (word, String(inline))
            }
        }
        return nil
    }
}

extension Character {
    fileprivate var isASCIIDigitCharacter: Bool { ("0"..."9").contains(self) }
}
