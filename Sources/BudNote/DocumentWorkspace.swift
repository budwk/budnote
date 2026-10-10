import AppKit

extension Notification.Name { static let documentTabsChanged = Notification.Name("BudNoteDocumentTabsChanged") }

/// Every document retains its own controller and save lifecycle. The selected
/// controller uses one persistent visible window; other windows remain parked.
/// Switching content does not order windows or change macOS fullscreen spaces.
final class DocumentWorkspace: NSObject {
    static let shared = DocumentWorkspace()
    private final class Entry {
        weak var controller: DocumentWindowController?
        init(_ controller: DocumentWindowController) { self.controller = controller }
    }
    private var entries: [Entry] = []
    private weak var selectedController: DocumentWindowController?
    private var activating = false
    private var closeObserver: NSObjectProtocol?
    private var keyObserver: NSObjectProtocol?
    var controllers: [DocumentWindowController] { entries.compactMap(\.controller) }
    var windows: [NSWindow] { controllers.compactMap(\.window) }
    private override init() {
        super.init()
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let window = note.object as? NSWindow,
                  let controller = self.controllers.first(where: { $0.window === window }) else { return }
            self.remove(controller)
        }
        keyObserver = NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, !self.activating, let window = note.object as? NSWindow, self.windows.contains(window) else { return }
            self.activate(window, sender: nil)
        }
    }
    func register(_ window: NSWindow) {
        guard let controller = window.windowController as? DocumentWindowController, !controllers.contains(controller) else { return }
        entries.append(Entry(controller)); notify()
    }
    func activate(_ window: NSWindow, sender: Any?) {
        guard !activating, let incoming = window.windowController as? DocumentWindowController,
              controllers.contains(incoming) else { return }
        activating = true
        defer { activating = false }
        if let outgoing = selectedController, outgoing !== incoming,
           let host = outgoing.window, let parked = incoming.window,
           let outgoingEditor = host.contentViewController as? EditorController,
           let incomingEditor = parked.contentViewController as? EditorController {
            // Retain both views while transferring document ownership.
            // All changes reach the screen in the same flush, with no empty frame.
            let hostFrame = host.frame, parkedFrame = parked.frame
            host.disableScreenUpdatesUntilFlush()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0; context.allowsImplicitAnimation = false
                host.contentViewController = nil; parked.contentViewController = nil
                outgoing.window = nil; incoming.window = nil
                outgoing.window = parked; incoming.window = host
                parked.contentViewController = outgoingEditor
                host.contentViewController = incomingEditor
                outgoingEditor.attachToolbar(to: parked)
                incomingEditor.attachToolbar(to: host)
                outgoing.synchronizeWindowTitleWithDocumentName()
                incoming.synchronizeWindowTitleWithDocumentName()
                parked.isDocumentEdited = outgoing.document?.isDocumentEdited ?? false
                host.isDocumentEdited = incoming.document?.isDocumentEdited ?? false
                host.representedURL = incoming.document?.fileURL
                parked.representedURL = outgoing.document?.fileURL
                parked.setFrame(parkedFrame, display: false, animate: false)
                host.setFrame(hostFrame, display: false, animate: false)
                selectedController = incoming
                incomingEditor.restoreFocus()
                host.contentView?.layoutSubtreeIfNeeded()
                host.displayIfNeeded()
            }
            // The host already belongs to the active fullscreen space and remains
            // visible/key. Only restore it when the user had minimized the app.
            if host.isMiniaturized { host.deminiaturize(sender) }
            if !host.isVisible { host.makeKeyAndOrderFront(sender) }
        } else {
            selectedController = incoming
            if !window.isKeyWindow { window.makeKeyAndOrderFront(sender) }
        }
        notify()
    }
    func selectAdjacentTab(_ offset: Int) {
        let current = controllers
        guard current.count > 1, let selectedController, let index = current.firstIndex(of: selectedController),
              let window = current[(index + offset + current.count) % current.count].window else { return }
        activate(window, sender: nil)
    }
    func requestClose(_ controller: DocumentWindowController) {
        guard let document = controller.document else { return }
        if document.isDocumentEdited, let window = controller.window { activate(window, sender: nil) }
        document.canClose(withDelegate: self, shouldClose: #selector(document(_:shouldClose:contextInfo:)), contextInfo: nil)
    }
    @objc private func document(_ document: NSDocument, shouldClose: Bool, contextInfo: UnsafeMutableRawPointer?) {
        if shouldClose { document.close() }
    }
    /// Move the visible host to another document before closing its old owner.
    /// This also preserves fullscreen when closing the selected file.
    func prepareToClose(_ document: NSDocument) {
        guard let selectedController, selectedController.document === document,
              let index = controllers.firstIndex(of: selectedController) else { return }
        let remaining = controllers.filter { $0 !== selectedController }
        if !remaining.isEmpty, let next = remaining[min(index, remaining.count - 1)].window { activate(next, sender: nil) }
    }
    private func remove(_ controller: DocumentWindowController) {
        entries.removeAll { $0.controller == nil || $0.controller === controller }
        if selectedController === controller { selectedController = nil }
        notify()
    }
    private func notify() { NotificationCenter.default.post(name: .documentTabsChanged, object: nil) }
}
final class DocumentWindowController: NSWindowController {
    override func showWindow(_ sender: Any?) {
        guard let window else { return }
        DocumentWorkspace.shared.activate(window, sender: sender)
    }
}
final class DocumentWindow: NSWindow {
    override func performClose(_ sender: Any?) {
        if let controller = windowController as? DocumentWindowController {
            DocumentWorkspace.shared.requestClose(controller)
        } else { super.performClose(sender) }
    }
}
