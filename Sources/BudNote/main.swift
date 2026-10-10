import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var settings: SettingsController?
    private weak var fileMenu: NSMenu?
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
        menu.addItem(item("清除菜单", #selector(NSDocumentController.clearRecentDocuments(_:))))
    }
    func menuWillOpen(_ menu: NSMenu) {
        if menu === fileMenu { pruneFileMenu(menu) }
    }
    private func pruneFileMenu(_ menu: NSMenu) {
        // NSDocument injects standard Save As and Rename commands for documents
        // with autosaving enabled. Keep our Save As with encoding options instead.
        let automaticActions: Set<Selector> = [#selector(NSDocument.saveAs(_:)), Selector(("renameDocument:"))]
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
    private func buildMenu() {
        let menu = NSMenu()
        _ = submenu("BudNote", items: [item("关于 BudNote", #selector(showAbout(_:)), target: self), .separator(), item("设置…", #selector(showSettings(_:)), ",", target: self), .separator(), item("隐藏 BudNote", #selector(NSApplication.hide(_:)), "h"), item("隐藏其他", #selector(NSApplication.hideOtherApplications(_:)), "h", modifiers: [.command, .option]), item("显示全部", #selector(NSApplication.unhideAllApplications(_:))), .separator(), item("退出 BudNote", #selector(NSApplication.terminate(_:)), "q")], parent: menu)
        let file = submenu("文件", items: [item("新建", #selector(NSDocumentController.newDocument(_:)), "n"), item("打开…", #selector(NSDocumentController.openDocument(_:)), "o")], parent: menu)
        fileMenu = file; file.delegate = self
        let recent = NSMenuItem(title: "最近打开", action: nil, keyEquivalent: "")
        let recentMenu = NSMenu(title: "最近打开"); recentMenu.delegate = self
        recentMenu.addItem(item("清除菜单", #selector(NSDocumentController.clearRecentDocuments(_:)))); recent.submenu = recentMenu; file.addItem(recent)
        [NSMenuItem.separator(), item("关闭", #selector(NSWindow.performClose(_:)), "w"), item("保存", #selector(NSDocument.save(_:)), "s"), item("另存为…", #selector(TextDocument.saveAsWithOptions(_:)), "s", modifiers: [.command, .shift]), item("移到…", #selector(NSDocument.move(_:))), item("恢复到已存储版本…", #selector(NSDocument.revertToSaved(_:)))].forEach(file.addItem)
        _ = submenu("编辑", items: [item("撤销", Selector(("undo:")), "z"), item("重做", Selector(("redo:")), "z", modifiers: [.command, .shift]), .separator(), item("剪切", #selector(NSText.cut(_:)), "x"), item("复制", #selector(NSText.copy(_:)), "c"), item("粘贴", #selector(NSText.paste(_:)), "v"), item("全选", #selector(NSText.selectAll(_:)), "a"), .separator(), item("查找…", #selector(EditorController.showFind(_:)), "f"), item("查找并替换…", #selector(EditorController.showReplace(_:)), "f", modifiers: [.command, .option]), item("查找下一个", #selector(EditorController.findNext(_:)), "g"), item("查找上一个", #selector(EditorController.findPrevious(_:)), "g", modifiers: [.command, .shift])], parent: menu)
        _ = submenu("格式", items: [item("自动换行", #selector(EditorController.toggleWrap(_:)), "w", modifiers: [.command, .option]), item("显示行号", #selector(EditorController.toggleLineNumbers(_:)), "l", modifiers: [.command, .option]), .separator(), item("增大字体", #selector(EditorController.increaseFont(_:)), "+"), item("减小字体", #selector(EditorController.decreaseFont(_:)), "-"), item("默认字体大小", #selector(EditorController.resetFont(_:)), "0"), .separator(), item("作为 Markdown 编辑", #selector(EditorController.useMarkdown(_:))), item("转换为 UTF-8 编码", #selector(TextDocument.convertToUTF8(_:)))], parent: menu)
        _ = submenu("显示", items: [item("编辑", #selector(EditorController.editMode(_:)), "1"), item("实时预览", #selector(EditorController.splitMode(_:)), "2"), item("阅读", #selector(EditorController.readMode(_:)), "3"), .separator(), item("进入全屏幕", #selector(NSWindow.toggleFullScreen(_:)), "f", modifiers: [.command, .control])], parent: menu)
        let window = submenu("窗口", items: [item("下一个标签", #selector(nextTab(_:)), "\t", modifiers: .control, target: self), item("上一个标签", #selector(previousTab(_:)), "\t", modifiers: [.control, .shift], target: self), .separator(), item("最小化", #selector(NSWindow.performMiniaturize(_:)), "m"), item("缩放", #selector(NSWindow.performZoom(_:))), item("全部置于前面", #selector(NSApplication.arrangeInFront(_:)))], parent: menu)
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
