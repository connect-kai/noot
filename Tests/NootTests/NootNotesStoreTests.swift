import Foundation
import XCTest
@testable import Noot

@MainActor
final class NootNotesStoreTests: XCTestCase {
    func testDirtyDraftFlushesBeforeSelectingAnotherNote() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NootNotesStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = NootNotesRepository(directory: directory)
        let first = try repository.create(title: "First", source: "one")
        let second = try repository.create(title: "Second", source: "two")
        let store = NootNotesStore(repository: repository)

        let started = await store.start()
        XCTAssertTrue(started)
        let selectedFirst = await store.select(first.id)
        XCTAssertTrue(selectedFirst)
        store.updateSource("changed")
        let selectedSecond = await store.select(second.id)
        XCTAssertTrue(selectedSecond)
        XCTAssertEqual(try repository.load(first.id).source, "changed")
    }

    func testSearchIsCancelableAndUsesRepositoryResults() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NootNotesStoreSearchTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = NootNotesRepository(directory: directory)
        _ = try repository.create(title: "Alpha", source: "needle")
        let store = NootNotesStore(repository: repository)
        let started = await store.start()
        XCTAssertTrue(started)
        store.updateSearchQuery("needle")
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(store.searchResults.count, 1)
        store.updateSearchQuery("")
        XCTAssertTrue(store.searchResults.isEmpty)
        XCTAssertFalse(store.isSearching)
    }
}
