import Foundation

/// File-system boundary for Notes. UI and editor code should not perform file IO directly.
struct NootNotesRepository: Sendable {
    enum Failure: Error, LocalizedError, Equatable, Sendable {
        case invalidTitle(String)
        case unreadable(URL)
        case invalidLocation(URL)
        case io(URL, String)

        var errorDescription: String? {
            switch self {
            case .invalidTitle(let title): return "\u{201c}\(title)\u{201d} can't be used as a note title."
            case .unreadable(let url): return "The note isn't valid UTF-8. (\(url.lastPathComponent))"
            case .invalidLocation(let url): return "The note is outside the Notes folder. (\(url.path))"
            case .io(let url, let message): return "Could not access \(url.path): \(message)"
            }
        }
    }

    struct Incoming: Equatable, Sendable {
        let title: String
        let source: String
    }

    let directory: URL
    private let trashOperation: @Sendable (URL) throws -> Void

    init(
        directory: URL,
        trashOperation: @escaping @Sendable (URL) throws -> Void = { url in
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
    ) {
        self.directory = directory
        self.trashOperation = trashOperation
    }

    func list() throws -> [NootNoteSummary] {
        try ensureDirectory()
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isHiddenKey,
                                         .isRegularFileKey, .isSymbolicLinkKey]
        do {
            return try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]
            ).compactMap { url -> NootNoteSummary? in
                guard url.pathExtension.caseInsensitiveCompare("md") == .orderedSame,
                      let values = try? url.resourceValues(forKeys: keys),
                      values.isRegularFile == true, values.isSymbolicLink != true,
                      values.isHidden != true, let safeURL = try? validatedFileURL(url)
                else { return nil }
                let title = safeURL.deletingPathExtension().lastPathComponent
                return NootNoteSummary(
                    id: NootNoteID(rawValue: safeURL.lastPathComponent), title: title,
                    firstLine: title == "Untitled" ? firstLine(of: safeURL) : nil,
                    modifiedAt: values.contentModificationDate ?? .distantPast)
            }.sorted {
                if $0.modifiedAt != $1.modifiedAt { return $0.modifiedAt > $1.modifiedAt }
                return $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
            }
        } catch { throw failure(at: directory, error) }
    }

    func load(_ id: NootNoteID) throws -> NootNoteDocument {
        let url = try validatedFileURL(fileURL(for: id))
        do {
            let data = try Data(contentsOf: url)
            guard let source = String(data: data, encoding: .utf8) else { throw Failure.unreadable(url) }
            return NootNoteDocument(id: id, source: source)
        } catch let error as Failure { throw error }
        catch { throw failure(at: url, error) }
    }

    func create(title: String = "Untitled", source: String = "") throws -> NootNoteDocument {
        try ensureDirectory()
        let base = try validatedTitle(title)
        let url = try uniqueURL(base: base) { try Data(source.utf8).write(to: $0, options: .atomic) }
        return try load(NootNoteID(rawValue: url.lastPathComponent))
    }

    func save(id: NootNoteID, source: String) throws {
        let url = try validatedFileURL(fileURL(for: id))
        do { try Data(source.utf8).write(to: url, options: .atomic) }
        catch { throw failure(at: url, error) }
    }

    func rename(id: NootNoteID, to title: String) throws -> NootNoteID {
        let source = try validatedFileURL(fileURL(for: id))
        let base = try validatedTitle(title)
        let destination = try uniqueURL(base: base, excluding: id) { url in
            do { try FileManager.default.moveItem(at: source, to: url) }
            catch { throw failure(at: source, error) }
        }
        return NootNoteID(rawValue: destination.lastPathComponent)
    }

    func trash(id: NootNoteID) throws {
        let url = try validatedFileURL(fileURL(for: id))
        do { try trashOperation(url) }
        catch { throw failure(at: url, error) }
    }

    @discardableResult
    func importNotes(_ notes: [Incoming]) throws -> Int {
        try ensureDirectory()
        var count = 0
        for note in notes {
            guard let title = try? validatedTitle(note.title) else { continue }
            _ = try uniqueURL(base: title) { try Data(note.source.utf8).write(to: $0, options: .atomic) }
            count += 1
        }
        return count
    }

    func search(_ query: String, summaries: [NootNoteSummary], limit: Int = 200) -> [NootNoteSearchResult] {
        let terms = query.split(whereSeparator: \Character.isWhitespace).map(String.init)
        guard !terms.isEmpty, limit > 0 else { return [] }
        return summaries.compactMap { summary in
            let title = summary.displayTitle
            var score = 0
            for term in terms {
                if let range = title.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) {
                    score += 2_000 + max(0, 500 - title.distance(from: title.startIndex, to: range.lowerBound))
                } else {
                    guard let source = try? load(summary.id).source,
                          source.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                    else { return nil }
                }
            }
            return NootNoteSearchResult(summary: summary, score: score)
        }.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.summary.modifiedAt > $1.summary.modifiedAt
        }.prefix(limit).map { $0 }
    }

    func fileURL(for id: NootNoteID) -> URL { directory.appendingPathComponent(id.rawValue) }

    private func ensureDirectory() throws {
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { throw failure(at: directory, error) }
    }

    private func validatedFileURL(_ candidate: URL) throws -> URL {
        let parent = directory.standardizedFileURL.resolvingSymlinksInPath()
        let resolved = candidate.standardizedFileURL.resolvingSymlinksInPath()
        guard resolved.deletingLastPathComponent() == parent else { throw Failure.invalidLocation(candidate) }
        return candidate
    }

    private func validatedTitle(_ raw: String) throws -> String {
        let title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalid = CharacterSet(charactersIn: "/\\:\0")
        guard !title.isEmpty, title != ".", title != "..", title.rangeOfCharacter(from: invalid) == nil
        else { throw Failure.invalidTitle(raw) }
        return title.hasSuffix(".md") ? String(title.dropLast(3)) : title
    }

    private func uniqueURL(
        base: String, excluding: NootNoteID? = nil,
        write: (URL) throws -> Void
    ) throws -> URL {
        var suffix = 1
        while true {
            let name = suffix == 1 ? "\(base).md" : "\(base) \(suffix).md"
            let url = directory.appendingPathComponent(name)
            if let excluding, url.lastPathComponent == excluding.rawValue { return url }
            if !FileManager.default.fileExists(atPath: url.path) {
                try write(url)
                return url
            }
            suffix += 1
        }
    }

    private func firstLine(of url: URL) -> String? {
        guard let source = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return source.split(whereSeparator: \Character.isNewline).first {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }.map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    private func failure(at url: URL, _ error: Error) -> Failure {
        if let failure = error as? Failure { return failure }
        return .io(url, error.localizedDescription)
    }
}
