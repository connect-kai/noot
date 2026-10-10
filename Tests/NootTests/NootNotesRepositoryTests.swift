import Foundation
import XCTest
@testable import Noot

final class NootNotesRepositoryTests: XCTestCase {
    private final class URLBox: @unchecked Sendable {
        var value: URL?
    }

    private func makeRepository() throws -> (NootNotesRepository, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("NootNotesRepositoryTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return (NootNotesRepository(directory: url), url)
    }

    func testCreateSaveRenameAndSearch() throws {
        let (repository, directory) = try makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = try repository.create(title: "Ideas", source: "# Launch\nalpha")
        let second = try repository.create(title: "Ideas")
        XCTAssertEqual(second.id.rawValue, "Ideas 2.md")
        XCTAssertEqual(try repository.load(first.id).source, "# Launch\nalpha")

        try repository.save(id: second.id, source: "beta")
        let renamed = try repository.rename(id: second.id, to: "Archive")
        XCTAssertEqual(renamed.rawValue, "Archive.md")

        let summaries = try repository.list()
        let results = repository.search("launch", summaries: summaries)
        XCTAssertEqual(results.map(\.summary.id), [first.id])
    }

    func testRejectsPathTraversalAndSkipsInvalidImportTitles() throws {
        let (repository, directory) = try makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertThrowsError(try repository.create(title: "../outside")) { error in
            XCTAssertEqual(error as? NootNotesRepository.Failure, .invalidTitle("../outside"))
        }
        let imported = try repository.importNotes([
            .init(title: "Good", source: "ok"),
            .init(title: "bad/name", source: "skip")
        ])
        XCTAssertEqual(imported, 1)
        XCTAssertEqual(try repository.list().map(\.title), ["Good"])
    }

    func testTrashUsesInjectedOperation() throws {
        let (base, directory) = try makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }
        let note = try base.create(title: "Trash me")
        let trashed = URLBox()
        let repository = NootNotesRepository(directory: directory) { url in trashed.value = url }
        try repository.trash(id: note.id)
        XCTAssertEqual(trashed.value?.lastPathComponent, "Trash me.md")
    }
}
