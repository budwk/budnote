import Foundation

public enum TextSearch {
    /// Literal UTF-16 ranges, suitable for NSTextView and NSString replacements.
    public static func ranges(in text: String, query: String, caseSensitive: Bool = false) -> [NSRange] {
        guard !query.isEmpty else { return [] }
        let source = text as NSString
        var ranges: [NSRange] = [], start = 0
        while start < source.length {
            let range = source.range(of: query, options: caseSensitive ? [] : [.caseInsensitive], range: NSRange(location: start, length: source.length - start))
            guard range.location != NSNotFound, range.length > 0 else { break }
            ranges.append(range); start = NSMaxRange(range)
        }
        return ranges
    }
}
