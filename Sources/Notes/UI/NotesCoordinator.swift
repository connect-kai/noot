import AppKit
import Observation
import SwiftUI

/// Tinycast's UI coordinator, backed by Noot's file store.
@MainActor
@Observable
final class NotesCoordinator {
    let store: NotesFeatureStore
    private(set) var formatting = NoteFormatting.plain
    private(set) var characterCountLabel = "0 characters"
    private(set) var isFormattingBarExpanded = UserDefaults.standard.object(forKey: "notesFormattingBarExpanded") as? Bool ?? true
    private(set) var isHeadingMenuPresented = false
    private(set) var isSwitcherPresented = false
    private(set) var switcherFocusRevision = 0
    var headingButtonFrame = CGRect.zero
    var switcherSelection: NoteID?
    var switcherEditingID: NoteID?
    var switcherTitleDraft = ""
    private var windowController: NotesWindowController?
    private var switcherController: NoteSwitcherWindowController?
    private var headingController: NoteHeadingMenuWindowController?

    init() {
        let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Noot")
        store = NotesFeatureStore(repository: NotesRepository(notesDirectory: directory))
        Task { [weak self] in
            guard let self else { return }
            _ = await store.start()
            if store.activeID == nil { _ = await store.create() }
        }
    }

    var activeTitle: String { store.activeTitle }
    var isVisible: Bool { windowController?.isVisible == true }
    var hasActiveNote: Bool { store.activeID != nil }
    var rendersMarkdown: Bool { true }
    var showsFormattingBar: Bool { rendersMarkdown }
    var editorInput: NoteEditorInput? {
        guard let id = store.activeID else { return nil }
        return NoteEditorInput(id: id, source: store.source, epoch: store.editorEpoch)
    }
    var visibleNotes: [NoteSummary] {
        store.searchQuery.isEmpty ? store.summaries : store.searchResults.map(\.summary)
    }
    var isSearching: Bool { store.isSearching }
    var searchQuery: String { store.searchQuery }
    var isRenamingSwitcherNote: Bool { switcherEditingID != nil }
    var switcherTitleDraftBinding: Binding<String> {
        Binding(get: { self.switcherTitleDraft }, set: { self.switcherTitleDraft = $0 })
    }
    var searchQueryBinding: Binding<String> {
        Binding(get: { self.store.searchQuery }, set: { self.store.updateSearchQuery($0) })
    }

    func attach(window: NotesWindowController) {
        windowController = window
    }

    func show() { windowController?.show(focusEditor: true) }
    func show(atMouse: Bool) {
        windowController?.show(focusEditor: true)
        if atMouse { windowController?.moveToMouse() }
    }
    func hide() {
        closeSwitcher(focusEditor: false)
        closeHeadingMenu()
        windowController?.hide(restoreFocus: true)
    }
    func toggle() {
        if windowController?.isVisible == true { hide() } else { show() }
    }

    func createNote() {
        Task { _ = await store.create(); switcherSelection = store.activeID }
    }
    func updateSource(_ source: String) { store.updateSource(source) }
    func updateTitle(_ title: String) {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        var lines = store.source.components(separatedBy: "\n")
        if let index = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            let old = lines[index]
            let prefix = old.prefix { $0 == "#" || $0 == " " || $0 == "\t" }
            lines[index] = String(prefix) + value
        } else {
            lines.insert(value, at: 0)
        }
        store.updateSource(lines.joined(separator: "\n"))
    }
    func updateCharacterCount(_ input: NoteEditorInput, _ count: Int) {
        characterCountLabel = "\(count) characters"
    }
    func updateFormatting(_ input: NoteEditorInput, _ value: NoteFormatting) { formatting = value }
    func editorReady(_ editor: NoteTextView) { windowController?.editorReady(editor) }
    func format(_ action: NoteEditAction) { windowController?.format(action) }

    func toggleFormattingBar() {
        isFormattingBarExpanded.toggle()
        UserDefaults.standard.set(isFormattingBarExpanded, forKey: "notesFormattingBarExpanded")
        if !isFormattingBarExpanded { closeHeadingMenu() }
    }
    func toggleHeadingMenu() {
        isHeadingMenuPresented.toggle()
        if isHeadingMenuPresented {
            if headingController == nil { headingController = NoteHeadingMenuWindowController(coordinator: self) }
            if let headingController { windowController?.presentHeadingMenu(headingController) }
        } else { closeHeadingMenu() }
    }
    func closeHeadingMenu() {
        isHeadingMenuPresented = false
        headingController?.hide()
    }
    func chooseHeading(_ level: Int) {
        format(.setHeading(level: level))
        closeHeadingMenu()
    }

    func searchNotes() {
        isSwitcherPresented = true
        if switcherController == nil { switcherController = NoteSwitcherWindowController(coordinator: self) }
        if let switcherController { windowController?.presentSwitcher(switcherController) }
        switcherFocusRevision &+= 1
    }
    func closeSwitcher(focusEditor: Bool = true) {
        isSwitcherPresented = false
        switcherController?.hide()
        if focusEditor { windowController?.focusEditor() }
    }
    func openNotesFolder() { NSWorkspace.shared.open(store.notesDirectory) }
    func moveToTopRight() { windowController?.moveToTopRight() }
    func handleEscape() {
        if isSwitcherPresented { closeSwitcher() } else if isHeadingMenuPresented { closeHeadingMenu() } else { hide() }
    }
    func noteWindowMouseDown() { closeSwitcher(focusEditor: false) }
    func handleDeleteShortcut() -> Bool { false }

    func reconcileSwitcherSelection() {
        guard !visibleNotes.isEmpty else { switcherSelection = nil; return }
        if let selection = switcherSelection, visibleNotes.contains(where: { $0.id == selection }) { return }
        switcherSelection = visibleNotes.first?.id
    }
    func moveSwitcherSelection(by offset: Int) {
        guard !visibleNotes.isEmpty else { return }
        let index = visibleNotes.firstIndex { $0.id == switcherSelection } ?? 0
        switcherSelection = visibleNotes[(index + offset + visibleNotes.count) % visibleNotes.count].id
    }
    func selectSwitcherNote() { if let id = switcherSelection { activateSwitcherNote(id) } }
    func activateSwitcherNote(_ id: NoteID) {
        Task { _ = await store.select(id); closeSwitcher() }
    }
    func beginSwitcherRename(_ summary: NoteSummary) {
        switcherEditingID = summary.id
        switcherTitleDraft = summary.displayTitle
    }
    func commitSwitcherRename() {
        guard let id = switcherEditingID else { return }
        let title = switcherTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        switcherEditingID = nil
        guard !title.isEmpty else { return }
        Task { _ = await store.rename(id, to: title) }
    }
    func cancelSwitcherRename() { switcherEditingID = nil }
    func trash(_ id: NoteID) { Task { _ = await store.trash(id) } }
}
