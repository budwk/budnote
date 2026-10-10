import Foundation

/// A dependency-free, safe Markdown subset. Raw HTML is displayed as text.
public enum Markdown {
    public static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    private static func replace(_ pattern: String, in text: String, transform: (NSTextCheckingResult, NSString) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let source = text as NSString
        var result = text
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)).reversed() {
            let range = Range(match.range, in: result)!
            result.replaceSubrange(range, with: transform(match, source))
        }
        return result
    }
    public static func inline(_ text: String) -> String {
        var tokens: [String] = []
        func stash(_ html: String) -> String { tokens.append(html); return "\u{001f}\(tokens.count - 1)\u{001f}" }
        // Escape before inserting our own tags. Tokens protect code and link markup.
        var value = escape(text.replacingOccurrences(of: "\u{001f}", with: ""))
        value = replace("`([^`]+)`", in: value) { m, s in stash("<code>\(s.substring(with: m.range(at: 1)))</code>") }
        value = replace(#"!?\[([^\]]*)\]\(([^\s)]+)(?:\s+&quot;.*?&quot;)?\)"#, in: value) { m, s in
            let label = s.substring(with: m.range(at: 1)), url = s.substring(with: m.range(at: 2))
            // Only explicit web/mail links; never execute arbitrary protocols or load remote images.
            guard let parsed = URL(string: url.replacingOccurrences(of: "&amp;", with: "&")),
                  ["http", "https", "mailto"].contains(parsed.scheme?.lowercased() ?? "") else { return label }
            if s.substring(with: m.range).hasPrefix("!") { return stash("<span class='image'>▧ \(label)</span>") }
            return stash("<a href='\(url)'>\(label)</a>")
        }
        for (pattern, tag) in [(#"\*\*(.+?)\*\*"#, "strong"), (#"__(.+?)__"#, "strong"), (#"~~(.+?)~~"#, "del"), (#"(?<!\*)\*([^*]+)\*(?!\*)"#, "em"), (#"(?<!\w)_([^_]+)_(?!\w)"#, "em")] {
            value = replace(pattern, in: value) { m, s in "<\(tag)>\(s.substring(with: m.range(at: 1)))</\(tag)>" }
        }
        for (index, token) in tokens.enumerated().reversed() { value = value.replacingOccurrences(of: "\u{001f}\(index)\u{001f}", with: token) }
        return value
    }
    public static func render(_ source: String, sourcePositions: Bool = false) -> String {
        let lines = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        var output: [String] = [], paragraph: [(String, Int)] = [], code: [String] = []
        var codeStart = 1
        var fence: String?, list: String?
        func positioned(_ html: String, line: Int, end: Int? = nil) -> String {
            guard sourcePositions, let insertion = html.firstIndex(of: ">") else { return html }
            var result = html
            result.insert(contentsOf: " data-source-line='\(line)' data-source-end='\(end ?? line)'", at: insertion)
            return result
        }
        func flush() {
            if !paragraph.isEmpty {
                output.append("<p>\(paragraph.map { sourcePositions ? positioned("<span>\(inline($0.0))</span>", line: $0.1) : inline($0.0) }.joined(separator: "<br>"))</p>")
                paragraph.removeAll()
            }
        }
        func closeList() { if let kind = list { output.append("</\(kind)>"); list = nil } }
        func cells(_ line: String) -> [String] {
            var parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: "|")
            if parts.first?.isEmpty == true { parts.removeFirst() }; if parts.last?.isEmpty == true { parts.removeLast() }
            return parts.map { $0.trimmingCharacters(in: .whitespaces) }
        }
        var i = 0
        while i < lines.count {
            let line = lines[i], trimmed = line.trimmingCharacters(in: .whitespaces)
            i += 1
            if let marker = fence {
                if trimmed.hasPrefix(marker) { output.append(positioned("<pre><code>\(escape(code.joined(separator: "\n")))</code></pre>", line: codeStart, end: i)); code.removeAll(); fence = nil }
                else { code.append(line) }
                continue
            }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { flush(); closeList(); fence = String(trimmed.prefix(3)); codeStart = i; continue }
            if trimmed.isEmpty { flush(); closeList(); continue }
            if i < lines.count, line.contains("|"), cells(lines[i]).allSatisfy({ $0.range(of: #"^:?-{3,}:?$"#, options: .regularExpression) != nil }), !cells(lines[i]).isEmpty {
                flush(); closeList()
                let header = cells(line), headerLine = i; i += 1
                output.append("<table><thead>" + positioned("<tr>" + header.map { "<th>\(inline($0))</th>" }.joined() + "</tr>", line: headerLine) + "</thead><tbody>")
                while i < lines.count && lines[i].contains("|") && !lines[i].isEmpty {
                    output.append(positioned("<tr>" + cells(lines[i]).map { "<td>\(inline($0))</td>" }.joined() + "</tr>", line: i + 1)); i += 1
                }
                output.append("</tbody></table>"); continue
            }
            if let match = trimmed.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
                flush(); closeList(); let level = trimmed[match].filter { $0 == "#" }.count
                output.append(positioned("<h\(level)>\(inline(String(trimmed[match.upperBound...])))</h\(level)>", line: i)); continue
            }
            if trimmed.range(of: #"^(\*\s*){3,}$|^(-\s*){3,}$|^(_\s*){3,}$"#, options: .regularExpression) != nil { flush(); closeList(); output.append(positioned("<hr>", line: i)); continue }
            if trimmed.hasPrefix(">") { flush(); closeList(); output.append(positioned("<blockquote>\(inline(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)))</blockquote>", line: i)); continue }
            if let range = trimmed.range(of: #"^([-+*]|\d+[.)])\s+"#, options: .regularExpression) {
                flush(); let kind = trimmed.first?.isNumber == true ? "ol" : "ul"
                if list != kind { closeList(); output.append("<\(kind)>"); list = kind }
                var item = String(trimmed[range.upperBound...])
                var prefix = ""
                if item.hasPrefix("[ ] ") || item.lowercased().hasPrefix("[x] ") { prefix = item.hasPrefix("[ ] ") ? "☐ " : "☑ "; item = String(item.dropFirst(4)) }
                output.append(positioned("<li>\(prefix)\(inline(item))</li>", line: i)); continue
            }
            closeList(); paragraph.append((line, i))
        }
        flush(); closeList()
        if fence != nil { output.append(positioned("<pre><code>\(escape(code.joined(separator: "\n")))</code></pre>", line: codeStart, end: lines.count)) }
        return output.joined(separator: "\n")
    }
    public static func page(_ source: String, fontSize: Double = 16) -> String {
        """
        <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'none'; img-src 'none'; base-uri 'none'; form-action 'none'">
        <style>
        :root{color-scheme:light dark;--bg:#fbfdf9;--fg:#28362d;--muted:#6c7c70;--accent:#397558;--line:#dce7dc;--code:#eef4ed}
        @media(prefers-color-scheme:dark){:root{--bg:#1d2521;--fg:#dfebe0;--muted:#a1b4a5;--accent:#a0d3ab;--line:#3b4a40;--code:#28332c}}
        html[data-theme="dark"]{color-scheme:dark;--bg:#1d2521;--fg:#dfebe0;--muted:#a1b4a5;--accent:#a0d3ab;--line:#3b4a40;--code:#28332c}
        html[data-theme="light"]{color-scheme:light;--bg:#fbfdf9;--fg:#28362d;--muted:#6c7c70;--accent:#397558;--line:#dce7dc;--code:#eef4ed}
        body{margin:0;background:var(--bg);color:var(--fg);font:\(min(40, max(10, fontSize)))px/1.75 -apple-system,BlinkMacSystemFont,sans-serif;padding:32px 36px;overflow-wrap:anywhere}
        main{max-width:800px;margin:auto}h1,h2,h3{line-height:1.35;letter-spacing:-.025em}h1{font-size:2em}h2{border-bottom:1px solid var(--line);padding-bottom:.3em}
        a{color:var(--accent)}code{font: .88em/1.6 ui-monospace,Menlo,monospace;background:var(--code);padding:2px 5px;border-radius:4px}pre{background:var(--code);padding:16px;border-radius:10px;overflow:auto}pre code{padding:0;white-space:pre}
        blockquote{margin:16px 0;padding:8px 18px;border-left:3px solid var(--accent);color:var(--muted);background:var(--code);border-radius:0 8px 8px 0}
        table{border-collapse:collapse;display:block;overflow:auto}td,th{border:1px solid var(--line);padding:8px 14px}th{background:var(--code)}hr{border:0;border-top:1px solid var(--line);margin:24px 0}.image{color:var(--muted)}
        </style></head><body><main>\(render(source, sourcePositions: true))</main></body></html>
        """
    }
}
