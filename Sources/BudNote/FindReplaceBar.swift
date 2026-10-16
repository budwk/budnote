import AppKit

final class FindReplaceBar: NSView, NSSearchFieldDelegate {
    let query = NSSearchField()
    let replacement = NSTextField()
    let caseSensitive = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    let result = NSTextField(labelWithString: "")
    private let replacementRow = NSStackView()
    private var prevButton: NSButton!
    private var nextButton: NSButton!
    private var replaceButton: NSButton!
    private var replaceAllButton: NSButton!
    private var closeButton: NSButton!
    var onSearch: ((Bool) -> Void)?
    var onReplace: ((Bool) -> Void)?
    var onClose: (() -> Void)?
    init() {
        super.init(frame: .zero)
        query.delegate = self; query.target = self; query.action = #selector(nextMatch)
        replacement.delegate = self; replacement.target = self; replacement.action = #selector(replaceOne)
        for field in [query as NSTextField, replacement] {
            field.font = .systemFont(ofSize: 14); field.heightAnchor.constraint(equalToConstant: 30).isActive = true
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
        }
        result.font = .monospacedDigitSystemFont(ofSize: 12.5, weight: .regular); result.textColor = .secondaryLabelColor
        caseSensitive.font = .systemFont(ofSize: 13)
        prevButton = actionButton("", #selector(previousMatch))
        nextButton = actionButton("", #selector(nextMatch))
        replaceButton = actionButton("", #selector(replaceOne))
        replaceAllButton = actionButton("", #selector(replaceAll))
        closeButton = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)!, target: self, action: #selector(closeBar))
        closeButton.isBordered = false
        let first = NSStackView(views: [query, prevButton, nextButton, caseSensitive, result, closeButton])
        first.spacing = 8; first.alignment = .centerY
        replacementRow.addArrangedSubview(replacement)
        replacementRow.addArrangedSubview(replaceButton)
        replacementRow.addArrangedSubview(replaceAllButton)
        replacementRow.spacing = 8; replacementRow.alignment = .centerY
        let rows = NSStackView(views: [first, replacementRow]); rows.orientation = .vertical; rows.alignment = .leading; rows.spacing = 10
        rows.translatesAutoresizingMaskIntoConstraints = false; addSubview(rows)
        NSLayoutConstraint.activate([rows.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10), rows.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10), rows.topAnchor.constraint(equalTo: topAnchor, constant: 8), first.widthAnchor.constraint(equalTo: rows.widthAnchor)])
        updateLocalization()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.separatorColor.withAlphaComponent(0.45).setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
    }
    func updateLocalization() {
        query.placeholderString = tr("查找文本", "Find")
        replacement.placeholderString = tr("替换为", "Replace with")
        caseSensitive.title = tr("区分大小写", "Case Sensitive")
        prevButton.title = tr("上一处", "Prev")
        nextButton.title = tr("下一处", "Next")
        replaceButton.title = tr("替换", "Replace")
        replaceAllButton.title = tr("全部替换", "Replace All")
        let closeTip = tr("关闭查找", "Close Find")
        closeButton.toolTip = closeTip
        closeButton.setAccessibilityLabel(closeTip)
    }
    private func actionButton(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action); b.bezelStyle = .rounded; b.font = .systemFont(ofSize: 13); return b
    }
    func showReplacement(_ show: Bool) { replacementRow.isHidden = !show }
    func controlTextDidChange(_ obj: Notification) { if obj.object as? NSSearchField === query { onSearch?(true) } }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) { onClose?(); return true }; return false
    }
    @objc private func nextMatch() { onSearch?(true) }
    @objc private func previousMatch() { onSearch?(false) }
    @objc private func replaceOne() { onReplace?(false) }
    @objc private func replaceAll() { onReplace?(true) }
    @objc private func closeBar() { onClose?() }
}
