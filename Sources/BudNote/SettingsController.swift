import AppKit
import UniformTypeIdentifiers

final class SettingsController: NSWindowController {
    private let sizeField = NSTextField(labelWithString: "")
    private let sizeStepper = NSStepper()
    private let wrap = NSButton(checkboxWithTitle: "自动换行", target: nil, action: nil)
    private let lines = NSButton(checkboxWithTitle: "显示行号", target: nil, action: nil)
    private let theme = NSPopUpButton()
    private var types: [(String, NSButton)] = []
    private let result = NSTextField(wrappingLabelWithString: "")
    private let defaultButton = NSButton(title: "设为所选类型的默认应用", target: nil, action: nil)
    private var observer: NSObjectProtocol?
    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 470), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "BudNote 设置"; window.isReleasedWhenClosed = false
        super.init(window: window)
        let title = NSTextField(labelWithString: "让书写更自在")
        title.font = .systemFont(ofSize: 22, weight: .semibold); title.textColor = Palette.accent
        let subtitle = NSTextField(labelWithString: "外观和编辑偏好适用于所有窗口")
        subtitle.textColor = .secondaryLabelColor; subtitle.font = .systemFont(ofSize: 12)
        theme.addItems(withTitles: ["跟随系统", "浅色 · 晨露", "深色 · 林间"])
        theme.target = self; theme.action = #selector(themeChanged(_:))
        sizeStepper.minValue = 10; sizeStepper.maxValue = 40; sizeStepper.increment = 1
        sizeStepper.target = self; sizeStepper.action = #selector(sizeChanged(_:)); sizeStepper.setAccessibilityLabel("字体大小")
        sizeField.widthAnchor.constraint(equalToConstant: 52).isActive = true
        let fontRow = NSStackView(views: [NSTextField(labelWithString: "字体大小"), sizeField, sizeStepper])
        fontRow.spacing = 16
        wrap.target = self; wrap.action = #selector(wrapChanged(_:)); lines.target = self; lines.action = #selector(linesChanged(_:))
        let associationTitle = NSTextField(labelWithString: "默认打开方式")
        associationTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        let associationHint = NSTextField(wrappingLabelWithString: "先将 BudNote 拖入“应用程序”，再选择文件类型。macOS 可能弹出确认窗口；HTML 默认不选中。")
        associationHint.font = .systemFont(ofSize: 12); associationHint.textColor = .secondaryLabelColor
        let formats = ["txt", "md", "html", "py", "java", "json", "css", "js"]
        for ext in formats {
            let b = NSButton(checkboxWithTitle: ".\(ext)", target: nil, action: nil)
            b.state = ["txt", "md", "py", "java"].contains(ext) ? .on : .off; types.append((ext, b))
        }
        let row1 = NSStackView(views: types.prefix(4).map(\.1)), row2 = NSStackView(views: types.suffix(4).map(\.1))
        row1.distribution = .fillEqually; row2.distribution = .fillEqually
        defaultButton.target = self; defaultButton.action = #selector(setDefaults(_:)); defaultButton.bezelStyle = .rounded
        result.font = .systemFont(ofSize: 12); result.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [title, subtitle, theme, fontRow, wrap, lines, NSBox(), associationTitle, associationHint, row1, row2, defaultButton, result])
        (stack.views[6] as? NSBox)?.boxType = .separator
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 14; stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 26), stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28), stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28), stack.bottomAnchor.constraint(lessThanOrEqualTo: window.contentView!.bottomAnchor, constant: -20), associationHint.widthAnchor.constraint(equalTo: stack.widthAnchor), row1.widthAnchor.constraint(equalTo: stack.widthAnchor), row2.widthAnchor.constraint(equalTo: stack.widthAnchor), result.widthAnchor.constraint(equalTo: stack.widthAnchor)])
        window.setContentSize(NSSize(width: 480, height: 540)); window.center()
        sync()
        observer = NotificationCenter.default.addObserver(forName: .preferencesChanged, object: nil, queue: .main) { [weak self] _ in self?.sync() }
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    private func sync() {
        let p = Preferences.shared
        p.applyAppearance()
        sizeField.stringValue = "\(Int(p.fontSize)) pt"; sizeStepper.doubleValue = p.fontSize
        wrap.state = p.wrap ? .on : .off; lines.state = p.lineNumbers ? .on : .off; theme.selectItem(at: p.theme)
    }
    @objc private func sizeChanged(_ sender: NSStepper) { Preferences.shared.fontSize = sender.doubleValue }
    @objc private func wrapChanged(_ sender: NSButton) { Preferences.shared.wrap = sender.state == .on }
    @objc private func linesChanged(_ sender: NSButton) { Preferences.shared.lineNumbers = sender.state == .on }
    @objc private func themeChanged(_ sender: NSPopUpButton) { Preferences.shared.theme = sender.indexOfSelectedItem }
    @objc private func setDefaults(_ sender: Any?) {
        let selected = types.filter { $0.1.state == .on }.map(\.0)
        guard !selected.isEmpty else { result.stringValue = "请至少选择一种文件类型。"; return }
        defaultButton.isEnabled = false
        result.stringValue = "正在设置，请完成 macOS 的确认提示…"
        associate(selected, successes: [], failures: [])
    }
    private func associate(_ remaining: [String], successes: [String], failures: [String]) {
        guard let ext = remaining.first else {
            defaultButton.isEnabled = true
            result.stringValue = (successes.isEmpty ? "" : "已设置：\(successes.map { "." + $0 }.joined(separator: "、"))。") + (failures.isEmpty ? "" : "未完成：\(failures.joined(separator: "；"))。可在 Finder → 显示简介 → 打开方式 → 全部更改中设置。")
            return
        }
        guard let type = UTType(filenameExtension: ext) else { associate(Array(remaining.dropFirst()), successes: successes, failures: failures + [".\(ext)：无法识别类型"]); return }
        NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: type) { [weak self] error in
            DispatchQueue.main.async {
                self?.associate(Array(remaining.dropFirst()), successes: successes + (error == nil ? [ext] : []), failures: failures + (error.map { [".\(ext)：\($0.localizedDescription)"] } ?? []))
            }
        }
    }
}
