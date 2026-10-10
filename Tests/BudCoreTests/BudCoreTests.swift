import XCTest
@testable import BudCore

final class BudCoreTests: XCTestCase {
    func testLiteralSearchUsesUTF16AndHandlesCase() {
        let source = "🌿 Alpha\r\nalpha .*"
        XCTAssertEqual(TextSearch.ranges(in: source, query: "alpha"), [NSRange(location: 3, length: 5), NSRange(location: 10, length: 5)])
        XCTAssertEqual(TextSearch.ranges(in: source, query: "alpha", caseSensitive: true), [NSRange(location: 10, length: 5)])
        XCTAssertEqual(TextSearch.ranges(in: source, query: ".*"), [NSRange(location: 16, length: 2)])
        XCTAssertTrue(TextSearch.ranges(in: source, query: "").isEmpty)
        XCTAssertEqual(TextSearch.ranges(in: "aaaa", query: "aa").count, 2)
    }
    func testEncodingRoundTripsPreserveBytes() throws {
        let text = "清晨🌿\r\nprint('hello')\r\n"
        for codec in [TextCodec(), TextCodec(encoding: .utf8, bom: Data([0xef,0xbb,0xbf])), TextCodec(encoding: .utf16LittleEndian, bom: Data([0xff,0xfe])), TextCodec(encoding: .utf16BigEndian, bom: Data([0xfe,0xff])), TextCodec(encoding: .utf32LittleEndian, bom: Data([0xff,0xfe,0,0])), TextCodec(encoding: .utf32BigEndian, bom: Data([0,0,0xfe,0xff]))] {
            let bytes = try codec.encode(text)
            let (decoded, detected) = try TextCodec.decode(bytes)
            XCTAssertEqual(decoded, text); XCTAssertEqual(try detected.encode(decoded), bytes)
        }
    }
    func testLegacyChineseAndBinaryRejection() throws {
        let bytes = try TextCodec(encoding: .gb_18030_2000).encode("你好，世界\n")
        let (text, codec) = try TextCodec.decode(bytes)
        XCTAssertEqual(text, "你好，世界\n"); XCTAssertEqual(try codec.encode(text), bytes)
        XCTAssertThrowsError(try TextCodec.decode(Data([0,1,2,3])))
        XCTAssertThrowsError(try TextCodec.decode(Data([0xff,0xfe,0xff])))
    }
    func testMarkdownBlocks() {
        let html = Markdown.render("# 清晨\n\n**你好** 与 `code`\n\n- [x] 完成\n- [ ] 待办\n\n> 引用\n\n```py\nprint('<hello>')\n```\n\n| 名称 | 值 |\n| --- | --- |\n| a | b |")
        for fragment in ["<h1>清晨</h1>", "<strong>你好</strong>", "<code>code</code>", "☑ 完成", "☐ 待办", "<blockquote>引用</blockquote>", "&lt;hello&gt;", "<table>"] { XCTAssertTrue(html.contains(fragment), fragment) }
    }
    func testPreviewEscapesHTMLAndDangerousLinks() {
        let html = Markdown.render("<script>alert(1)</script>\n\n[run](javascript:alert) ![track](https://evil.example/pixel)\n\n`**literal**` [web](https://example.com?q=1&x=2)")
        XCTAssertFalse(html.contains("<script>")); XCTAssertFalse(html.contains("href='javascript:")); XCTAssertFalse(html.contains("<img"))
        XCTAssertTrue(html.contains("<code>**literal**</code>")); XCTAssertTrue(html.contains("href='https://example.com?q=1&amp;x=2'"))
        XCTAssertTrue(Markdown.page("hello").contains("script-src 'none'"))
    }
    func testSyntaxStringsAndCommentsDoNotOverlap() {
        let source = "class Hello { String s = \"// not a comment\"; // \"comment\"\n int n = 42; }"
        let tokens = Syntax.tokens(source, language: "java")
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && (source as NSString).substring(with: $0.range) == "class" })
        XCTAssertTrue(tokens.contains { $0.kind == .string && (source as NSString).substring(with: $0.range) == "\"// not a comment\"" })
        XCTAssertTrue(tokens.contains { $0.kind == .comment })
        for (i, token) in tokens.enumerated() { for other in tokens.dropFirst(i + 1) { XCTAssertEqual(NSIntersectionRange(token.range, other.range).length, 0) } }
        XCTAssertTrue(Syntax.tokens("# comment\nprint('hi')", language: "py").contains { $0.kind == .comment })
        XCTAssertTrue(Syntax.tokens("<!-- hi -->\n<h1 title=\"hey\">", language: "html").contains { $0.kind == .tag })
    }
}
