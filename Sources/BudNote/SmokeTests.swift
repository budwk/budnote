#if DEBUG
import AppKit
import BudCore

func runSmokeTests() throws {
    func require(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !value() { throw NSError(domain: "BudNoteSmoke", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    let suite = ProcessInfo.processInfo.environment["BUDNOTE_TEST_DEFAULTS_SUITE"]
    defer { if let suite { UserDefaults.standard.removePersistentDomain(forName: suite) } }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("budnote-smoke-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("note.md")
    let original = "# 清晨\r\n\r\nHello 世界\r\n"
    let controller = NSDocumentController.shared
    for ext in ["txt", "md", "html", "py", "java", "json", "yaml", "log"] {
        let fixture = directory.appendingPathComponent("sample.\(ext)")
        try Data(original.utf8).write(to: fixture)
        let detectedType = try controller.typeForContents(of: fixture)
        let opened = try controller.makeDocument(withContentsOf: fixture, ofType: detectedType)
        try require(opened is TextDocument, "Wrong document class for .\(ext)")
        try require(try opened.data(ofType: detectedType) == Data(original.utf8), "File opening changed .\(ext)")
    }
    guard let document = try controller.makeUntitledDocument(ofType: "public.plain-text") as? TextDocument else {
        throw NSError(domain: "BudNoteSmoke", code: 3, userInfo: [NSLocalizedDescriptionKey: "New document type registration failed"])
    }
    try document.read(from: Data(original.utf8), ofType: "public.plain-text")
    document.fileURL = file
    controller.addDocument(document)
    document.makeWindowControllers()
    guard let editor = document.editor else { throw NSError(domain: "BudNoteSmoke", code: 2) }
    try require(editor.textView.layoutManager != nil && editor.textView.textContainer != nil && editor.textView.textStorage != nil, "TextKit 1 layoutManager/textStorage missing")
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    try require(editor.textView.textStorage != nil && editor.textView.string == original, "Opening changed line endings or lost textStorage after autoreleasepool drain")
    try require(try document.data(ofType: "public.plain-text") == Data(original.utf8), "Document roundtrip changed bytes")
    guard let window = document.windowControllers.first?.window else { throw NSError(domain: "BudNoteSmoke", code: 4) }
    window.contentView?.layoutSubtreeIfNeeded()
    try require(editor.textView.frame.width > 500 && (editor.textView.textContainer?.containerSize.width ?? 0) > 500, "Editor text container width was collapsed: frame=\(editor.textView.frame), container=\(String(describing: editor.textView.textContainer?.containerSize))")
    try require(window.toolbarStyle == .unifiedCompact && window.titleVisibility == .hidden, "Titlebar is not a single compact toolbar row")
    for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
        try require(window.standardWindowButton(type)?.isHidden == false, "Missing native window button")
    }
    try require(editor.markdownControlsVisible, "Markdown controls missing")
    try require(editor.lineNumberWidth <= 35, "Line number gutter is too wide")
    document.fileURL = directory.appendingPathComponent("note.py")
    try require(!editor.markdownControlsVisible, "Non-Markdown files show Markdown controls")
    document.fileURL = file
    try require(editor.markdownControlsVisible, "Markdown controls did not return")
    for (theme, expected) in [(2, NSAppearance.Name.darkAqua), (1, .aqua), (0, nil)] as [(Int, NSAppearance.Name?)] {
        Preferences.shared.theme = theme
        if let expected {
            try require(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == expected, "Window chrome did not change theme")
            try require(editor.view.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == expected, "Editor did not change theme")
        } else { try require(window.appearance == nil && NSApp.appearance == nil, "System appearance was not restored") }
    }
    let second = TextDocument(); second.fileURL = directory.appendingPathComponent("second.txt")
    second.makeWindowControllers()
    if let other = second.windowControllers.first?.window {
        editor.refreshChrome(); second.editor?.refreshChrome()
        try require(editor.displayedTabCount == 2, "Grouped file tabs are missing")
        try require(window.tabbingMode == .disallowed && other.tabbingMode == .disallowed, "Native tab bar adds an extra header row")
        DocumentWorkspace.shared.activate(window, sender: nil)
        let hostFrame = window.frame
        DocumentWorkspace.shared.activate(other, sender: nil)
        try require(second.windowControllers.first?.window === window, "Switch did not reuse the visible window")
        try require(window.windowController?.document === second && second.editor?.view.window === window, "Host is bound to the wrong document")
        try require(window.frame == hostFrame && window.animationBehavior == .none && window.isVisible, "Switch changed frame, visibility or animation behavior: \(hostFrame) -> \(window.frame), visible=\(window.isVisible), animation=\(window.animationBehavior.rawValue)")
        try require(document.windowControllers.first?.window === other && editor.view.window === other, "Inactive document lost its parked controller")
        let hostToolbar = window.toolbar
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        let highlightPasses = editor.highlightPassCount + second.editor!.highlightPassCount
        let firstTabViews = editor.tabViewIdentities, secondTabViews = second.editor!.tabViewIdentities
        for index in 0..<8 {
            let target = index % 2 == 0 ? document : second
            DocumentWorkspace.shared.activate(target.windowControllers.first!.window!, sender: nil)
            RunLoop.current.run(until: Date().addingTimeInterval(0.015))
            try require(window.frame == hostFrame && window.toolbar === hostToolbar && window.windowController?.document === target, "Repeated switching recreated toolbar, drifted frame or bound wrong document")
        }
        try require(editor.highlightPassCount + second.editor!.highlightPassCount == highlightPasses, "Switching tabs rescanned syntax without a content or theme change")
        try require(editor.tabViewIdentities == firstTabViews && second.editor!.tabViewIdentities == secondTabViews, "Switching tabs rebuilt unchanged tab controls")
        // Closing the selected tab transfers the host before closing its document.
        second.close(); editor.refreshChrome()
        try require(document.windowControllers.first?.window === window && window.isVisible, "Closing selected tab lost the visible host")
        try require(editor.displayedTabCount == 1, "Closing a tab left a stale file tab")
    }
    window.setContentSize(NSSize(width: 1280, height: 740))
    editor.refreshChrome(); window.contentView?.layoutSubtreeIfNeeded()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    try require(abs(editor.tabViewportWidth - window.frame.width * 0.8) < 3, "Tabs did not occupy 80 percent of wide window")
    let more = (0..<10).map { index -> TextDocument in
        let doc = TextDocument(); doc.fileURL = directory.appendingPathComponent("长文件名称-\(index).txt")
        doc.makeWindowControllers(); return doc
    }
    editor.refreshChrome(); window.contentView?.layoutSubtreeIfNeeded()
    try require(editor.tabContentHeight >= 28, "Tab text is clipped by scroll chrome or content insets")
    try require(editor.tabContentWidth > editor.tabViewportWidth, "Overflowing tabs were compressed instead of scrolling")
    editor.scrollTabsToEnd()
    try require(editor.tabScrollOffset > 0, "Overflowing tabs cannot scroll horizontally")
    DocumentWorkspace.shared.activate(more.last!.windowControllers.first!.window!, sender: nil)
    try require(more.last!.windowControllers.first?.window === window, "Many-tab switch replaced the host")
    DocumentWorkspace.shared.requestClose(more.last!.windowControllers.first! as! DocumentWindowController)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    try require(more.last!.windowControllers.isEmpty && window.isVisible, "Close action failed to close the selected document while retaining host")
    DocumentWorkspace.shared.activate(document.windowControllers.first!.window!, sender: nil)
    more.forEach { $0.close() }
    try require(editor.displayedTabCount == 1, "Closed overflow tabs remain in toolbar")
    try require(AppDelegate.aboutCredits.string.contains("https://github.com/budwk/budnote") && !AppDelegate.aboutCredits.string.contains("wizzer@qq.com"), "About project link missing")
    // Real NSTextView edit and real NSDocument write, without touching user documents.
    let view = editor.textView
    view.setSelectedRange(NSRange(location: (view.string as NSString).length, length: 0))
    view.insertText("EDIT", replacementRange: view.selectedRange())
    view.breakUndoCoalescing()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try require(document.content.hasSuffix("EDIT"), "Edit did not update document")
    try require(document.isDocumentEdited, "Edit did not mark the document dirty")
    try require(editor.fileTabTitles.contains { $0.hasSuffix(" - 已编辑") }, "Edited suffix missing")
    view.undoManager?.undo()
    try require(!editor.fileTabTitles.contains { $0.hasSuffix(" - 已编辑") }, "Edited suffix survived undo")
    try require(document.content == original, "Undo failed")
    try require(!document.isDocumentEdited, "Undoing all edits left the document dirty")
    view.undoManager?.redo()
    try require(document.content.hasSuffix("EDIT"), "Redo failed")
    try require(document.isDocumentEdited, "Redo did not mark the document dirty")
    try document.write(to: file, ofType: "public.plain-text")
    try require(try Data(contentsOf: file) == Data(document.content.utf8), "Save did not preserve bytes")
    editor.splitMode(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    try require(editor.paneWidths.0 > 200 && editor.paneWidths.1 > 200 && abs(editor.paneWidths.0 - editor.paneWidths.1) < 3, "First preview click did not create equal split panes")
    var completed = false, previewText = "", previewError: Error?
    let timeout = Date().addingTimeInterval(15)
    while Date() < timeout && !completed {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        editor.inspectPreview { value, error in
            if let value, value.contains("Hello 世界") { previewText = value; completed = true }
            previewError = error
        }
    }
    try require(completed && previewText.contains("清晨"), "Markdown preview did not load: \(String(describing: previewError))")
    view.setSelectedRange(NSRange(location: 0, length: 0))
    view.insertText("# LIVE\n\n", replacementRange: view.selectedRange())
    completed = false
    let liveTimeout = Date().addingTimeInterval(5)
    while Date() < liveTimeout && !completed {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        editor.inspectPreview { value, _ in if value?.contains("LIVE") == true { completed = true } }
    }
    try require(completed, "Live preview did not update after editing")
    // Switch a highlighted code file against an already-rendered Markdown pane.
    // Neither syntax nor preview work should run just because its tab is selected.
    let codeDocument = TextDocument()
    codeDocument.fileURL = directory.appendingPathComponent("switch-performance.py")
    let code = Array(repeating: "def greet(value): return 'hello' if value > 12 else None", count: 2500).joined(separator: "\n")
    try codeDocument.read(from: Data(code.utf8), ofType: "public.plain-text")
    codeDocument.makeWindowControllers()
    let codeEditor = codeDocument.editor!
    DocumentWorkspace.shared.activate(codeDocument.windowControllers.first!.window!, sender: nil)
    DocumentWorkspace.shared.activate(document.windowControllers.first!.window!, sender: nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    let cachedHighlights = editor.highlightPassCount + codeEditor.highlightPassCount
    let cachedPreview = editor.previewUpdateCount
    let preservedSelection = editor.textView.selectedRange(), preservedDirty = document.isDocumentEdited
    var switchTimes: [Double] = []
    for index in 0..<12 {
        let target = index % 2 == 0 ? codeDocument : document
        let start = ProcessInfo.processInfo.systemUptime
        DocumentWorkspace.shared.activate(target.windowControllers.first!.window!, sender: nil)
        switchTimes.append((ProcessInfo.processInfo.systemUptime - start) * 1000)
        RunLoop.current.run(until: Date().addingTimeInterval(0.015))
    }
    try require(editor.highlightPassCount + codeEditor.highlightPassCount == cachedHighlights && editor.previewUpdateCount == cachedPreview, "Tab switching repeated syntax or Markdown rendering")
    try require(editor.textView.selectedRange() == preservedSelection && document.isDocumentEdited == preservedDirty && codeEditor.textView.string == code, "Tab switching changed selection, edited state or code")
    print(String(format: "Tab switch benchmark: %d-character Python + live Markdown, average %.1f ms, maximum %.1f ms (12 switches)", (code as NSString).length, switchTimes.reduce(0, +) / Double(switchTimes.count), switchTimes.max()!))
    codeDocument.close()
    editor.readMode(nil)
    try require(document.windowControllers.first?.window?.firstResponder !== view, "Reading mode retained hidden editor focus")
    editor.editMode(nil)
    try require(document.windowControllers.first?.window?.firstResponder === view, "Edit mode did not restore editor focus")
    editor.showReplace(nil)
    try require(editor.searchBar.query.font?.pointSize == 14 && editor.searchBar.frame.height == 88, "Find bar is too small")
    editor.searchBar.query.stringValue = "hello"
    view.setSelectedRange(NSRange(location: 0, length: 0)); editor.findNext(nil)
    try require((view.string as NSString).substring(with: view.selectedRange()) == "Hello", "Find failed")
    editor.searchBar.replacement.stringValue = "你好"
    let beforeReplace = document.content
    editor.searchBar.onReplace?(true)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    try require(document.content.contains("你好 世界"), "Replace failed")
    view.undoManager?.undo()
    try require(document.content == beforeReplace, "Undo replacement failed")
    editor.searchBar.onClose?()
    // Real AppKit wheel events zoom without editing text or moving the caret.
    func wheel(_ value: Int32, command: Bool, precise: Bool = false) throws -> NSEvent {
        guard let cg = CGEvent(scrollWheelEvent2Source: nil, units: precise ? .pixel : .line, wheelCount: 1, wheel1: value, wheel2: 0, wheel3: 0) else { throw NSError(domain: "BudNoteSmoke", code: 5) }
        cg.flags = command ? .maskCommand : []
        cg.setIntegerValueField(.scrollWheelEventIsContinuous, value: precise ? 1 : 0)
        guard let event = NSEvent(cgEvent: cg) else { throw NSError(domain: "BudNoteSmoke", code: 6) }
        return event
    }
    let originalFont = Preferences.shared.fontSize
    let beforeZoom = document.content, zoomSelection = view.selectedRange(), zoomDirty = document.isDocumentEdited
    Preferences.shared.fontSize = 15
    editor.scrollView.scrollWheel(with: try wheel(1, command: true))
    try require(Preferences.shared.fontSize == 16 && view.font?.pointSize == 16, "Command-wheel did not enlarge font")
    editor.scrollView.scrollWheel(with: try wheel(-1, command: true))
    try require(Preferences.shared.fontSize == 15 && view.font?.pointSize == 15, "Command-wheel did not shrink font")
    editor.scrollView.scrollWheel(with: try wheel(1, command: false))
    try require(Preferences.shared.fontSize == 15, "Ordinary scrolling changed font")
    editor.scrollView.scrollWheel(with: try wheel(6, command: true, precise: true))
    try require(Preferences.shared.fontSize == 15, "Precise wheel zoom is too sensitive")
    editor.scrollView.scrollWheel(with: try wheel(6, command: true, precise: true))
    try require(Preferences.shared.fontSize == 16, "Precise wheel zoom did not accumulate")
    Preferences.shared.fontSize = 40
    editor.scrollView.scrollWheel(with: try wheel(1, command: true))
    try require(Preferences.shared.fontSize == 40, "Wheel zoom exceeded maximum font size")
    Preferences.shared.fontSize = 10
    editor.scrollView.scrollWheel(with: try wheel(-1, command: true))
    try require(Preferences.shared.fontSize == 10, "Wheel zoom exceeded minimum font size")
    try require(document.content == beforeZoom && view.selectedRange() == zoomSelection && document.isDocumentEdited == zoomDirty, "Zoom changed text, caret or edited state")
    Preferences.shared.fontSize = originalFont
    // Large fonts and digit-count boundaries must fit inside the actual ruler.
    let rulerDocument = TextDocument()
    rulerDocument.makeWindowControllers()
    guard let rulerEditor = rulerDocument.editor else { throw NSError(domain: "BudNoteSmoke", code: 7) }
    for lineCount in [9, 10, 99, 100, 999, 1000] {
        let text = Array(repeating: "行号验证", count: lineCount).joined(separator: "\n")
        try rulerDocument.read(from: Data(text.utf8), ofType: "public.plain-text")
        for size in [15.0, 24.0, 40.0] {
            Preferences.shared.fontSize = size
            rulerEditor.view.layoutSubtreeIfNeeded()
            let labelFont = NSFont.monospacedDigitSystemFont(ofSize: max(10, size - 3), weight: .regular)
            let requiredWidth = (String(lineCount) as NSString).size(withAttributes: [.font: labelFont]).width + 14
            try require(rulerEditor.lineNumberWidth >= requiredWidth && rulerEditor.lineNumberVisibleWidth >= requiredWidth, "Line numbers clipped at \(lineCount) lines / \(size) pt")
        }
    }
    let largeGutter = rulerEditor.lineNumberWidth
    Preferences.shared.fontSize = 15
    try require(rulerEditor.lineNumberWidth < largeGutter, "Ruler did not shrink after font reset")
    // Long unwrapped text must be clipped before either scrollbar track.
    let originalWrap = Preferences.shared.wrap
    let longLines = Array(repeating: String(repeating: "abcdefgh ", count: 120), count: 80).joined(separator: "\n")
    try rulerDocument.read(from: Data(longLines.utf8), ofType: "public.plain-text")
    Preferences.shared.wrap = false
    rulerEditor.view.layoutSubtreeIfNeeded()
    rulerEditor.textView.layoutManager?.ensureLayout(for: rulerEditor.textView.textContainer!)
    rulerEditor.textView.sizeToFit()
    rulerEditor.scrollView.reflectScrolledClipView(rulerEditor.scrollView.contentView)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    rulerEditor.scrollView.tile()
    let unwrappedScroll = rulerEditor.scrollView
    for scroller in [unwrappedScroll.verticalScroller, unwrappedScroll.horizontalScroller] {
        guard let scroller else { throw NSError(domain: "BudNoteSmoke", code: 8) }
        let track = unwrappedScroll.convert(scroller.bounds, from: scroller)
        try require(!scroller.isHidden && !track.intersects(unwrappedScroll.contentView.frame), "Unwrapped text viewport overlaps a scrollbar: \(track), \(unwrappedScroll.contentView.frame), style \(unwrappedScroll.scrollerStyle.rawValue), insets \(unwrappedScroll.contentView.contentInsets), size \(unwrappedScroll.contentSize), visible \(unwrappedScroll.documentVisibleRect)")
    }
    try require(rulerEditor.textView.frame.width > unwrappedScroll.contentSize.width, "Long unwrapped lines cannot scroll horizontally")
    try require(rulerEditor.textView.string == longLines, "Changing scrollbar layout modified text")
    Preferences.shared.wrap = originalWrap
    rulerDocument.close()
    Preferences.shared.fontSize = originalFont
    // Mixed Markdown heights must map to source lines rather than percentages.
    let scrollingDocument = TextDocument()
    scrollingDocument.fileURL = directory.appendingPathComponent("scrolling.md")
    let scrollingText = (1...80).map { "# Section \($0)\n\nA paragraph with **bold** text.\nSecond paragraph line.\n\n- first item\n- second item\n\n```py\nprint(\($0))\n```\n" }.joined(separator: "\n")
    try scrollingDocument.read(from: Data(scrollingText.utf8), ofType: "public.plain-text")
    scrollingDocument.makeWindowControllers()
    let scrollingEditor = scrollingDocument.editor!
    let restoreWrap = Preferences.shared.wrap
    Preferences.shared.wrap = true
    DocumentWorkspace.shared.activate(scrollingDocument.windowControllers.first!.window!, sender: nil)
    scrollingEditor.splitMode(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    let targetOffset = (scrollingText as NSString).range(of: "# Section 40\n").location
    let sourceLine = (scrollingText as NSString).substring(to: targetOffset).filter { $0 == "\n" }.count + 1
    let scrollingView = scrollingEditor.textView, scrollingClip = scrollingEditor.scrollView.contentView
    scrollingView.layoutManager!.ensureLayout(for: scrollingView.textContainer!)
    let targetGlyph = scrollingView.layoutManager!.glyphIndexForCharacter(at: targetOffset)
    let targetY = scrollingView.layoutManager!.lineFragmentRect(forGlyphAt: targetGlyph, effectiveRange: nil).minY + scrollingView.textContainerOrigin.y
    scrollingClip.scroll(to: NSPoint(x: 0, y: targetY))
    scrollingEditor.scrollView.reflectScrolledClipView(scrollingClip)
    func waitForPreviewPosition(_ predicate: @escaping ([String: Double]) -> Bool) -> Bool {
        var matched = false
        let deadline = Date().addingTimeInterval(5)
        while !matched && Date() < deadline {
            scrollingEditor.inspectPreviewPosition(line: sourceLine) { value, _ in if let value, predicate(value) { matched = true } }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return matched
    }
    try require(waitForPreviewPosition { $0["y", default: 0] > 0 && abs($0["top", default: -9999]) < 5 }, "Markdown preview did not align with the visible source heading")
    let fixedWidth = scrollingView.frame.width
    let unchangedHighlights = scrollingEditor.highlightPassCount, unchangedPreview = scrollingEditor.previewUpdateCount
    var lastScroll = scrollingClip.bounds.minY
    for _ in 0..<8 {
        scrollingEditor.scrollView.scrollWheel(with: try wheel(-3, command: false))
        RunLoop.current.run(until: Date().addingTimeInterval(0.03))
        let position = scrollingClip.bounds.minY
        try require(position > lastScroll, "Markdown wheel scrolling stalled or rebounded")
        for _ in 0..<3 { scrollingEditor.scrollView.tile() }
        try require(abs(scrollingClip.bounds.minY - position) < 0.5 && scrollingView.frame.width == fixedWidth, "Tiling changed the Markdown scroll offset or wrapping width")
        lastScroll = position
    }
    try require(scrollingEditor.highlightPassCount == unchangedHighlights && scrollingEditor.previewUpdateCount == unchangedPreview, "Scrolling rescanned syntax or rerendered Markdown")
    scrollingClip.scroll(to: NSPoint(x: 0, y: max(0, scrollingView.bounds.height - scrollingClip.bounds.height)))
    try require(waitForPreviewPosition { abs($0["y", default: -9999] - $0["max", default: 0]) < 2 }, "Preview did not reach the bottom with the editor")
    scrollingClip.scroll(to: .zero)
    try require(waitForPreviewPosition { abs($0["y", default: -9999]) < 1 }, "Preview did not return to the top with the editor")
    try require(scrollingView.string == scrollingText && !scrollingDocument.isDocumentEdited, "Scroll synchronization edited the document")
    scrollingDocument.close(); Preferences.shared.wrap = restoreWrap
    // Save As with another extension and encoding keeps the original file intact.
    let copy = directory.appendingPathComponent("另存.java")
    let chosenCodec = TextCodec(encoding: .utf16LittleEndian, bom: Data([0xff, 0xfe]))
    var operationDone = false, operationError: Error?
    document.saveCopy(to: copy, codec: chosenCodec) { error in operationError = error; operationDone = true }
    let saveDeadline = Date().addingTimeInterval(10)
    while !operationDone && Date() < saveDeadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
    try require(operationDone && operationError == nil, "Save As failed: \(String(describing: operationError))")
    try require(document.fileURL == copy && !document.isDocumentEdited, "Save As did not update document state")
    try require(try Data(contentsOf: copy) == chosenCodec.encode(document.content), "Save As ignored selected encoding")
    try require(FileManager.default.fileExists(atPath: file.path), "Save As removed original file")
    operationDone = false
    document.saveCopy(to: directory.appendingPathComponent("missing/cannot-save.txt"), codec: TextCodec()) { error in operationError = error; operationDone = true }
    let failureDeadline = Date().addingTimeInterval(10)
    while !operationDone && Date() < failureDeadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
    try require(operationDone && operationError != nil && document.fileURL == copy && document.codec.encoding == chosenCodec.encoding, "Failed Save As changed document URL or codec")
    let folder = directory.appendingPathComponent("moved")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    view.insertText("移动前编辑", replacementRange: NSRange(location: 0, length: 0)); view.breakUndoCoalescing()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    let moved = folder.appendingPathComponent(copy.lastPathComponent)
    operationDone = false; operationError = nil
    document.moveFile(to: moved) { error in operationError = error; operationDone = true }
    let moveDeadline = Date().addingTimeInterval(10)
    while !operationDone && Date() < moveDeadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
    try require(operationDone && operationError == nil, "Move failed: \(String(describing: operationError))")
    try require(document.fileURL == moved && !FileManager.default.fileExists(atPath: copy.path), "Move did not update file location")
    try require(try Data(contentsOf: moved) == chosenCodec.encode(document.content), "Move lost pending edits")
    // Rename file in place and verify File menu placement + language switching.
    let menuDelegate = AppDelegate()
    menuDelegate.buildMenu()
    if let fileSubmenu = NSApp.mainMenu?.items.dropFirst().first?.submenu {
        let saveAsIdx = fileSubmenu.items.firstIndex { $0.action == #selector(TextDocument.saveAsWithOptions(_:)) }
        let renameIdx = fileSubmenu.items.firstIndex { $0.action == #selector(TextDocument.renameDocumentItem(_:)) }
        try require(saveAsIdx != nil && renameIdx == saveAsIdx! + 1, "Rename item is not immediately below Save As in File menu")
    } else {
        throw NSError(domain: "BudNoteSmoke", code: 9, userInfo: [NSLocalizedDescriptionKey: "Missing File menu"])
    }
    view.insertText("重命名前编辑", replacementRange: NSRange(location: 0, length: 0)); view.breakUndoCoalescing()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    let renamedURL = folder.appendingPathComponent("重命名文件.md")
    operationDone = false; operationError = nil
    document.renameFile(to: "重命名文件.md") { error in operationError = error; operationDone = true }
    let renameDeadline = Date().addingTimeInterval(10)
    while !operationDone && Date() < renameDeadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
    try require(operationDone && operationError == nil, "Rename failed: \(String(describing: operationError))")
    try require(document.fileURL == renamedURL && !FileManager.default.fileExists(atPath: moved.path), "Rename did not update file location")
    try require(try Data(contentsOf: renamedURL) == chosenCodec.encode(document.content), "Rename lost pending edits")
    try require(editor.markdownControlsVisible, "Renaming to .md did not enable Markdown controls")
    operationDone = false; operationError = nil
    document.renameFile(to: "bad/name.md") { error in operationError = error; operationDone = true }
    try require(operationDone && operationError != nil && document.fileURL == renamedURL, "Invalid rename name was not rejected")
    // Verify language switch (Simplified Chinese <-> English)
    let settingsController = SettingsController()
    Preferences.shared.language = 1
    menuDelegate.buildMenu()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    try require(NSApp.mainMenu?.items.dropFirst().first?.title == "File", "Main menu did not switch to English")
    try require(settingsController.window?.title == "BudNote Settings", "Settings window did not switch to English")
    try require(editor.searchBar.query.placeholderString == "Find", "Find bar did not switch to English")
    Preferences.shared.language = 0
    menuDelegate.buildMenu()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    try require(NSApp.mainMenu?.items.dropFirst().first?.title == "文件", "Main menu did not switch back to Simplified Chinese")
    try require(settingsController.window?.title == "BudNote 设置", "Settings window did not switch back to Simplified Chinese")
    document.close()
    print("PASS: file type registration, document open/save, CRLF preservation, NSTextView editing, undo/redo, WebKit Markdown live preview, reading/editing focus, compact toolbar, native window controls, theme switching, conditional Markdown controls, file tabs, About project link, first-click split geometry, larger find/replace, replacement undo, Save As encoding and error recovery, move and rename with pending edits, zh-Hans/en language switching, persistent host document ownership, closing active tabs, 80-percent tab width, overflow scrolling and Command-wheel font zoom, large-font line-number clipping, unwrapped scrollbar separation, stable Markdown wheel scrolling and source-mapped preview synchronization")
}
#endif
