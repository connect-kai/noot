import Foundation
import Combine

/// Main-actor state machine for Notes. Persistence runs outside the UI lifecycle.
@MainActor
final class NootNotesStore: ObservableObject {
    enum Issue: Equatable {
        case load(NootNotesRepository.Failure)
        case save(NootNotesRepository.Failure)
        case operation(NootNotesRepository.Failure)
    }

    @Published private(set) var summaries: [NootNoteSummary] = []
    @Published private(set) var activeID: NootNoteID?
    @Published private(set) var source = ""
    @Published private(set) var isDirty = false
    @Published private(set) var isLoaded = false
    @Published private(set) var searchResults: [NootNoteSearchResult] = []
    @Published private(set) var isSearching = false

    let repository: NootNotesRepository
    var onIssue: ((Issue) -> Void)?

    private var saveDebounce: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var searchGeneration = 0
    private var saveFailed = false

    init(repository: NootNotesRepository) { self.repository = repository }

    deinit {
        saveDebounce?.cancel()
        searchTask?.cancel()
    }

    func start() async -> Bool {
        await reload()
    }

    func reload() async -> Bool {
        guard await flush() else { return false }
        let repository = repository
        let result = await perform { try repository.list() }
        switch result {
        case .success(let summaries):
            self.summaries = summaries
            if let activeID, summaries.contains(where: { $0.id == activeID }) {
                return await select(activeID, flushFirst: false)
            }
            if let first = summaries.first { return await select(first.id, flushFirst: false) }
            apply(nil, summaries: summaries)
            return true
        case .failure(let error): publish(.load(error)); return false
        }
    }

    func updateSource(_ updated: String) {
        guard activeID != nil, updated != source else { return }
        source = updated
        isDirty = true
        saveFailed = false
        scheduleSave()
    }

    @discardableResult
    func flush() async -> Bool {
        saveDebounce?.cancel()
        saveDebounce = nil
        if let saveTask { await saveTask.value }
        guard isDirty, !saveFailed, let activeID else { return !isDirty }
        let savedSource = source
        let repository = repository
        let task = Task { await self.write(id: activeID, source: savedSource, repository: repository) }
        saveTask = task
        await task.value
        saveTask = nil
        return !isDirty
    }

    @discardableResult
    func create(title: String = "Untitled", source: String = "") async -> Bool {
        guard await flush() else { return false }
        let repository = repository
        switch await perform({ try repository.create(title: title, source: source) }) {
        case .success(let document):
            guard let summaries = try? repository.list() else { return false }
            apply(document, summaries: summaries)
            return true
        case .failure(let error): publish(.operation(error)); return false
        }
    }

    @discardableResult
    func select(_ id: NootNoteID, flushFirst: Bool = true) async -> Bool {
        if id == activeID { return true }
        if flushFirst, !(await flush()) { return false }
        let repository = repository
        switch await perform({ try repository.load(id) }) {
        case .success(let document):
            apply(document, summaries: (try? repository.list()) ?? summaries)
            return true
        case .failure(let error): publish(.load(error)); return false
        }
    }

    @discardableResult
    func rename(_ id: NootNoteID, to title: String) async -> Bool {
        guard await flush() else { return false }
        let repository = repository
        switch await perform({ try repository.rename(id: id, to: title) }) {
        case .success(let renamed):
            summaries = (try? repository.list()) ?? summaries
            if activeID == id { activeID = renamed }
            return true
        case .failure(let error): publish(.operation(error)); return false
        }
    }

    @discardableResult
    func trash(_ id: NootNoteID) async -> Bool {
        guard await flush() else { return false }
        let repository = repository
        switch await perform({ try repository.trash(id: id) }) {
        case .success:
            summaries = (try? repository.list()) ?? []
            if activeID == id {
                if let next = summaries.first { return await select(next.id, flushFirst: false) }
                apply(nil, summaries: summaries)
            }
            return true
        case .failure(let error): publish(.operation(error)); return false
        }
    }

    func updateSearchQuery(_ query: String) {
        searchTask?.cancel()
        searchGeneration += 1
        let generation = searchGeneration
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        let repository = repository
        let summaries = summaries
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            let results = await Task.detached(priority: .userInitiated) {
                repository.search(query, summaries: summaries)
            }.value
            guard let self, !Task.isCancelled, generation == self.searchGeneration else { return }
            self.searchResults = results
            self.isSearching = false
        }
    }

    func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        searchGeneration += 1
        searchResults = []
        isSearching = false
    }

    private func scheduleSave() {
        saveDebounce?.cancel()
        saveDebounce = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self else { return }
            _ = await self.flush()
        }
    }

    private func write(id: NootNoteID, source: String, repository: NootNotesRepository) async {
        switch await perform({ try repository.save(id: id, source: source) }) {
        case .success:
            summaries = (try? repository.list()) ?? summaries
            isDirty = self.source != source
        case .failure(let error):
            saveFailed = true
            publish(.save(error))
        }
    }

    private func apply(_ document: NootNoteDocument?, summaries: [NootNoteSummary]) {
        self.summaries = summaries
        activeID = document?.id
        source = document?.source ?? ""
        isDirty = false
        saveFailed = false
        isLoaded = true
    }

    private func publish(_ issue: Issue) { onIssue?(issue) }

    private func perform<Value: Sendable>(
        _ work: @escaping @Sendable () throws -> Value
    ) async -> Result<Value, NootNotesRepository.Failure> {
        await Task.detached(priority: .utility) {
            do { return .success(try work()) }
            catch let error as NootNotesRepository.Failure { return .failure(error) }
            catch { return .failure(.io(self.repository.directory, error.localizedDescription)) }
        }.value
    }
}
