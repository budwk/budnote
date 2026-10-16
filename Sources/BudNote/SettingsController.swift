import AppKit
import UniformTypeIdentifiers

final class SettingsController: NSWindowController {
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let languageLabel = NSTextField(labelWithString: "")
    private let themeLabel = NSTextField(labelWithString: "")
    private let fontLabel = NSTextField(labelWithString: "")
    private let editorLabel = NSTextField(labelWithString: "")
    private let language = NSPopUpButton()
    private let theme = NSPopUpButton()
    private let sizeField = NSTextField(labelWithString: "")
    private let sizeStepper = NSStepper()
    private let wrap = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let lines = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let associationTitle = NSTextField(labelWithString: "")
    private let associationHint = NSTextField(wrappingLabelWithString: "")
    private var types: [(String, NSButton)] = []
    private let result = NSTextField(wrappingLabelWithString: "")
    private let defaultButton = NSButton(title: "", target: nil, action: nil)
    private var observer: NSObjectProtocol?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 520), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        super.init(window: window)

        titleLabel.font = .systemFont(ofSize: 21, weight: .semibold)
        titleLabel.textColor = Palette.accent
        subtitleLabel.font = .systemFont(ofSize: 12.5, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor

        let headerStack = NSStackView(views: [titleLabel, subtitleLabel])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 4

        language.addItems(withTitles: ["简体中文", "English"])
        language.target = self; language.action = #selector(languageChanged(_:))
        language.font = .systemFont(ofSize: 13)
        language.widthAnchor.constraint(equalToConstant: 200).isActive = true

        theme.target = self; theme.action = #selector(themeChanged(_:))
        theme.font = .systemFont(ofSize: 13)
        theme.widthAnchor.constraint(equalToConstant: 200).isActive = true

        sizeStepper.minValue = 10; sizeStepper.maxValue = 40; sizeStepper.increment = 1
        sizeStepper.target = self; sizeStepper.action = #selector(sizeChanged(_:))
        sizeField.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        sizeField.textColor = .labelColor
        sizeField.widthAnchor.constraint(equalToConstant: 48).isActive = true
        let fontControlStack = NSStackView(views: [sizeField, sizeStepper])
        fontControlStack.spacing = 8
        fontControlStack.alignment = .centerY

        wrap.font = .systemFont(ofSize: 13)
        wrap.target = self; wrap.action = #selector(wrapChanged(_:))
        lines.font = .systemFont(ofSize: 13)
        lines.target = self; lines.action = #selector(linesChanged(_:))
        let togglesStack = NSStackView(views: [wrap, lines])
        togglesStack.spacing = 20
        togglesStack.alignment = .centerY

        func makeFormRow(label: NSTextField, control: NSView) -> NSStackView {
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.textColor = .labelColor
            label.alignment = .left
            label.widthAnchor.constraint(equalToConstant: 96).isActive = true
            let row = NSStackView(views: [label, control])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 12
            return row
        }

        let formStack = NSStackView(views: [
            makeFormRow(label: languageLabel, control: language),
            makeFormRow(label: themeLabel, control: theme),
            makeFormRow(label: fontLabel, control: fontControlStack),
            makeFormRow(label: editorLabel, control: togglesStack)
        ])
        formStack.orientation = .vertical
        formStack.alignment = .leading
        formStack.spacing = 12

        let divider = NSBox()
        divider.boxType = .separator

        associationTitle.font = .systemFont(ofSize: 14, weight: .semibold)
        associationTitle.textColor = .labelColor
        associationHint.font = .systemFont(ofSize: 12, weight: .regular)
        associationHint.textColor = .secondaryLabelColor

        let formats = ["txt", "md", "html", "py", "java", "json", "css", "js"]
        for ext in formats {
            let b = NSButton(checkboxWithTitle: ".\(ext)", target: nil, action: nil)
            b.font = .monospacedSystemFont(ofSize: 12.5, weight: .regular)
            b.state = ["txt", "md", "py", "java"].contains(ext) ? .on : .off
            types.append((ext, b))
        }
        let row1 = NSStackView(views: types.prefix(4).map(\.1))
        let row2 = NSStackView(views: types.suffix(4).map(\.1))
        row1.distribution = .fillEqually
        row2.distribution = .fillEqually

        defaultButton.target = self; defaultButton.action = #selector(setDefaults(_:))
        defaultButton.bezelStyle = .rounded
        defaultButton.font = .systemFont(ofSize: 13, weight: .medium)
        result.font = .systemFont(ofSize: 12)
        result.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [
            headerStack, formStack, divider,
            associationTitle, associationHint, row1, row2, defaultButton, result
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.setCustomSpacing(18, after: headerStack)
        stack.setCustomSpacing(16, after: formStack)
        stack.setCustomSpacing(16, after: divider)
        stack.setCustomSpacing(6, after: associationTitle)
        stack.setCustomSpacing(12, after: associationHint)
        stack.setCustomSpacing(8, after: row1)
        stack.setCustomSpacing(14, after: row2)
        stack.translatesAutoresizingMaskIntoConstraints = false

        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: window.contentView!.bottomAnchor, constant: -20),
            divider.widthAnchor.constraint(equalTo: stack.widthAnchor),
            associationHint.widthAnchor.constraint(equalTo: stack.widthAnchor),
            row1.widthAnchor.constraint(equalTo: stack.widthAnchor),
            row2.widthAnchor.constraint(equalTo: stack.widthAnchor),
            result.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        window.setContentSize(NSSize(width: 500, height: 520))
        window.center()
        sync()
        observer = NotificationCenter.default.addObserver(forName: .preferencesChanged, object: nil, queue: .main) { [weak self] _ in self?.sync() }
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

    private func sync() {
        let p = Preferences.shared
        p.applyAppearance()
        window?.title = tr("BudNote 设置", "BudNote Settings")
        titleLabel.stringValue = tr("让书写更自在", "Write with Ease")
        subtitleLabel.stringValue = tr("外观、语言和编辑偏好适用于所有窗口", "Appearance, language, and editor preferences apply to all windows")
        languageLabel.stringValue = tr("界面语言", "Language")
        themeLabel.stringValue = tr("外观主题", "Appearance")
        fontLabel.stringValue = tr("字体大小", "Font Size")
        editorLabel.stringValue = tr("编辑选项", "Editor")

        language.selectItem(at: p.language)
        language.setAccessibilityLabel(tr("界面语言", "Language"))

        let themeTitles = [
            tr("跟随系统", "System"),
            tr("浅色 · 晨露", "Light · Dew"),
            tr("深色 · 林间", "Dark · Forest")
        ]
        if theme.itemTitles != themeTitles {
            theme.removeAllItems()
            theme.addItems(withTitles: themeTitles)
        }
        theme.selectItem(at: p.theme)
        theme.setAccessibilityLabel(tr("外观主题", "Appearance"))

        sizeField.stringValue = "\(Int(p.fontSize)) pt"
        sizeStepper.doubleValue = p.fontSize
        sizeStepper.setAccessibilityLabel(tr("字体大小", "Font Size"))

        wrap.title = tr("自动换行", "Word Wrap")
        wrap.state = p.wrap ? .on : .off
        lines.title = tr("显示行号", "Show Line Numbers")
        lines.state = p.lineNumbers ? .on : .off

        associationTitle.stringValue = tr("默认打开方式", "Default File Associations")
        associationHint.stringValue = tr(
            "先将 BudNote 拖入“应用程序”，再选择文件类型。macOS 可能弹出确认窗口；HTML 默认不选中。",
            "Move BudNote to Applications first, then select file types. macOS may prompt for confirmation; HTML is unchecked by default."
        )
        defaultButton.title = tr("设为所选类型的默认应用", "Set as Default for Selected Types")
    }

    @objc private func languageChanged(_ sender: NSPopUpButton) { Preferences.shared.language = sender.indexOfSelectedItem }
    @objc private func sizeChanged(_ sender: NSStepper) { Preferences.shared.fontSize = sender.doubleValue }
    @objc private func wrapChanged(_ sender: NSButton) { Preferences.shared.wrap = sender.state == .on }
    @objc private func linesChanged(_ sender: NSButton) { Preferences.shared.lineNumbers = sender.state == .on }
    @objc private func themeChanged(_ sender: NSPopUpButton) { Preferences.shared.theme = sender.indexOfSelectedItem }
    @objc private func setDefaults(_ sender: Any?) {
        let selected = types.filter { $0.1.state == .on }.map(\.0)
        guard !selected.isEmpty else {
            result.stringValue = tr("请至少选择一种文件类型。", "Please select at least one file type.")
            return
        }
        defaultButton.isEnabled = false
        result.stringValue = tr("正在设置，请完成 macOS 的确认提示…", "Applying settings, please confirm the macOS prompt…")
        associate(selected, successes: [], failures: [])
    }
    private func associate(_ remaining: [String], successes: [String], failures: [String]) {
        guard let ext = remaining.first else {
            defaultButton.isEnabled = true
            let sep = tr("、", ", ")
            let okText = successes.isEmpty ? "" : tr(
                "已设置：\(successes.map { "." + $0 }.joined(separator: sep))。",
                "Configured: \(successes.map { "." + $0 }.joined(separator: sep)). "
            )
            let failText = failures.isEmpty ? "" : tr(
                "未完成：\(failures.joined(separator: "；"))。可在 Finder → 显示简介 → 打开方式 → 全部更改中设置。",
                "Incomplete: \(failures.joined(separator: "; ")). You can also set this in Finder → Get Info → Open with → Change All."
            )
            result.stringValue = okText + failText
            return
        }
        guard let type = UTType(filenameExtension: ext) else {
            associate(Array(remaining.dropFirst()), successes: successes, failures: failures + [tr(".\(ext)：无法识别类型", ".\(ext): unrecognized type")])
            return
        }
        NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: type) { [weak self] error in
            DispatchQueue.main.async {
                self?.associate(
                    Array(remaining.dropFirst()),
                    successes: successes + (error == nil ? [ext] : []),
                    failures: failures + (error.map { [".\(ext): \($0.localizedDescription)"] } ?? [])
                )
            }
        }
    }
}
