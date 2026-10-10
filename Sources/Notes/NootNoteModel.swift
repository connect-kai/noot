import Foundation

/// Stable identity and file-backed state for the refactored Notes feature.
struct NootNoteID: RawRepresentable, Hashable, Sendable {
    let rawValue: String
}

struct NootNoteSummary: Identifiable, Equatable, Sendable {
    let id: NootNoteID
    let title: String
    let firstLine: String?
    let modifiedAt: Date

    var displayTitle: String { firstLine ?? title }
}

struct NootNoteDocument: Equatable, Sendable {
    let id: NootNoteID
    let source: String
}

struct NootNoteSearchResult: Identifiable, Equatable, Sendable {
    var id: NootNoteID { summary.id }
    let summary: NootNoteSummary
    let score: Int
}
