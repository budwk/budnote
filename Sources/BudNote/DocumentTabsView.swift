import AppKit

/// File tabs share the native titlebar with the toolbar actions.
final class DocumentTabsView: NSScrollView {
    private let stack = NSStackView()
    private var signature = ""
    private var selection: ObjectIdentifier?
    private var viewportWidth: CGFloat = 420
    private var widthConstraint: NSLayoutConstraint!
    override var intrinsicContentSize: NSSize { NSSize(width: viewportWidth, height: 28) }
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 420, height: 28))
        drawsBackground = false; hasHorizontalScroller = false; hasVerticalScroller = false
        automaticallyAdjustsContentInsets = false; contentInsets = .init()
        toolTip = "标签较多时，可用触控板左右滑动或在此处滚动鼠标滚轮。"
        horizontalScrollElasticity = .allowed; verticalScrollElasticity = .none
        stack.orientation = .horizontal; stack.spacing = 4; stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = true
        documentView = stack
        widthConstraint = widthAnchor.constraint(equalToConstant: viewportWidth)
        NSLayoutConstraint.activate([heightAnchor.constraint(equalToConstant: 28), widthConstraint])
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        updateLocalization()
    }
    required init?(coder: NSCoder) { fatalError() }
    func updateLocalization() {
        toolTip = tr(
            "标签较多时，可用触控板左右滑动或在此处滚动鼠标滚轮。",
            "Scroll horizontally with trackpad or mouse wheel when many tabs are open."
        )
        setAccessibilityLabel(tr("文件标签", "File Tabs"))
    }
    #if DEBUG
    var tabTitles: [String] { stack.arrangedSubviews.compactMap { ($0.subviews.first as? NSButton)?.title } }
    var tabCount: Int { stack.arrangedSubviews.count }
    var tabViewIdentities: [ObjectIdentifier] { stack.arrangedSubviews.map(ObjectIdentifier.init) }
    #endif
    func updateViewportWidth(_ windowWidth: CGFloat, reservesMarkdownControls: Bool) {
        let width = max(150, min(windowWidth * 0.8, windowWidth - (reservesMarkdownControls ? 210 : 110)))
        guard abs(viewportWidth - width) > 0.5 else { return }
        viewportWidth = width; widthConstraint.constant = width; invalidateIntrinsicContentSize()
    }
    override func scrollWheel(with event: NSEvent) {
        // Horizontal trackpad gestures and conventional mouse wheels both
        // move the strip, without a scrollbar taking height from the labels.
        let maximum = max(0, stack.frame.width - contentSize.width)
        let movement = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) ? event.scrollingDeltaX : event.scrollingDeltaY
        let delta = movement * (event.hasPreciseScrollingDeltas ? 1 : 12)
        contentView.scroll(to: NSPoint(x: min(maximum, max(0, contentView.bounds.minX - delta)), y: 0))
        reflectScrolledClipView(contentView)
    }
    func refresh(for window: NSWindow) {
        let windows = DocumentWorkspace.shared.windows
        let current = windows.contains(window) ? windows : [window]
        let next = "\(Preferences.shared.language)|" + current.map { "\(ObjectIdentifier($0.windowController ?? $0)):\($0.title):\($0.budnoteIsEdited):\($0.representedURL?.absoluteString ?? "")" }.joined(separator: "|")
        let nextSelection = ObjectIdentifier(window.windowController ?? window)
        guard next != signature || selection != nextSelection else { return }
        let rebuild = next != signature
        signature = next
        selection = nextSelection
        var selected: NSView?
        if rebuild {
            for view in stack.arrangedSubviews { stack.removeArrangedSubview(view); view.removeFromSuperview() }
            for tabWindow in current {
                let tab = FileTabView(window: tabWindow, selected: tabWindow === window)
                stack.addArrangedSubview(tab)
                if tabWindow === window { selected = tab }
            }
            stack.layoutSubtreeIfNeeded()
            stack.frame = NSRect(x: 0, y: 0, width: stack.fittingSize.width, height: 28)
        } else {
            for case let tab as FileTabView in stack.arrangedSubviews {
                let active = tab.represents(window)
                tab.updateSelection(active)
                if active { selected = tab }
            }
        }
        if let selected {
            var x = contentView.bounds.minX
            if selected.frame.minX < x { x = selected.frame.minX }
            if selected.frame.maxX > x + contentSize.width { x = selected.frame.maxX - contentSize.width }
            contentView.scroll(to: NSPoint(x: max(0, x), y: 0))
            reflectScrolledClipView(contentView)
        }
    }
}
private final class FileTabView: NSView {
    private weak var tabController: DocumentWindowController?
    private var selected: Bool
    private let button: NSButton
    init(window: NSWindow, selected: Bool) {
        tabController = window.windowController as? DocumentWindowController; self.selected = selected
        let name = window.title.isEmpty ? tr("未命名", "Untitled") : window.title
        button = NSButton(title: name + (window.budnoteIsEdited ? tr(" - 已编辑", " - Edited") : ""), target: nil, action: #selector(selectTab(_:)))
        super.init(frame: .zero)
        button.target = self
        button.isBordered = false; button.font = .systemFont(ofSize: 12, weight: selected ? .medium : .regular)
        button.contentTintColor = selected ? .labelColor : .secondaryLabelColor
        button.lineBreakMode = .byTruncatingMiddle; button.toolTip = window.representedURL?.path ?? name
        button.setAccessibilityLabel(button.title); button.setAccessibilityValue(selected ? tr("当前标签", "Active tab") : "")
        let closeTip = tr("关闭 \(name)", "Close \(name)")
        let close = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: closeTip)!, target: self, action: #selector(closeTab(_:)))
        close.isBordered = false; close.imageScaling = .scaleProportionallyDown; close.contentTintColor = .secondaryLabelColor
        close.toolTip = closeTip; close.setAccessibilityLabel(closeTip)
        for child in [button, close] { child.translatesAutoresizingMaskIntoConstraints = false; addSubview(child) }
        let width = min(280, max(110, (button.title as NSString).size(withAttributes: [.font: button.font!]).width + 38))
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: width), heightAnchor.constraint(equalToConstant: 28),
            button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8), button.centerYAnchor.constraint(equalTo: centerYAnchor), button.trailingAnchor.constraint(equalTo: close.leadingAnchor, constant: -3),
            close.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6), close.centerYAnchor.constraint(equalTo: centerYAnchor), close.widthAnchor.constraint(equalToConstant: 14), close.heightAnchor.constraint(equalToConstant: 14)])
    }
    required init?(coder: NSCoder) { fatalError() }
    func represents(_ window: NSWindow) -> Bool { tabController === window.windowController }
    func updateSelection(_ active: Bool) {
        guard selected != active else { return }
        selected = active
        button.font = .systemFont(ofSize: 12, weight: active ? .medium : .regular)
        button.contentTintColor = active ? .labelColor : .secondaryLabelColor
        button.setAccessibilityValue(active ? tr("当前标签", "Active tab") : "")
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        (selected ? NSColor.controlBackgroundColor : NSColor.quaternaryLabelColor.withAlphaComponent(0.07)).setFill(); path.fill()
        (selected ? Palette.accent.withAlphaComponent(0.55) : NSColor.separatorColor.withAlphaComponent(0.4)).setStroke()
        path.lineWidth = 1; path.stroke()
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
    @objc private func selectTab(_ sender: Any?) {
        guard let tabWindow = tabController?.window else { return }
        DocumentWorkspace.shared.activate(tabWindow, sender: sender)
    }
    @objc private func closeTab(_ sender: Any?) { if let tabController { DocumentWorkspace.shared.requestClose(tabController) } }
}

extension NSWindow {
    var budnoteIsEdited: Bool { windowController?.document?.isDocumentEdited ?? isDocumentEdited }
}
