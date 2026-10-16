import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var settings: SettingsController?
    private weak var fileMenu: NSMenu?
    private var observer: NSObjectProtocol?
    override init() {
        super.init()
        observer = NotificationCenter.default.addObserver(forName: .preferencesChanged, object: nil, queue: .main) { [weak self] _ in
            self?.buildMenu()
        }
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSWindow.allowsAutomaticWindowTabbing = false
        Preferences.shared.applyAppearance()
        buildMenu()
        _ = NSDocumentController.shared
    }
    func applicationDidFinishLaunching(_ notification: Notification) { NSApp.activate(ignoringOtherApps: true) }
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    @objc func showSettings(_ sender: Any?) {
        if settings == nil { settings = SettingsController() }
        settings?.showWindow(sender); settings?.window?.makeKeyAndOrderFront(sender)
    }
    static var aboutCredits: NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center; paragraph.lineSpacing = 6; paragraph.paragraphSpacing = 8
        let text = NSMutableAttributedString(string: "https://github.com/budwk/budnote", attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph])
        text.addAttribute(.link, value: URL(string: "https://github.com/budwk/budnote")!, range: (text.string as NSString).range(of: "https://github.com/budwk/budnote"))
        return text
    }
    @objc func showAbout(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [.credits: Self.aboutCredits])
        Preferences.shared.applyAppearance()
    }
    @objc func nextTab(_ sender: Any?) { DocumentWorkspace.shared.selectAdjacentTab(1) }
    @objc func previousTab(_ sender: Any?) { DocumentWorkspace.shared.selectAdjacentTab(-1) }
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === fileMenu { pruneFileMenu(menu); return }
        menu.removeAllItems()
        for url in NSDocumentController.shared.recentDocumentURLs {
            let entry = item(url.lastPathComponent, #selector(openRecent(_:)), target: self)
            entry.representedObject = url; menu.addItem(entry)
        }
        if !menu.items.isEmpty { menu.addItem(.separator()) }
        menu.addItem(item(tr("清除菜单", "Clear Menu"), #selector(NSDocumentController.clearRecentDocuments(_:))))
    }
    func menuWillOpen(_ menu: NSMenu) {
        if menu === fileMenu { pruneFileMenu(menu) }
    }
    private func pruneFileMenu(_ menu: NSMenu) {
        // NSDocument injects standard Save As and Rename commands for documents
        // with autosaving enabled. Keep our Save As and Rename items instead.
        let automaticActions: Set<Selector> = [#selector(NSDocument.saveAs(_:)), #selector(NSDocument.rename(_:))]
        for item in menu.items {
            if let action = item.action, automaticActions.contains(action) { menu.removeItem(item) }
        }
    }
    @objc private func openRecent(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            if let error { NSApp.presentError(error) }
        }
    }
    private func item(_ title: String, _ action: Selector?, _ key: String = "", modifiers: NSEvent.ModifierFlags = .command, target: AnyObject? = nil, tag: Int = 0) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key); i.keyEquivalentModifierMask = modifiers; i.target = target; i.tag = tag; return i
    }
    private func submenu(_ title: String, items: [NSMenuItem], parent: NSMenu) -> NSMenu {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: ""); let sub = NSMenu(title: title)
        items.forEach(sub.addItem); i.submenu = sub; parent.addItem(i); return sub
    }
    func buildMenu() {
        let menu = NSMenu()
        _ = submenu("BudNote", items: [
            item(tr("关于 BudNote", "About BudNote"), #selector(showAbout(_:)), target: self),
            .separator(),
            item(tr("设置…", "Settings…"), #selector(showSettings(_:)), ",", target: self),
            .separator(),
            item(tr("隐藏 BudNote", "Hide BudNote"), #selector(NSApplication.hide(_:)), "h"),
            item(tr("隐藏其他", "Hide Others"), #selector(NSApplication.hideOtherApplications(_:)), "h", modifiers: [.command, .option]),
            item(tr("显示全部", "Show All"), #selector(NSApplication.unhideAllApplications(_:))),
            .separator(),
            item(tr("退出 BudNote", "Quit BudNote"), #selector(NSApplication.terminate(_:)), "q")
        ], parent: menu)
        let file = submenu(tr("文件", "File"), items: [
            item(tr("新建", "New"), #selector(NSDocumentController.newDocument(_:)), "n"),
            item(tr("打开…", "Open…"), #selector(NSDocumentController.openDocument(_:)), "o")
        ], parent: menu)
        fileMenu = file; file.delegate = self
        let recentTitle = tr("最近打开", "Open Recent")
        let recent = NSMenuItem(title: recentTitle, action: nil, keyEquivalent: "")
        let recentMenu = NSMenu(title: recentTitle); recentMenu.delegate = self
        recentMenu.addItem(item(tr("清除菜单", "Clear Menu"), #selector(NSDocumentController.clearRecentDocuments(_:)))); recent.submenu = recentMenu; file.addItem(recent)
        [
            NSMenuItem.separator(),
            item(tr("关闭", "Close"), #selector(NSWindow.performClose(_:)), "w"),
            item(tr("保存", "Save"), #selector(NSDocument.save(_:)), "s"),
            item(tr("另存为…", "Save As…"), #selector(TextDocument.saveAsWithOptions(_:)), "s", modifiers: [.command, .shift]),
            item(tr("重命名…", "Rename…"), #selector(TextDocument.renameDocumentItem(_:))),
            item(tr("移到…", "Move To…"), #selector(NSDocument.move(_:))),
            item(tr("恢复到已存储版本…", "Revert to Saved…"), #selector(NSDocument.revertToSaved(_:)))
        ].forEach(file.addItem)
        _ = submenu(tr("编辑", "Edit"), items: [
            item(tr("撤销", "Undo"), Selector(("undo:")), "z"),
            item(tr("重做", "Redo"), Selector(("redo:")), "z", modifiers: [.command, .shift]),
            .separator(),
            item(tr("剪切", "Cut"), #selector(NSText.cut(_:)), "x"),
            item(tr("复制", "Copy"), #selector(NSText.copy(_:)), "c"),
            item(tr("粘贴", "Paste"), #selector(NSText.paste(_:)), "v"),
            item(tr("全选", "Select All"), #selector(NSText.selectAll(_:)), "a"),
            .separator(),
            item(tr("查找…", "Find…"), #selector(EditorController.showFind(_:)), "f"),
            item(tr("查找并替换…", "Find and Replace…"), #selector(EditorController.showReplace(_:)), "f", modifiers: [.command, .option]),
            item(tr("查找下一个", "Find Next"), #selector(EditorController.findNext(_:)), "g"),
            item(tr("查找上一个", "Find Previous"), #selector(EditorController.findPrevious(_:)), "g", modifiers: [.command, .shift])
        ], parent: menu)
        _ = submenu(tr("格式", "Format"), items: [
            item(tr("自动换行", "Word Wrap"), #selector(EditorController.toggleWrap(_:)), "w", modifiers: [.command, .option]),
            item(tr("显示行号", "Line Numbers"), #selector(EditorController.toggleLineNumbers(_:)), "l", modifiers: [.command, .option]),
            .separator(),
            item(tr("增大字体", "Bigger"), #selector(EditorController.increaseFont(_:)), "+"),
            item(tr("减小字体", "Smaller"), #selector(EditorController.decreaseFont(_:)), "-"),
            item(tr("默认字体大小", "Default Size"), #selector(EditorController.resetFont(_:)), "0"),
            .separator(),
            item(tr("作为 Markdown 编辑", "Edit as Markdown"), #selector(EditorController.useMarkdown(_:))),
            item(tr("转换为 UTF-8 编码", "Convert to UTF-8"), #selector(TextDocument.convertToUTF8(_:)))
        ], parent: menu)
        _ = submenu(tr("显示", "View"), items: [
            item(tr("编辑", "Edit"), #selector(EditorController.editMode(_:)), "1"),
            item(tr("实时预览", "Split Preview"), #selector(EditorController.splitMode(_:)), "2"),
            item(tr("阅读", "Read"), #selector(EditorController.readMode(_:)), "3"),
            .separator(),
            item(tr("进入全屏幕", "Enter Full Screen"), #selector(NSWindow.toggleFullScreen(_:)), "f", modifiers: [.command, .control])
        ], parent: menu)
        let window = submenu(tr("窗口", "Window"), items: [
            item(tr("下一个标签", "Select Next Tab"), #selector(nextTab(_:)), "\t", modifiers: .control, target: self),
            item(tr("上一个标签", "Select Previous Tab"), #selector(previousTab(_:)), "\t", modifiers: [.control, .shift], target: self),
            .separator(),
            item(tr("最小化", "Minimize"), #selector(NSWindow.performMiniaturize(_:)), "m"),
            item(tr("缩放", "Zoom"), #selector(NSWindow.performZoom(_:))),
            item(tr("全部置于前面", "Bring All to Front"), #selector(NSApplication.arrangeInFront(_:)))
        ], parent: menu)
        NSApp.windowsMenu = window
        NSApp.mainMenu = menu
    }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
#if DEBUG
if CommandLine.arguments.contains("--smoke-test") {
    app.delegate = nil
    app.setActivationPolicy(.prohibited)
    app.finishLaunching()
    do { try runSmokeTests(); exit(0) }
    catch { fputs("FAIL: \(error.localizedDescription)\n", stderr); exit(1) }
}
#endif
app.run()
