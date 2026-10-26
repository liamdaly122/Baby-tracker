import Foundation

/// Offline search over the glossary for the jargon decoder: "what did the midwife just say?"
///
/// Matching ignores case, accents and punctuation, so "she's 6", "SROM" and "3/5 palpable" find
/// their entries however they're typed. Terms and aliases outrank the explanation text, and the
/// current labour stage nudges its own terms up.
public struct GlossaryIndex: Sendable {
    private struct Indexed: Sendable {
        var entry: GlossaryEntry
        var names: [String]
        var nameWords: [String]
        var explanation: String
        var explanationWords: [String]
    }

    private let indexed: [Indexed]

    public init(entries: [GlossaryEntry]) {
        indexed = entries.map { entry in
            let names = ([entry.term] + entry.aliases).map(Self.normalise).filter { !$0.isEmpty }
            let explanation = Self.normalise(entry.plainEnglish)
            return Indexed(
                entry: entry,
                names: names,
                nameWords: names.flatMap { $0.split(separator: " ").map(String.init) },
                explanation: explanation,
                explanationWords: explanation.split(separator: " ").map(String.init)
            )
        }
    }

    /// Ranked matches. An empty query lists everything, current stage first, then by term.
    public func search(_ query: String, stage: LabourStage? = nil, limit: Int = 25) -> [GlossaryEntry] {
        let normalised = Self.normalise(query)
        let words = normalised.split(separator: " ").map(String.init)
        let scored = indexed.compactMap { item -> (score: Int, entry: GlossaryEntry)? in
            var score = normalised.isEmpty ? 1 : Self.score(item, query: normalised, words: words)
            guard score > 0 else { return nil }
            if let stage, item.entry.stages.contains(stage) {
                score += 5
            }
            return (score, item.entry)
        }
        return
            scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                let lhsTerm = Self.normalise(lhs.entry.term)
                let rhsTerm = Self.normalise(rhs.entry.term)
                return lhsTerm != rhsTerm ? lhsTerm < rhsTerm : lhs.entry.id < rhs.entry.id
            }
            .prefix(limit)
            .map(\.entry)
    }

    private static func score(_ item: Indexed, query: String, words: [String]) -> Int {
        if item.names.contains(query) { return 100 }
        if item.names.contains(where: { $0.hasPrefix(query) }) { return 80 }
        if words.allSatisfy({ word in item.nameWords.contains { $0.hasPrefix(word) } }) { return 60 }
        if item.names.contains(where: { $0.contains(query) }) { return 40 }
        if words.allSatisfy({ word in item.explanationWords.contains { $0.hasPrefix(word) } }) { return 20 }
        if item.explanation.contains(query) { return 10 }
        return 0
    }

    /// Lowercase, no accents, apostrophes dropped ("she's" → "shes"), other punctuation as spaces.
    static func normalise(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).lowercased()
        var result = ""
        var lastWasSpace = true
        for character in folded {
            if character == "'" || character == "\u{2019}" {
                continue
            }
            if character.isLetter || character.isNumber {
                result.append(character)
                lastWasSpace = false
            } else if !lastWasSpace {
                result.append(" ")
                lastWasSpace = true
            }
        }
        return lastWasSpace && !result.isEmpty ? String(result.dropLast()) : result
    }
}
