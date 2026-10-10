import AppKit
import BudCore

@objc(TextDocument)
final class TextDocument: NSDocument {
    var content = ""
    var codec = TextCodec()
    weak var editor: EditorController?
    let editingUndoManager = UndoManager()
    private var fileOperationInProgress = false
    private var undoObservers: [NSObjectProtocol] = []
    deinit { undoObservers.forEach(NotificationCenter.default.removeObserver) }
    private func configureUndoTracking() {
        guard undoObservers.isEmpty else { return }
        // Track one change per undo group using a dedicated editor manager.
        // This makes text undo and document dirty state use exactly the same history.
        hasUndoManager = false
        let center = NotificationCenter.default
        undoObservers.append(center.addObserver(forName: .NSUndoManagerWillCloseUndoGroup, object: editingUndoManager, queue: nil) { [weak self] _ in
            guard let self, self.editingUndoManager.groupingLevel == 1,
                  !self.editingUndoManager.isUndoing, !self.editingUndoManager.isRedoing,
                  self.editingUndoManager.canUndo else { return }
            self.updateChangeCount(.changeDone)
        })
        undoObservers.append(center.addObserver(forName: .NSUndoManagerDidUndoChange, object: editingUndoManager, queue: nil) { [weak self] _ in self?.updateChangeCount(.changeUndone) })
        undoObservers.append(center.addObserver(forName: .NSUndoManagerDidRedoChange, object: editingUndoManager, queue: nil) { [weak self] _ in self?.updateChangeCount(.changeRedone) })
    }
    override class var autosavesInPlace: Bool { true }
    override class var preservesVersions: Bool { true }
    override var fileURL: URL? { didSet { editor?.fileDidChange() } }
    override func read(from data: Data, ofType typeName: String) throws {
        (content, codec) = try TextCodec.decode(data)
        editor?.reloadContent()
    }
    override func data(ofType typeName: String) throws -> Data { try codec.encode(content) }
    override func makeWindowControllers() {
        configureUndoTracking()
        let controller = EditorController(document: self)
        editor = controller
        let window = DocumentWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 740),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.animationBehavior = .none
        window.minSize = NSSize(width: 680, height: 420)
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.setContentSize(NSSize(width: 1080, height: 740))
        window.tabbingMode = .disallowed
        window.center()
        let wc = DocumentWindowController(window: window)
        addWindowController(wc)
        DocumentWorkspace.shared.register(window)
        controller.installToolbar(on: window)
        for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(type)?.isHidden = false
        }
        window.makeFirstResponder(controller.textView)
    }
    override func close() {
        DocumentWorkspace.shared.prepareToClose(self)
        super.close()
    }
    override func updateChangeCount(_ change: NSDocument.ChangeType) {
        super.updateChangeCount(change)
        editor?.refreshChrome()
        NotificationCenter.default.post(name: .documentTabsChanged, object: nil)
    }
    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        savePanel.allowsOtherFileTypes = true
        savePanel.isExtensionHidden = false
        return true
    }
    override func saveAs(_ sender: Any?) { saveAsWithOptions(sender) }
    @objc func saveAsWithOptions(_ sender: Any?) {
        guard !fileOperationInProgress else { return }
        let panel = NSSavePanel()
        panel.title = "另存为"; panel.prompt = "保存"
        panel.allowedContentTypes = []; panel.allowsOtherFileTypes = true
        panel.canCreateDirectories = true; panel.isExtensionHidden = false
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "未命名.txt"
        panel.directoryURL = fileURL?.deletingLastPathComponent()
        let options = SaveOptionsView(panel: panel, codec: codec)
        panel.accessoryView = options
        let finish: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            self.saveCopy(to: url, codec: options.selectedCodec) { error in
                if let error { self.presentError(error) }
            }
        }
        if let window = windowControllers.first?.window { panel.beginSheetModal(for: window, completionHandler: finish) }
        else { panel.begin(completionHandler: finish) }
    }
    // NSDocument owns the safe write, URL update and change-count bookkeeping.
    func saveCopy(to url: URL, codec selectedCodec: TextCodec, completion: @escaping (Error?) -> Void) {
        guard !fileOperationInProgress else { completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)); return }
        do { _ = try selectedCodec.encode(content) } catch { completion(error); return }
        fileOperationInProgress = true
        let previous = codec
        let editable = editor?.textView.isEditable ?? true
        editor?.textView.isEditable = false
        codec = selectedCodec
        save(to: url, ofType: fileType ?? "public.plain-text", for: .saveAsOperation) { error in
            if error != nil { self.codec = previous }
            self.fileOperationInProgress = false; self.editor?.textView.isEditable = editable
            self.editor?.refreshStatus(); completion(error)
        }
    }
    override func move(_ sender: Any?) {
        guard !fileOperationInProgress else { return }
        guard let current = fileURL else { saveAs(sender); return }
        let panel = NSOpenPanel()
        panel.title = "移到"; panel.message = "选择目标文件夹，保留当前文件名称。"; panel.prompt = "移到此处"
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false; panel.directoryURL = current.deletingLastPathComponent()
        let finish: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self, response == .OK, let folder = panel.url else { return }
            let destination = folder.appendingPathComponent(current.lastPathComponent)
            guard destination != current else { return }
            // Leave existing files untouched; choosing another folder is always reversible.
            if FileManager.default.fileExists(atPath: destination.path) {
                self.presentError(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteFileExistsError, userInfo: [NSLocalizedDescriptionKey: "目标文件夹已存在同名文件，请选择其他位置或使用“另存为”。"]))
                return
            }
            self.moveFile(to: destination) { error in if let error { self.presentError(error) } }
        }
        if let window = windowControllers.first?.window { panel.beginSheetModal(for: window, completionHandler: finish) }
        else { panel.begin(completionHandler: finish) }
    }
    func moveFile(to destination: URL, completion: @escaping (Error?) -> Void) {
        guard !fileOperationInProgress, let current = fileURL else { completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)); return }
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            completion(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteFileExistsError)); return
        }
        fileOperationInProgress = true
        let editable = editor?.textView.isEditable ?? true
        editor?.textView.isEditable = false
        let finish: (Error?) -> Void = { error in
            self.fileOperationInProgress = false; self.editor?.textView.isEditable = editable
            self.editor?.refreshStatus(); completion(error)
        }
        // Flush pending edits before the coordinated move so neither location loses text.
        save(to: current, ofType: fileType ?? "public.plain-text", for: .saveOperation) { error in
            if let error { finish(error); return }
            self.move(to: destination, completionHandler: finish)
        }
    }
    @objc func convertToUTF8(_ sender: Any?) {
        codec = TextCodec(); updateChangeCount(.changeDone); editor?.refreshStatus()
    }
}
