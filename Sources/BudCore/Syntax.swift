import Foundation

public enum Syntax {
    public struct Token: Equatable { public let range: NSRange; public let kind: Kind }
    public enum Kind { case comment, string, keyword, number, tag, heading }
    public static func tokens(_ source: String, language: String) -> [Token] {
        let lang = language.lowercased(), full = NSRange(location: 0, length: (source as NSString).length)
        var patterns: [(String, Kind)]
        switch lang {
        case "md", "markdown":
            patterns = [(#"(?m)^#{1,6}\s+.*$"#, .heading), (#"(?s)```.*?```|~~~.*?~~~|`[^`\n]+`"#, .string), (#"\*\*[^*]+\*\*|\[[^\]]+\]\([^)]+\)"#, .keyword)]
        case "html", "htm", "xml", "svg":
            patterns = [(#"(?s)<!--.*?-->"#, .comment), (#"\"[^\"]*\"|'[^']*'"#, .string), (#"</?[A-Za-z][\w:-]*|/?>"#, .tag)]
        case "py", "python":
            patterns = [(#"(?s)\"\"\".*?\"\"\"|'''.*?'''|\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'|(?m:#.*$)"#, .string),
                        (#"\b(?:def|class|if|elif|else|for|while|return|import|from|as|try|except|finally|raise|with|yield|lambda|pass|break|continue|True|False|None|and|or|not|in|is|async|await|global|nonlocal|assert|del)\b"#, .keyword), (#"\b\d+(?:\.\d+)?\b"#, .number)]
        case "java", "js", "ts", "c", "h", "cpp", "swift", "css", "json", "sh", "rb", "go", "rs":
            patterns = [(#"(?s:/\*.*?\*/)|(?m://[^\n\r]*)|\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`"#, .string),
                        (#"\b(?:public|private|protected|static|final|class|interface|extends|implements|new|return|void|int|double|boolean|char|long|float|short|byte|if|else|switch|case|default|for|while|do|break|continue|try|catch|finally|throw|throws|import|package|this|super|true|false|null|var|let|const|function|async|await|func|struct|enum|guard|nil|self|in|as|override|init)\b"#, .keyword), (#"\b(?:0x[\da-fA-F]+|\d+(?:\.\d+)?)\b"#, .number)]
        default: return []
        }
        var result: [Token] = []
        var occupied = IndexSet()
        // The first pattern lexes comments and strings together, so quote markers in comments
        // or comment markers inside strings cannot override each other.
        for (pattern, defaultKind) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: source, range: full) {
                let indices = match.range.location..<NSMaxRange(match.range)
                guard occupied.count(in: indices) == 0 else { continue }
                let fragment = (source as NSString).substring(with: match.range)
                let kind: Kind = fragment.hasPrefix("//") || fragment.hasPrefix("/*") || fragment.hasPrefix("<!--") || (["py", "python"].contains(lang) && fragment.hasPrefix("#")) ? .comment : defaultKind
                result.append(Token(range: match.range, kind: kind)); occupied.insert(integersIn: indices)
            }
        }
        return result
    }
}
