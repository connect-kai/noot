import Foundation

/// Small subsequence matcher used by the imported Tinycast Notes search model.
enum FuzzyMatch {
    struct Match: Sendable, Equatable {
        let score: Int
    }

    static func match(query: String, candidate: String) -> Match? {
        let needle = normalized(query)
        let haystack = normalized(candidate)
        guard !needle.isEmpty else { return Match(score: 0) }
        guard let range = haystack.range(of: needle) else {
            var index = haystack.startIndex
            var matched = 0
            for character in needle {
                guard let found = haystack[index...].firstIndex(of: character) else { return nil }
                matched += 1
                index = haystack.index(after: found)
            }
            return matched == needle.count ? Match(score: 100 - max(0, haystack.count - needle.count)) : nil
        }
        let position = haystack.distance(from: haystack.startIndex, to: range.lowerBound)
        return Match(score: 1_000 - position * 4 - max(0, haystack.count - needle.count))
    }

    static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
