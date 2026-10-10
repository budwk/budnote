import AppKit

final class FindReplaceBar: NSView, NSSearchFieldDelegate {
    let query = NSSearchField()
    let replacement = NSTextField()
    let caseSensitive = NSButton(checkboxWithTitle: "区分大小写", target: nil, action: nil)
    let result = NSTextField(labelWithString: "")
    private let replacementRow = NSStackView()
    var onSearch: ((Bool) -> Void)?
    var onReplace: ((Bool) -> Void)?
    var onClose: (() -> Void)?
    init() {
        super.init(frame: .zero)
        query.placeholderString = "查找文本"; query.delegate = self
        query.target = self; query.action = #selector(nextMatch)
        replacement.delegate = self; replacement.placeholderString = "替换为"; replacement.target = self; replacement.action = #selector(replaceOne)
        for field in [query as NSTextField, replacement] {
            field.font = .systemFont(ofSize: 14); field.heightAnchor.constraint(equalToConstant: 30).isActive = true
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
        }
        result.font = .systemFont(ofSize: 13); result.textColor = .secondaryLabelColor
        caseSensitive.font = .systemFont(ofSize: 13)
        let close = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "关闭查找")!, target: self, action: #selector(closeBar))
        close.isBordered = false; close.toolTip = "关闭查找"
        let first = NSStackView(views: [query, actionButton("上一处", #selector(previousMatch)), actionButton("下一处", #selector(nextMatch)), caseSensitive, result, close])
        first.spacing = 8; first.alignment = .centerY
        replacementRow.addArrangedSubview(replacement)
        replacementRow.addArrangedSubview(actionButton("替换", #selector(replaceOne)))
        replacementRow.addArrangedSubview(actionButton("全部替换", #selector(replaceAll)))
        replacementRow.spacing = 8; replacementRow.alignment = .centerY
        let rows = NSStackView(views: [first, replacementRow]); rows.orientation = .vertical; rows.alignment = .leading; rows.spacing = 10
        rows.translatesAutoresizingMaskIntoConstraints = false; addSubview(rows)
        NSLayoutConstraint.activate([rows.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10), rows.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10), rows.topAnchor.constraint(equalTo: topAnchor, constant: 8), first.widthAnchor.constraint(equalTo: rows.widthAnchor)])
    }
    required init?(coder: NSCoder) { fatalError() }
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
