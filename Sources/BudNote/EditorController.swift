import AppKit
import WebKit
import BudCore

final class MeadowView: NSView {
    var appearanceChanged: (() -> Void)?
    override func draw(_ dirtyRect: NSRect) {
        Palette.background.setFill(); dirtyRect.fill()
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); appearanceChanged?() }
}
final class PlainTextView: NSTextView {
    override func paste(_ sender: Any?) { pasteAsPlainText(sender) }
}
final class EditorController: NSViewController, NSTextViewDelegate, WKNavigationDelegate, NSMenuItemValidation, NSToolbarDelegate {
    weak var document: TextDocument?
    let textView = PlainTextView()
    let scrollView = FontZoomScrollView()
    private let webView: WKWebView
    private let splitView = NSSplitView()
    private let findBar = FindReplaceBar()
    private var findHeight: NSLayoutConstraint!
    private let status = NSTextField(labelWithString: "")
    private let tabsView = DocumentTabsView()
    private let modeControl = NSSegmentedControl(images: [
        NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "编辑")!,
        NSImage(systemSymbolName: "rectangle.lefthalf.inset.filled", accessibilityDescription: "实时预览")!,
        NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: "阅读")!
    ], trackingMode: .selectOne, target: nil, action: nil)
    private static let tabsID = NSToolbarItem.Identifier("BudNote.tabs")
    private static let modeID = NSToolbarItem.Identifier("BudNote.markdown")
    private var toolbar: NSToolbar?
    private var ruler: LineNumberRuler!
    private var changeWork: DispatchWorkItem?
    private var previewReady = false
    private var mode = 0
    private var languageOverride: String?
    private var applying = false
    private var appliedColorScheme: NSAppearance.Name?
    private var previewScrollWork: DispatchWorkItem?
    #if DEBUG
    private(set) var highlightPassCount = 0
    private(set) var previewUpdateCount = 0
    #endif
    private var observers: [NSObjectProtocol] = []
    private var language: String { languageOverride ?? document?.fileURL?.pathExtension.lowercased() ?? "txt" }
    private var markdown: Bool { ["md", "markdown"].contains(language) }
    init(document: TextDocument) {
        self.document = document
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: config)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit {
        changeWork?.cancel()
        previewScrollWork?.cancel()
        observers.forEach(NotificationCenter.default.removeObserver)
    }
    override func loadView() {
        let root = MeadowView(); view = root
        root.appearanceChanged = { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.appliedColorScheme != self.view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) else { return }
                self.applyColors(); self.highlight(); self.updatePreview()
            }
        }
        modeControl.target = self; modeControl.action = #selector(changeMode(_:)); modeControl.selectedSegment = 0
        modeControl.controlSize = .small
        modeControl.setAccessibilityLabel("Markdown 显示模式")
        for (index, label) in ["编辑", "实时预览", "阅读"].enumerated() {
            modeControl.setToolTip(label, forSegment: index); modeControl.setWidth(28, forSegment: index)
        }
        status.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular); status.textColor = .secondaryLabelColor
        status.translatesAutoresizingMaskIntoConstraints = false
        splitView.isVertical = true; splitView.dividerStyle = .thin; splitView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true; scrollView.hasHorizontalScroller = true; scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder; scrollView.drawsBackground = true
        scrollView.verticalScrollElasticity = .none; scrollView.horizontalScrollElasticity = .none
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsetsZero
        scrollView.contentView.automaticallyAdjustsContentInsets = false
        scrollView.contentView.contentInsets = NSEdgeInsetsZero
        scrollView.contentView.clipsToBounds = true
        textView.isRichText = false; textView.importsGraphics = false; textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false; textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false; textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.usesFindBar = false
        textView.textContainerInset = NSSize(width: 10, height: 12)
        textView.isVerticallyResizable = true; textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.delegate = self; textView.setAccessibilityLabel("文本编辑器")
        scrollView.documentView = textView
        ruler = LineNumberRuler(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = ruler; scrollView.hasVerticalRuler = true
        scrollView.contentView.postsBoundsChangedNotifications = true
        observers.append(NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.contentView, queue: .main) { [weak self] _ in
            self?.ruler.needsDisplay = true; self?.schedulePreviewScroll()
        })
        observers.append(NotificationCenter.default.addObserver(forName: .preferencesChanged, object: nil, queue: .main) { [weak self] _ in self?.applyPreferences() })
        webView.navigationDelegate = self; webView.setAccessibilityLabel("Markdown 阅读预览")
        splitView.addArrangedSubview(scrollView); splitView.addArrangedSubview(webView)
        observers.append(NotificationCenter.default.addObserver(forName: .documentTabsChanged, object: nil, queue: .main) { [weak self] _ in self?.refreshChrome() })
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let window = note.object as? NSWindow, self.view.window === window else { return }
            self.refreshChrome()
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didUpdateNotification, object: nil, queue: .main) { [weak self] _ in self?.refreshChrome() })
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] _ in self?.refreshChrome() })
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshChrome() }
        })
        findBar.translatesAutoresizingMaskIntoConstraints = false
        findBar.isHidden = true
        findBar.onSearch = { [weak self] forward in self?.findMatch(forward: forward) }
        findBar.onReplace = { [weak self] all in self?.replaceMatches(all: all) }
        findBar.onClose = { [weak self] in
            guard let self else { return }
            self.findBar.isHidden = true; self.findHeight.constant = 0
            self.view.window?.makeFirstResponder(self.textView)
        }
        findHeight = findBar.heightAnchor.constraint(equalToConstant: 0)
        view.addSubview(findBar); view.addSubview(splitView); view.addSubview(status)
        NSLayoutConstraint.activate([
            findBar.topAnchor.constraint(equalTo: view.topAnchor), findBar.leadingAnchor.constraint(equalTo: view.leadingAnchor), findBar.trailingAnchor.constraint(equalTo: view.trailingAnchor), findHeight,
            splitView.topAnchor.constraint(equalTo: findBar.bottomAnchor), splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor), splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor), splitView.bottomAnchor.constraint(equalTo: status.topAnchor, constant: -4),
            status.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10), status.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10), status.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4), status.heightAnchor.constraint(equalToConstant: 16)])
        reloadContent(); applyPreferences(); setMode(0)
    }
    override func viewDidAppear() { super.viewDidAppear(); configureWrap() }
    func installToolbar(on window: NSWindow) {
        let toolbar = NSToolbar(identifier: "BudNote.compactToolbar.\(UUID().uuidString)")
        toolbar.delegate = self; toolbar.displayMode = .iconOnly; toolbar.sizeMode = .small
        toolbar.allowsUserCustomization = false; toolbar.autosavesConfiguration = false
        self.toolbar = toolbar
        window.toolbarStyle = .unifiedCompact
        window.toolbar = toolbar
        refreshChrome(); applyPreferences()
    }
    func attachToolbar(to window: NSWindow) {
        // Keep the host toolbar itself in place to avoid titlebar relayout or
        // animation. Its custom controls follow the selected editor instead.
        toolbar = window.toolbar
        toolbar?.delegate = self
        if let item = toolbar?.items.first(where: { $0.itemIdentifier == Self.tabsID }) { item.view = tabsView }
        if let item = toolbar?.items.first(where: { $0.itemIdentifier == Self.modeID }) { item.view = modeControl }
        applyColors()
    }
    func restoreFocus() { view.window?.makeFirstResponder(mode == 2 ? webView : textView) }
    func refreshChrome() {
        guard let window = view.window else { return }
        tabsView.updateViewportWidth(window.frame.width, reservesMarkdownControls: markdown)
        tabsView.refresh(for: window)
        guard let toolbar else { return }
        let index = toolbar.items.firstIndex { $0.itemIdentifier == Self.modeID }
        if markdown && index == nil { toolbar.insertItem(withItemIdentifier: Self.modeID, at: 2) }
        if !markdown, let index { toolbar.removeItem(at: index) }
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.tabsID, .flexibleSpace, Self.modeID]
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.tabsID, .flexibleSpace] + (markdown ? [Self.modeID] : [])
    }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: identifier)
        switch identifier {
        case Self.tabsID:
            item.label = "文件标签"; item.view = tabsView

            item.visibilityPriority = .high
        case Self.modeID:
            item.label = "Markdown 显示模式"; item.view = modeControl
        default: return nil
        }
        return item
    }
    func reloadContent() {
        guard isViewLoaded else { return }
        applying = true; textView.string = document?.content ?? ""; applying = false
        textView.undoManager?.removeAllActions(); ruler.updateLines(); fileDidChange()
    }
    func fileDidChange() {
        guard isViewLoaded else { return }
        refreshChrome()
        if !markdown { setMode(0) }
        highlight(); updatePreview(); refreshStatus()
    }
    func applyPreferences() {
        let p = Preferences.shared
        Preferences.shared.applyAppearance()
        textView.font = .monospacedSystemFont(ofSize: p.fontSize, weight: .regular)
        textView.typingAttributes = [.font: textView.font!, .foregroundColor: NSColor.textColor]
        scrollView.rulersVisible = p.lineNumbers
        applyColors(); ruler.updateLines(); scrollView.tile(); configureWrap(); highlight(); updatePreview()
    }
    private func applyColors() {
        appliedColorScheme = view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        textView.backgroundColor = Palette.background; textView.textColor = .textColor; textView.insertionPointColor = Palette.accent
        scrollView.backgroundColor = Palette.background
        view.needsDisplay = true
        view.window?.backgroundColor = Palette.background
        view.window?.contentView?.needsDisplay = true
        tabsView.needsDisplay = true
        ruler?.needsDisplay = true
    }
    private func configureWrap() {
        guard let container = textView.textContainer else { return }
        let wrap = Preferences.shared.wrap
        // Overlay scrollers cover long lines and the last visible text row.
        // Reserve separate scrollbar tracks when scrolling in both directions.
        scrollView.scrollerStyle = wrap ? NSScroller.preferredScrollerStyle : .legacy
        scrollView.autohidesScrollers = wrap
        scrollView.hasHorizontalScroller = !wrap
        scrollView.tile()
        textView.isHorizontallyResizable = !wrap
        container.widthTracksTextView = wrap
        textView.layoutManager?.allowsNonContiguousLayout = !(markdown && mode == 1 && (textView.string as NSString).length <= 1_000_000)
        if wrap {
            textView.setFrameSize(NSSize(width: scrollView.contentSize.width, height: max(textView.frame.height, scrollView.contentSize.height)))
            container.containerSize = NSSize(width: max(1, scrollView.contentSize.width - 20), height: CGFloat.greatestFiniteMagnitude)
            textView.autoresizingMask = [.width]
        } else {
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.autoresizingMask = []
        }
        textView.needsDisplay = true
    }
    func textDidChange(_ notification: Notification) {
        guard !applying else { return }
        // The document observes editor undo groups to track edited/clean state.
        // Counting here as well would leave a document dirty after undoing all edits.
        document?.content = textView.string
        let previousGutterWidth = ruler.ruleThickness
        ruler.updateLines()
        if ruler.ruleThickness != previousGutterWidth { scrollView.tile(); configureWrap() }
        refreshStatus()
        changeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.highlight(); self?.updatePreview() }
        changeWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }
    func undoManager(for view: NSTextView) -> UndoManager? { document?.editingUndoManager }
    func textViewDidChangeSelection(_ notification: Notification) { refreshStatus() }
    func refreshStatus() {
        guard isViewLoaded else { return }
        let location = min(textView.selectedRange().location, (textView.string as NSString).length)
        let source = textView.string as NSString
        var low = 0, high = ruler.lineStarts.count
        while low < high { let mid = (low + high) / 2; if ruler.lineStarts[mid] <= location { low = mid + 1 } else { high = mid } }
        let line = max(0, low - 1), start = ruler.lineStarts[line]
        let column = source.substring(with: NSRange(location: start, length: location - start)).count + 1
        let endings = source.range(of: "\r\n").location != NSNotFound ? "CRLF" : source.range(of: "\r").location != NSNotFound ? "CR" : "LF"
        let limited = source.length > 1_000_000 ? "  ·  大文件：已暂停高亮与预览" : ""
        refreshChrome()
        status.stringValue = "第 \(line + 1) 行，\(column) 列    ·    \(textView.string.count) 字符    ·    \(document?.codec.name ?? "UTF-8")    ·    \(endings)\(limited)"
    }
    private func highlight() {
        #if DEBUG
        highlightPassCount += 1
        #endif
        guard let manager = textView.layoutManager else { return }
        let range = NSRange(location: 0, length: (textView.string as NSString).length)
        manager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: range)
        guard range.length <= 1_000_000 else { return }
        for token in Syntax.tokens(textView.string, language: language) {
            let color: NSColor
            switch token.kind {
            case .comment: color = .secondaryLabelColor
            case .string: color = Palette.accent
            case .keyword: color = .systemPurple
            case .number: color = .systemOrange
            case .tag: color = .systemBlue
            case .heading: color = Palette.accent
            }
            // Temporary layout attributes never become saved content or undo operations.
            manager.addTemporaryAttribute(.foregroundColor, value: color, forCharacterRange: token.range)
        }
    }
    private func updatePreview() {
        guard isViewLoaded, markdown, mode != 0 else { return }
        #if DEBUG
        previewUpdateCount += 1
        #endif
        let source = (textView.string as NSString).length <= 1_000_000 ? textView.string : "# 文件较大\n请切换到编辑模式查看全文。"
        if !previewReady {
            if !webView.isLoading { webView.loadHTMLString(Markdown.page(source, fontSize: Preferences.shared.fontSize + 1), baseURL: nil) }
            return
        }
        let dark = view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let payload = ["html": Markdown.render(source, sourcePositions: true), "size": "\(Preferences.shared.fontSize + 1)px", "theme": dark ? "dark" : "light"]
        guard let data = try? JSONSerialization.data(withJSONObject: payload), let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("(() => { const p = \(json); document.querySelector('main').innerHTML = p.html; document.body.style.fontSize = p.size; document.documentElement.dataset.theme = p.theme; \(Self.previewScrollScript) })()") { [weak self] _, _ in self?.schedulePreviewScroll() }
    }
    private static let previewScrollScript = """
    window.__budnoteScrollMap = null;
    window.__budnoteSyncScroll = (line, progress) => {
      const key = innerWidth + ':' + innerHeight;
      let cached = window.__budnoteScrollMap;
      if (!cached || cached.key !== key) {
        const points = [];
        for (const node of document.querySelectorAll('main [data-source-line]')) {
          const rect = node.getBoundingClientRect();
          const start = Number(node.dataset.sourceLine), end = Number(node.dataset.sourceEnd);
          points.push({line:start, y:rect.top + scrollY});
          if (end > start) points.push({line:end + 1, y:rect.bottom + scrollY});
        }
        points.sort((a,b) => a.line - b.line);
        cached = window.__budnoteScrollMap = {key, points};
      }
      const maxY = Math.max(0, document.documentElement.scrollHeight - innerHeight);
      let y = progress * maxY;
      const points = cached.points;
      if (points.length && progress > 0 && progress < 1) {
        let lo = 0, hi = points.length;
        while (lo < hi) { const mid = (lo + hi) >> 1; if (points[mid].line <= line) lo = mid + 1; else hi = mid; }
        const a = points[Math.max(0,lo - 1)], b = points[Math.min(points.length - 1,lo)];
        const fraction = b.line > a.line ? Math.max(0,Math.min(1,(line - a.line)/(b.line - a.line))) : 0;
        y = a.y + (b.y - a.y) * fraction;
      }
      window.scrollTo(0, Math.max(0,Math.min(maxY,y)));
    };
    """
    private func schedulePreviewScroll() {
        guard mode == 1, markdown, previewReady, previewScrollWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.previewScrollWork = nil
            self.synchronizePreviewScroll()
        }
        previewScrollWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 / 60.0, execute: work)
    }
    private func synchronizePreviewScroll() {
        guard mode == 1, markdown, previewReady, (textView.string as NSString).length <= 1_000_000,
              let manager = textView.layoutManager, let container = textView.textContainer else { return }
        let origin = scrollView.contentView.bounds.minY
        let maximum = max(0, textView.bounds.height - scrollView.contentView.bounds.height)
        let progress = maximum > 0 ? min(1, max(0, origin / maximum)) : 0
        let point = NSPoint(x: 0, y: max(0, origin - textView.textContainerOrigin.y))
        let glyph = manager.glyphIndex(for: point, in: container)
        let character = manager.numberOfGlyphs > 0 ? manager.characterIndexForGlyph(at: min(glyph, manager.numberOfGlyphs - 1)) : 0
        var low = 0, high = ruler.lineStarts.count
        while low < high { let mid = (low + high) / 2; if ruler.lineStarts[mid] <= character { low = mid + 1 } else { high = mid } }
        let index = max(0, low - 1), start = ruler.lineStarts[index]
        let length = (textView.string as NSString).length
        func y(_ offset: Int) -> CGFloat {
            if offset >= length { return manager.extraLineFragmentRect.minY + textView.textContainerOrigin.y }
            return manager.lineFragmentRect(forGlyphAt: manager.glyphIndexForCharacter(at: offset), effectiveRange: nil).minY + textView.textContainerOrigin.y
        }
        let top = y(start)
        let bottom = index + 1 < ruler.lineStarts.count ? y(ruler.lineStarts[index + 1]) : textView.bounds.height
        let fraction = bottom > top ? min(1, max(0, (origin - top) / (bottom - top))) : 0
        let line = Double(index + 1) + Double(fraction)
        webView.evaluateJavaScript("window.__budnoteSyncScroll?.(\(line), \(progress))", completionHandler: nil)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { previewReady = true; updatePreview() }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.navigationType == .linkActivated {
            if let url = action.request.url, ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") { NSWorkspace.shared.open(url) }
            decisionHandler(.cancel)
        } else { decisionHandler(action.navigationType == .other ? .allow : .cancel) }
    }
    private func setMode(_ value: Int) {
        mode = markdown ? value : 0; modeControl.selectedSegment = mode
        scrollView.isHidden = mode == 2; webView.isHidden = mode == 0
        view.layoutSubtreeIfNeeded()
        splitView.adjustSubviews()
        if mode == 1 {
            splitView.setPosition(splitView.bounds.width / 2, ofDividerAt: 0)
            // Toolbar/window layout can change content width in the same event.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.mode == 1 else { return }
                self.view.layoutSubtreeIfNeeded()
                self.splitView.setPosition(self.splitView.bounds.width / 2, ofDividerAt: 0)
                self.configureWrap()
            }
        }
        if mode == 2 { view.window?.makeFirstResponder(webView) }
        else { view.window?.makeFirstResponder(textView); configureWrap() }
        updatePreview()
    }
    #if DEBUG
    var markdownControlsVisible: Bool { toolbar?.items.contains { $0.itemIdentifier == Self.modeID } == true }
    var displayedTabCount: Int { tabsView.tabCount }
    var tabViewIdentities: [ObjectIdentifier] { tabsView.tabViewIdentities }
    var tabContentHeight: CGFloat { tabsView.contentSize.height }
    var tabViewportWidth: CGFloat { tabsView.frame.width }
    var tabContentWidth: CGFloat { tabsView.documentView?.frame.width ?? 0 }
    var tabScrollOffset: CGFloat { tabsView.contentView.bounds.minX }
    func scrollTabsToEnd() { tabsView.contentView.scroll(to: NSPoint(x: max(0, tabContentWidth - tabsView.contentSize.width), y: 0)) }
    var fileTabTitles: [String] { tabsView.tabTitles }
    var searchBar: FindReplaceBar { findBar }
    var paneWidths: (CGFloat, CGFloat) { (scrollView.frame.width, webView.frame.width) }
    var lineNumberVisibleWidth: CGFloat { ruler.bounds.width }
    var lineNumberWidth: CGFloat { ruler.ruleThickness }
    func inspectPreview(completion: @escaping (String?, Error?) -> Void) {
        webView.evaluateJavaScript("document.body.innerText") { value, error in completion(value as? String, error) }
    }
    func inspectPreviewPosition(line: Int, completion: @escaping ([String: Double]?, Error?) -> Void) {
        webView.evaluateJavaScript("({y:scrollY, top:document.querySelector('[data-source-line=\"\(line)\"]')?.getBoundingClientRect().top ?? -9999, max:document.documentElement.scrollHeight-innerHeight})") { value, error in completion(value as? [String: Double], error) }
    }
    #endif
    @objc func changeMode(_ sender: NSSegmentedControl) { setMode(sender.selectedSegment) }
    @objc func editMode(_ sender: Any?) { setMode(0) }
    @objc func splitMode(_ sender: Any?) { setMode(1) }
    @objc func readMode(_ sender: Any?) { setMode(2) }
    @objc func useMarkdown(_ sender: Any?) { languageOverride = markdown ? "txt" : "md"; fileDidChange() }
    @objc func showFind(_ sender: Any?) { showSearch(replace: false) }
    @objc func showReplace(_ sender: Any?) { showSearch(replace: true) }
    private func showSearch(replace: Bool) {
        if mode == 2 { setMode(1) }
        findBar.showReplacement(replace)
        findBar.isHidden = false; findHeight.constant = replace ? 88 : 46
        let selection = textView.selectedRange()
        if selection.length > 0 { findBar.query.stringValue = (textView.string as NSString).substring(with: selection) }
        view.layoutSubtreeIfNeeded()
        view.window?.makeFirstResponder(findBar.query)
    }
    @objc func findNext(_ sender: Any?) { findMatch(forward: true) }
    @objc func findPrevious(_ sender: Any?) { findMatch(forward: false) }
    private func matches() -> [NSRange] {
        TextSearch.ranges(in: textView.string, query: findBar.query.stringValue, caseSensitive: findBar.caseSensitive.state == .on)
    }
    private func findMatch(forward: Bool) {
        let ranges = matches(), selection = textView.selectedRange()
        guard !ranges.isEmpty else { findBar.result.stringValue = "无匹配"; return }
        let range = forward ? (ranges.first { $0.location >= NSMaxRange(selection) } ?? ranges[0])
                            : (ranges.last { $0.location < selection.location } ?? ranges[ranges.count - 1])
        textView.setSelectedRange(range); textView.scrollRangeToVisible(range)
        findBar.result.stringValue = "\(ranges.firstIndex(of: range)! + 1)/\(ranges.count)"
    }
    private func replaceMatches(all: Bool) {
        let ranges = matches()
        guard !ranges.isEmpty else { findBar.result.stringValue = "无匹配"; return }
        textView.breakUndoCoalescing()
        if all {
            let source = NSMutableString(string: textView.string)
            for range in ranges.reversed() { source.replaceCharacters(in: range, with: findBar.replacement.stringValue) }
            textView.insertText(source as String, replacementRange: NSRange(location: 0, length: (textView.string as NSString).length))
            findBar.result.stringValue = "已替换 \(ranges.count) 处"
        } else {
            if !ranges.contains(textView.selectedRange()) { findMatch(forward: true) }
            textView.insertText(findBar.replacement.stringValue, replacementRange: textView.selectedRange())
            findMatch(forward: true)
        }
        textView.breakUndoCoalescing(); textView.undoManager?.setActionName(all ? "全部替换" : "替换")
    }
    @objc func saveDocument(_ sender: Any?) { document?.save(sender) }
    @objc func showSettings(_ sender: Any?) { (NSApp.delegate as? AppDelegate)?.showSettings(sender) }
    @objc func toggleWrap(_ sender: Any?) { Preferences.shared.wrap.toggle() }
    @objc func toggleLineNumbers(_ sender: Any?) { Preferences.shared.lineNumbers.toggle() }
    @objc func increaseFont(_ sender: Any?) { Preferences.shared.fontSize += 1 }
    @objc func decreaseFont(_ sender: Any?) { Preferences.shared.fontSize -= 1 }
    @objc func resetFont(_ sender: Any?) { Preferences.shared.fontSize = 15 }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(toggleWrap(_:)): menuItem.state = Preferences.shared.wrap ? .on : .off
        case #selector(toggleLineNumbers(_:)): menuItem.state = Preferences.shared.lineNumbers ? .on : .off
        case #selector(useMarkdown(_:)): menuItem.state = markdown ? .on : .off
        case #selector(editMode(_:)): menuItem.state = mode == 0 ? .on : .off
        case #selector(splitMode(_:)): menuItem.state = mode == 1 ? .on : .off; return markdown
        case #selector(readMode(_:)): menuItem.state = mode == 2 ? .on : .off; return markdown
        default: break
        }
        return true
    }
}
