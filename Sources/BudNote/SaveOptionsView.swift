import AppKit
import BudCore

final class SaveOptionsView: NSView, NSComboBoxDelegate {
    private let encodings = NSPopUpButton()
    private let suffix = NSComboBox()
    private weak var panel: NSSavePanel?
    private let originalCodec: TextCodec
    private static let codecs: [(String, TextCodec)] = [
        ("UTF-8", TextCodec()), ("UTF-8（BOM）", TextCodec(bom: Data([0xef, 0xbb, 0xbf]))),
        ("UTF-16 LE", TextCodec(encoding: .utf16LittleEndian, bom: Data([0xff, 0xfe]))),
        ("UTF-16 BE", TextCodec(encoding: .utf16BigEndian, bom: Data([0xfe, 0xff]))),
        ("UTF-32 LE", TextCodec(encoding: .utf32LittleEndian, bom: Data([0xff, 0xfe, 0, 0]))),
        ("UTF-32 BE", TextCodec(encoding: .utf32BigEndian, bom: Data([0, 0, 0xfe, 0xff]))),
        ("GB18030", TextCodec(encoding: .gb_18030_2000))
    ]
    var selectedCodec: TextCodec { encodings.indexOfSelectedItem == 0 ? originalCodec : Self.codecs[encodings.indexOfSelectedItem - 1].1 }
    init(panel: NSSavePanel, codec: TextCodec) {
        self.panel = panel; originalCodec = codec
        super.init(frame: NSRect(x: 0, y: 0, width: 420, height: 84))
        encodings.addItems(withTitles: ["保持原编码（\(codec.name)）"] + Self.codecs.map { $0.0 })
        suffix.addItems(withObjectValues: ["txt", "md", "html", "py", "java", "json", "css", "js", "无后缀"])
        suffix.stringValue = (panel.nameFieldStringValue as NSString).pathExtension
        if suffix.stringValue.isEmpty { suffix.stringValue = "txt" }
        suffix.delegate = self
        suffix.target = self; suffix.action = #selector(changeSuffix)
        suffix.setAccessibilityLabel("文件后缀名")
        encodings.setAccessibilityLabel("编码格式")
        let rows = NSStackView(views: [NSStackView(views: [NSTextField(labelWithString: "后缀名"), suffix]), NSStackView(views: [NSTextField(labelWithString: "编码格式"), encodings])])
        rows.orientation = .vertical; rows.alignment = .leading; rows.spacing = 10
        rows.translatesAutoresizingMaskIntoConstraints = false; addSubview(rows)
        NSLayoutConstraint.activate([rows.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12), rows.topAnchor.constraint(equalTo: topAnchor, constant: 8), rows.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12), suffix.widthAnchor.constraint(equalToConstant: 240), encodings.widthAnchor.constraint(equalToConstant: 240)])
    }
    required init?(coder: NSCoder) { fatalError() }
    func controlTextDidChange(_ notification: Notification) { changeSuffix() }
    func controlTextDidEndEditing(_ notification: Notification) { changeSuffix() }
    func comboBoxSelectionDidChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in self?.changeSuffix() }
    }
    @objc private func changeSuffix() {
        guard let panel else { return }
        let ext = suffix.stringValue.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        guard !ext.contains("/"), !ext.contains(":") else { return }
        let base = (panel.nameFieldStringValue as NSString).deletingPathExtension
        panel.nameFieldStringValue = ext.isEmpty || ext == "无后缀" ? base : base + "." + ext
    }
}
