import AppKit

let args = CommandLine.arguments
let outDir = args.count > 1 ? args[1] : "appstore/screenshots"
let W: CGFloat = 2880
let H: CGFloat = 1800

try FileManager.default.createDirectory(atPath: outDir + "/zh-Hans", withIntermediateDirectories: true)
try FileManager.default.createDirectory(atPath: outDir + "/en-US", withIntermediateDirectories: true)

func makeCanvas(draw: (CGContext) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(W),
        pixelsHigh: Int(H),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    draw(ctx.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ rep: NSBitmapImageRep, to path: String) throws {
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: URL(fileURLWithPath: path))
}

func drawBackground(_ cg: CGContext, dark: Bool = true) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let colors: [CGColor] = dark
        ? [
            NSColor(srgbRed: 0.08, green: 0.16, blue: 0.13, alpha: 1).cgColor,
            NSColor(srgbRed: 0.13, green: 0.27, blue: 0.21, alpha: 1).cgColor,
            NSColor(srgbRed: 0.07, green: 0.12, blue: 0.10, alpha: 1).cgColor
          ]
        : [
            NSColor(srgbRed: 0.91, green: 0.96, blue: 0.92, alpha: 1).cgColor,
            NSColor(srgbRed: 0.83, green: 0.92, blue: 0.86, alpha: 1).cgColor,
            NSColor(srgbRed: 0.94, green: 0.97, blue: 0.95, alpha: 1).cgColor
          ]
    let locs: [CGFloat] = [0.0, 0.52, 1.0]
    let grad = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locs)!
    cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: W, y: 0), options: [])

    // Subtle decorative glow circles
    cg.saveGState()
    let glowColor = dark
        ? NSColor(srgbRed: 0.38, green: 0.72, blue: 0.53, alpha: 0.14).cgColor
        : NSColor(srgbRed: 0.20, green: 0.52, blue: 0.36, alpha: 0.10).cgColor
    let glowGrad = CGGradient(colorsSpace: space, colors: [glowColor, NSColor.clear.cgColor] as CFArray, locations: [0, 1])!
    cg.drawRadialGradient(glowGrad, startCenter: CGPoint(x: W * 0.2, y: H * 0.85), startRadius: 10, endCenter: CGPoint(x: W * 0.2, y: H * 0.85), endRadius: 900, options: [])
    cg.drawRadialGradient(glowGrad, startCenter: CGPoint(x: W * 0.82, y: H * 0.25), startRadius: 10, endCenter: CGPoint(x: W * 0.82, y: H * 0.25), endRadius: 850, options: [])
    cg.restoreGState()
}

func drawLeafIcon(in rect: NSRect) {
    NSGraphicsContext.current?.saveGraphicsState()
    let t = NSAffineTransform()
    t.translateX(by: rect.minX, yBy: rect.minY)
    t.scale(by: rect.width / 1024.0)
    t.concat()

    NSColor(srgbRed: 0.15, green: 0.33, blue: 0.26, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 200, yRadius: 200).fill()
    NSColor(srgbRed: 0.96, green: 0.97, blue: 0.91, alpha: 1).setFill()
    let leaf = NSBezierPath()
    leaf.move(to: NSPoint(x: 316, y: 296))
    leaf.curve(to: NSPoint(x: 735, y: 740), controlPoint1: NSPoint(x: 215, y: 607), controlPoint2: NSPoint(x: 423, y: 783))
    leaf.curve(to: NSPoint(x: 316, y: 296), controlPoint1: NSPoint(x: 809, y: 425), controlPoint2: NSPoint(x: 596, y: 252))
    leaf.fill()
    NSColor(srgbRed: 0.15, green: 0.33, blue: 0.26, alpha: 1).setStroke()
    let vein = NSBezierPath(); vein.lineWidth = 34; vein.lineCapStyle = .round
    vein.move(to: NSPoint(x: 285, y: 273)); vein.line(to: NSPoint(x: 584, y: 579)); vein.stroke()
    NSGraphicsContext.current?.restoreGraphicsState()
}

func drawHeader(badge: String, title: String, subtitle: String, dark: Bool = true) {
    let badgeFont = NSFont.systemFont(ofSize: 28, weight: .semibold)
    let badgeTextColor = dark ? NSColor(srgbRed: 0.68, green: 0.91, blue: 0.74, alpha: 1) : NSColor(srgbRed: 0.15, green: 0.38, blue: 0.27, alpha: 1)
    let badgeAttr: [NSAttributedString.Key: Any] = [.font: badgeFont, .foregroundColor: badgeTextColor]
    let badgeSize = (badge as NSString).size(withAttributes: badgeAttr)
    let pillW = badgeSize.width + 76
    let pillH: CGFloat = 54
    let pillRect = NSRect(x: (W - pillW) / 2, y: H - 140, width: pillW, height: pillH)

    let pillBg = dark ? NSColor(srgbRed: 0.18, green: 0.36, blue: 0.28, alpha: 0.85) : NSColor(srgbRed: 0.82, green: 0.92, blue: 0.85, alpha: 0.95)
    pillBg.setFill()
    let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: pillH / 2, yRadius: pillH / 2)
    pillPath.fill()
    let pillBorder = dark ? NSColor(srgbRed: 0.45, green: 0.75, blue: 0.56, alpha: 0.45) : NSColor(srgbRed: 0.22, green: 0.48, blue: 0.35, alpha: 0.3)
    pillBorder.setStroke()
    pillPath.lineWidth = 2
    pillPath.stroke()

    drawLeafIcon(in: NSRect(x: pillRect.minX + 14, y: pillRect.minY + 7, width: 40, height: 40))
    (badge as NSString).draw(at: NSPoint(x: pillRect.minX + 60, y: pillRect.minY + (pillH - badgeSize.height) / 2), withAttributes: badgeAttr)

    let pStyle = NSMutableParagraphStyle(); pStyle.alignment = .center
    let titleColor = dark ? NSColor.white : NSColor(srgbRed: 0.09, green: 0.16, blue: 0.12, alpha: 1)
    let titleAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 72, weight: .bold),
        .foregroundColor: titleColor,
        .paragraphStyle: pStyle
    ]
    (title as NSString).draw(in: NSRect(x: 120, y: H - 255, width: W - 240, height: 95), withAttributes: titleAttr)

    let subColor = dark ? NSColor(srgbRed: 0.78, green: 0.86, blue: 0.81, alpha: 1) : NSColor(srgbRed: 0.28, green: 0.38, blue: 0.32, alpha: 1)
    let subAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 36, weight: .regular),
        .foregroundColor: subColor,
        .paragraphStyle: pStyle
    ]
    (subtitle as NSString).draw(in: NSRect(x: 160, y: H - 325, width: W - 320, height: 56), withAttributes: subAttr)
}

func drawMacWindowShell(rect: NSRect, darkWindow: Bool, tabs: [(String, Bool)], showModeSegment: Int? = nil, statusText: String) {
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.48)
    shadow.shadowBlurRadius = 60
    shadow.shadowOffset = NSSize(width: 0, height: -22)
    shadow.set()

    let winBg = darkWindow ? NSColor(srgbRed: 0.114, green: 0.145, blue: 0.129, alpha: 1) : NSColor(srgbRed: 0.984, green: 0.992, blue: 0.977, alpha: 1)
    winBg.setFill()
    let winPath = NSBezierPath(roundedRect: rect, xRadius: 24, yRadius: 24)
    winPath.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    // Clip to window rounded rect
    NSGraphicsContext.current?.saveGraphicsState()
    winPath.addClip()

    // Titlebar / Toolbar (top 76px)
    let titlebarH: CGFloat = 76
    let titlebarRect = NSRect(x: rect.minX, y: rect.maxY - titlebarH, width: rect.width, height: titlebarH)
    let titlebarBg = darkWindow ? NSColor(srgbRed: 0.14, green: 0.18, blue: 0.16, alpha: 1) : NSColor(srgbRed: 0.94, green: 0.96, blue: 0.93, alpha: 1)
    titlebarBg.setFill()
    titlebarRect.fill()

    // Traffic lights
    let trafficColors = [
        NSColor(srgbRed: 1.0, green: 0.37, blue: 0.34, alpha: 1),
        NSColor(srgbRed: 1.0, green: 0.74, blue: 0.18, alpha: 1),
        NSColor(srgbRed: 0.16, green: 0.78, blue: 0.25, alpha: 1)
    ]
    for (i, c) in trafficColors.enumerated() {
        c.setFill()
        let cx = rect.minX + 34 + CGFloat(i) * 34
        let cy = titlebarRect.midY - 11
        NSBezierPath(ovalIn: NSRect(x: cx, y: cy, width: 22, height: 22)).fill()
    }

    // Tabs
    var tabX = rect.minX + 156
    for (title, active) in tabs {
        let font = NSFont.systemFont(ofSize: 22, weight: active ? .semibold : .regular)
        let textColor = darkWindow
            ? (active ? NSColor.white : NSColor(calibratedWhite: 0.68, alpha: 1))
            : (active ? NSColor(calibratedWhite: 0.12, alpha: 1) : NSColor(calibratedWhite: 0.45, alpha: 1))
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        let tSize = (title as NSString).size(withAttributes: attr)
        let tabW = max(180, tSize.width + 68)
        let tabRect = NSRect(x: tabX, y: titlebarRect.minY + 13, width: tabW, height: 50)
        let tabFill = darkWindow
            ? NSColor(calibratedWhite: 1.0, alpha: active ? 0.14 : 0.05)
            : NSColor(calibratedWhite: 0.0, alpha: active ? 0.10 : 0.04)
        tabFill.setFill()
        NSBezierPath(roundedRect: tabRect, xRadius: 12, yRadius: 12).fill()
        if active {
            let accent = darkWindow ? NSColor(srgbRed: 0.63, green: 0.83, blue: 0.67, alpha: 1) : NSColor(srgbRed: 0.22, green: 0.46, blue: 0.34, alpha: 1)
            accent.setFill()
            NSBezierPath(roundedRect: NSRect(x: tabRect.minX + 14, y: tabRect.minY + 3, width: tabRect.width - 28, height: 4), xRadius: 2, yRadius: 2).fill()
        }
        (title as NSString).draw(at: NSPoint(x: tabRect.minX + 20, y: tabRect.minY + (50 - tSize.height) / 2), withAttributes: attr)
        let closeAttr: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 20, weight: .medium), .foregroundColor: textColor.withAlphaComponent(0.65)]
        ("×" as NSString).draw(at: NSPoint(x: tabRect.maxX - 32, y: tabRect.minY + 11), withAttributes: closeAttr)
        tabX += tabW + 12
    }

    // Markdown Mode Segmented Control if requested
    if let selectedSeg = showModeSegment {
        let segW: CGFloat = 198
        let segH: CGFloat = 46
        let segRect = NSRect(x: rect.maxX - segW - 28, y: titlebarRect.minY + 15, width: segW, height: segH)
        let segBg = darkWindow ? NSColor(calibratedWhite: 1, alpha: 0.08) : NSColor(calibratedWhite: 0, alpha: 0.06)
        segBg.setFill()
        NSBezierPath(roundedRect: segRect, xRadius: 10, yRadius: 10).fill()
        let symbols = ["✎", "◧", "▤"]
        for i in 0..<3 {
            let cellRect = NSRect(x: segRect.minX + CGFloat(i) * (segW / 3), y: segRect.minY, width: segW / 3, height: segH)
            if i == selectedSeg {
                let selBg = darkWindow ? NSColor(srgbRed: 0.26, green: 0.48, blue: 0.37, alpha: 1) : NSColor.white
                selBg.setFill()
                NSBezierPath(roundedRect: cellRect.insetBy(dx: 4, dy: 4), xRadius: 8, yRadius: 8).fill()
            }
            let p = NSMutableParagraphStyle(); p.alignment = .center
            let c = darkWindow ? NSColor.white : NSColor(calibratedWhite: 0.15, alpha: 1)
            (symbols[i] as NSString).draw(in: NSRect(x: cellRect.minX, y: cellRect.minY + 7, width: cellRect.width, height: 32), withAttributes: [
                .font: NSFont.systemFont(ofSize: 23, weight: .semibold),
                .foregroundColor: c,
                .paragraphStyle: p
            ])
        }
    }

    // Bottom status bar (48px)
    let statusH: CGFloat = 48
    let statusRect = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: statusH)
    let statusBg = darkWindow ? NSColor(srgbRed: 0.10, green: 0.13, blue: 0.115, alpha: 1) : NSColor(srgbRed: 0.95, green: 0.97, blue: 0.94, alpha: 1)
    statusBg.setFill()
    statusRect.fill()

    let dividerColor = darkWindow ? NSColor(calibratedWhite: 1, alpha: 0.08) : NSColor(calibratedWhite: 0, alpha: 0.08)
    dividerColor.setFill()
    NSRect(x: rect.minX, y: titlebarRect.minY, width: rect.width, height: 1.5).fill()
    NSRect(x: rect.minX, y: statusRect.maxY, width: rect.width, height: 1.5).fill()

    let statusColor = darkWindow ? NSColor(calibratedWhite: 0.65, alpha: 1) : NSColor(calibratedWhite: 0.42, alpha: 1)
    (statusText as NSString).draw(at: NSPoint(x: rect.minX + 24, y: statusRect.minY + 11), withAttributes: [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 20, weight: .regular),
        .foregroundColor: statusColor
    ])

    NSGraphicsContext.current?.restoreGraphicsState()

    // Window outer border
    let borderColor = darkWindow ? NSColor(calibratedWhite: 1, alpha: 0.16) : NSColor(calibratedWhite: 0, alpha: 0.14)
    borderColor.setStroke()
    winPath.lineWidth = 2
    winPath.stroke()
}

enum TokKind { case plain, heading, keyword, string, comment, number, accent }

func drawCodePane(rect: NSRect, dark: Bool, startLine: Int = 1, lines: [[(String, TokKind)]]) {
    let gutterW: CGFloat = 76
    let gutterBg = dark ? NSColor(srgbRed: 0.114, green: 0.145, blue: 0.129, alpha: 1) : NSColor(srgbRed: 0.984, green: 0.992, blue: 0.977, alpha: 1)
    gutterBg.setFill()
    NSRect(x: rect.minX, y: rect.minY, width: gutterW, height: rect.height).fill()

    let lineH: CGFloat = 46
    let font = NSFont.monospacedSystemFont(ofSize: 25, weight: .regular)
    let boldFont = NSFont.monospacedSystemFont(ofSize: 25, weight: .bold)
    let numFont = NSFont.monospacedDigitSystemFont(ofSize: 21, weight: .regular)
    let numColor = dark ? NSColor(calibratedWhite: 0.46, alpha: 1) : NSColor(calibratedWhite: 0.55, alpha: 1)

    for (idx, segs) in lines.enumerated() {
        let y = rect.maxY - 32 - CGFloat(idx + 1) * lineH
        if y < rect.minY + 10 { break }

        let lineNum = "\(startLine + idx)" as NSString
        let numSize = lineNum.size(withAttributes: [.font: numFont])
        lineNum.draw(at: NSPoint(x: rect.minX + gutterW - numSize.width - 18, y: y + 3), withAttributes: [
            .font: numFont, .foregroundColor: numColor
        ])

        var x = rect.minX + gutterW + 18
        for (text, kind) in segs {
            let color: NSColor
            var useFont = font
            switch kind {
            case .plain:
                color = dark ? NSColor(calibratedWhite: 0.93, alpha: 1) : NSColor(calibratedWhite: 0.14, alpha: 1)
            case .heading, .accent:
                color = dark ? NSColor(srgbRed: 0.63, green: 0.83, blue: 0.67, alpha: 1) : NSColor(srgbRed: 0.18, green: 0.44, blue: 0.31, alpha: 1)
                if kind == .heading { useFont = boldFont }
            case .keyword:
                color = dark ? NSColor(srgbRed: 0.82, green: 0.58, blue: 0.98, alpha: 1) : NSColor(srgbRed: 0.58, green: 0.18, blue: 0.78, alpha: 1)
            case .string:
                color = dark ? NSColor(srgbRed: 0.63, green: 0.83, blue: 0.67, alpha: 1) : NSColor(srgbRed: 0.19, green: 0.47, blue: 0.33, alpha: 1)
            case .comment:
                color = dark ? NSColor(calibratedWhite: 0.52, alpha: 1) : NSColor(calibratedWhite: 0.48, alpha: 1)
            case .number:
                color = dark ? NSColor(srgbRed: 0.98, green: 0.68, blue: 0.32, alpha: 1) : NSColor(srgbRed: 0.82, green: 0.42, blue: 0.08, alpha: 1)
            }
            let attr: [NSAttributedString.Key: Any] = [.font: useFont, .foregroundColor: color]
            (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attr)
            x += (text as NSString).size(withAttributes: attr).width
        }
    }
}

// ==========================================
// Slide 1: Markdown Live Split Preview
// ==========================================
func generateSlide1(zh: Bool) throws {
    let rep = makeCanvas { cg in
        drawBackground(cg, dark: true)
        drawHeader(
            badge: zh ? "BudNote · 原生 macOS 文本与 Markdown 编辑器" : "BudNote · Native macOS Text & Markdown Editor",
            title: zh ? "轻巧、清新的 Markdown 实时同步预览" : "Clean, Scroll-Synced Markdown Live Preview",
            subtitle: zh ? "Swift + AppKit 原生构建 · 编辑 / 双栏预览 / 阅读三模式 · 按源码行精确同步滚动" : "Built with Swift & AppKit · Edit, Split Preview & Read Modes · Source-Line Scroll Sync"
        )

        let winRect = NSRect(x: 180, y: 110, width: W - 360, height: 1260)
        drawMacWindowShell(
            rect: winRect,
            darkWindow: true,
            tabs: zh
                ? [("README.md", true), ("清晨笔记.md - 已编辑", false), ("ReleaseNotes.txt", false)]
                : [("README.md", true), ("MorningNotes.md - Edited", false), ("ReleaseNotes.txt", false)],
            showModeSegment: 1,
            statusText: zh
                ? "第 18 行，1 列    ·    1,428 字符    ·    UTF-8    ·    LF"
                : "Ln 18, Col 1    ·    1,428 chars    ·    UTF-8    ·    LF"
        )

        let bodyRect = NSRect(x: winRect.minX, y: winRect.minY + 48, width: winRect.width, height: winRect.height - 76 - 48)
        let leftRect = NSRect(x: bodyRect.minX, y: bodyRect.minY, width: bodyRect.width * 0.5, height: bodyRect.height)
        let rightRect = NSRect(x: bodyRect.midX, y: bodyRect.minY, width: bodyRect.width * 0.5, height: bodyRect.height)

        // Split divider
        NSColor(calibratedWhite: 1, alpha: 0.1).setFill()
        NSRect(x: bodyRect.midX - 1, y: bodyRect.minY, width: 2, height: bodyRect.height).fill()

        let mdLines: [[(String, TokKind)]] = zh ? [
            [("# BudNote 🌿", .heading)],
            [("", .plain)],
            [("轻巧、清新、随系统明暗主题变化的 ", .plain), ("**macOS 原生文本编辑器**", .keyword), ("。", .plain)],
            [("使用 ", .plain), ("`Swift + AppKit + WebKit`", .string), ("，无第三方依赖。", .plain)],
            [("", .plain)],
            [("## 核心优势", .heading)],
            [("", .plain)],
            [("- [x] ", .accent), ("单行紧凑多标签，支持触控板横向滑动", .plain)],
            [("- [x] ", .accent), ("Markdown 编辑、双栏实时预览与阅读模式", .plain)],
            [("- [x] ", .accent), ("UTF-8 / UTF-16 / GB18030 编码无损往返", .plain)],
            [("- [x] ", .accent), ("Swift / Python / JS / HTML 等轻量语法高亮", .plain)],
            [("", .plain)],
            [("## 快速构建", .heading)],
            [("", .plain)],
            [("```bash", .comment)],
            [("./build.sh && open dist/BudNote.app", .string)],
            [("```", .comment)],
            [("", .plain)],
            [("> 专注文字本身，启动即写，零内存负担。", .comment)]
        ] : [
            [("# BudNote 🌿", .heading)],
            [("", .plain)],
            [("A lightweight, serene ", .plain), ("**native macOS text editor**", .keyword), (".", .plain)],
            [("Built with ", .plain), ("`Swift + AppKit + WebKit`", .string), (" — zero dependencies.", .plain)],
            [("", .plain)],
            [("## Highlights", .heading)],
            [("", .plain)],
            [("- [x] ", .accent), ("Compact single-row tabs with horizontal scroll", .plain)],
            [("- [x] ", .accent), ("Markdown Edit, Split Preview & Read modes", .plain)],
            [("- [x] ", .accent), ("Lossless UTF-8, UTF-16 & GB18030 encodings", .plain)],
            [("- [x] ", .accent), ("Fast syntax highlighting for code & configs", .plain)],
            [("", .plain)],
            [("## Quick Build", .heading)],
            [("", .plain)],
            [("```bash", .comment)],
            [("./build.sh && open dist/BudNote.app", .string)],
            [("```", .comment)],
            [("", .plain)],
            [("> Stay focused on your words with instant native speed.", .comment)]
        ]
        drawCodePane(rect: leftRect, dark: true, lines: mdLines)

        // Rendered Markdown Preview on Right
        let px = rightRect.minX + 54
        var py = rightRect.maxY - 95

        ( "BudNote 🌿" as NSString).draw(at: NSPoint(x: px, y: py), withAttributes: [
            .font: NSFont.systemFont(ofSize: 44, weight: .bold),
            .foregroundColor: NSColor.white
        ])
        py -= 22
        NSColor(calibratedWhite: 1, alpha: 0.12).setFill()
        NSRect(x: px, y: py, width: rightRect.width - 108, height: 2).fill()

        py -= 62
        let pText = zh
            ? "轻巧、清新、随系统明暗主题变化的 macOS 原生文本编辑器。使用 Swift + AppKit + WebKit，无第三方依赖。"
            : "A lightweight, serene native macOS text editor. Built with Swift + AppKit + WebKit — zero dependencies."
        (pText as NSString).draw(in: NSRect(x: px, y: py - 40, width: rightRect.width - 108, height: 85), withAttributes: [
            .font: NSFont.systemFont(ofSize: 25, weight: .regular),
            .foregroundColor: NSColor(calibratedWhite: 0.88, alpha: 1)
        ])

        py -= 95
        ((zh ? "核心优势" : "Highlights") as NSString).draw(at: NSPoint(x: px, y: py), withAttributes: [
            .font: NSFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: NSColor(srgbRed: 0.63, green: 0.83, blue: 0.67, alpha: 1)
        ])

        let items = zh ? [
            "☑  单行紧凑多标签，支持触控板横向滑动",
            "☑  Markdown 编辑、双栏实时预览与阅读模式",
            "☑  UTF-8 / UTF-16 / GB18030 编码无损往返",
            "☑  Swift / Python / JS / HTML 等轻量语法高亮"
        ] : [
            "☑  Compact single-row tabs with horizontal scroll",
            "☑  Markdown Edit, Split Preview & Read modes",
            "☑  Lossless UTF-8, UTF-16 & GB18030 encodings",
            "☑  Fast syntax highlighting for code & configs"
        ]
        for item in items {
            py -= 50
            (item as NSString).draw(at: NSPoint(x: px + 8, y: py), withAttributes: [
                .font: NSFont.systemFont(ofSize: 24, weight: .regular),
                .foregroundColor: NSColor(calibratedWhite: 0.90, alpha: 1)
            ])
        }

        py -= 74
        ((zh ? "快速构建" : "Quick Build") as NSString).draw(at: NSPoint(x: px, y: py), withAttributes: [
            .font: NSFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: NSColor(srgbRed: 0.63, green: 0.83, blue: 0.67, alpha: 1)
        ])

        py -= 92
        let codeBox = NSRect(x: px, y: py, width: rightRect.width - 108, height: 74)
        NSColor(srgbRed: 0.08, green: 0.11, blue: 0.095, alpha: 1).setFill()
        NSBezierPath(roundedRect: codeBox, xRadius: 12, yRadius: 12).fill()
        ("./build.sh && open dist/BudNote.app" as NSString).draw(at: NSPoint(x: px + 24, y: py + 21), withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 23, weight: .regular),
            .foregroundColor: NSColor(srgbRed: 0.68, green: 0.90, blue: 0.73, alpha: 1)
        ])

        py -= 86
        let quoteBox = NSRect(x: px, y: py, width: rightRect.width - 108, height: 60)
        NSColor(srgbRed: 0.63, green: 0.83, blue: 0.67, alpha: 1).setFill()
        NSRect(x: quoteBox.minX, y: quoteBox.minY, width: 6, height: quoteBox.height).fill()
        let qStr = zh ? "专注文字本身，启动即写，零内存负担。" : "Stay focused on your words with instant native speed."
        (qStr as NSString).draw(at: NSPoint(x: px + 24, y: py + 14), withAttributes: [
            .font: NSFont.systemFont(ofSize: 24, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.72, alpha: 1)
        ])
    }
    try save(rep, to: "\(outDir)/\(zh ? "zh-Hans" : "en-US")/01_markdown_preview.png")
}

// ==========================================
// Slide 2: Syntax Highlighting & Multi-Tabs + Find/Replace
// ==========================================
func generateSlide2(zh: Bool) throws {
    let rep = makeCanvas { cg in
        drawBackground(cg, dark: true)
        drawHeader(
            badge: zh ? "多语言代码高亮 · 增量查找与替换" : "Code Syntax Highlighting · Find & Replace",
            title: zh ? "紧凑多标签工作区与轻量代码高亮" : "Compact Document Tabs & Clean Code Highlighting",
            subtitle: zh ? "支持 Swift / Python / JS / HTML / JSON / Shell 等 20+ 种文本格式 · 毫秒级查找替换" : "Supports Swift, Python, JS, HTML, JSON, Shell & 20+ Plain Text Formats · Instant Find & Replace"
        )

        let winRect = NSRect(x: 180, y: 110, width: W - 360, height: 1260)
        drawMacWindowShell(
            rect: winRect,
            darkWindow: true,
            tabs: zh
                ? [("TextCodec.swift", true), ("server.py", false), ("config.json", false), ("deploy.sh - 已编辑", false)]
                : [("TextCodec.swift", true), ("server.py", false), ("config.json", false), ("deploy.sh - Edited", false)],
            showModeSegment: nil,
            statusText: zh
                ? "第 14 行，28 列    ·    2,180 字符    ·    UTF-8    ·    LF"
                : "Ln 14, Col 28    ·    2,180 chars    ·    UTF-8    ·    LF"
        )

        // Find & Replace Bar (top of body)
        let findH: CGFloat = 136
        let findRect = NSRect(x: winRect.minX + 2, y: winRect.maxY - 76 - findH, width: winRect.width - 4, height: findH)
        NSColor(srgbRed: 0.13, green: 0.17, blue: 0.15, alpha: 1).setFill()
        findRect.fill()
        NSColor(calibratedWhite: 1, alpha: 0.1).setFill()
        NSRect(x: findRect.minX, y: findRect.minY, width: findRect.width, height: 1.5).fill()

        // Search input box
        let searchBox = NSRect(x: findRect.minX + 28, y: findRect.maxY - 60, width: 520, height: 46)
        NSColor(srgbRed: 0.09, green: 0.12, blue: 0.10, alpha: 1).setFill()
        NSBezierPath(roundedRect: searchBox, xRadius: 10, yRadius: 10).fill()
        ("🔍  TextCodec" as NSString).draw(at: NSPoint(x: searchBox.minX + 16, y: searchBox.minY + 9), withAttributes: [
            .font: NSFont.systemFont(ofSize: 22, weight: .regular),
            .foregroundColor: NSColor.white
        ])

        let btns = zh ? ["上一处", "下一处", "☑ 区分大小写", "3 / 3 处匹配"] : ["Previous", "Next", "☑ Case Sensitive", "3 of 3 matches"]
        var bx = searchBox.maxX + 20
        for (idx, bTitle) in btns.enumerated() {
            let w = CGFloat((bTitle as NSString).length * 22 + 36)
            if idx < 2 {
                let bRect = NSRect(x: bx, y: searchBox.minY, width: w, height: 46)
                NSColor(calibratedWhite: 1, alpha: 0.10).setFill()
                NSBezierPath(roundedRect: bRect, xRadius: 10, yRadius: 10).fill()
            }
            (bTitle as NSString).draw(at: NSPoint(x: bx + 16, y: searchBox.minY + 9), withAttributes: [
                .font: NSFont.systemFont(ofSize: 21, weight: idx == 3 ? .semibold : .regular),
                .foregroundColor: idx == 3 ? NSColor(srgbRed: 0.63, green: 0.83, blue: 0.67, alpha: 1) : NSColor(calibratedWhite: 0.88, alpha: 1)
            ])
            bx += w + 18
        }

        // Replace row
        let repBox = NSRect(x: findRect.minX + 28, y: findRect.minY + 16, width: 520, height: 46)
        NSColor(srgbRed: 0.09, green: 0.12, blue: 0.10, alpha: 1).setFill()
        NSBezierPath(roundedRect: repBox, xRadius: 10, yRadius: 10).fill()
        ((zh ? "替换为：EncodingCodec" : "Replace with: EncodingCodec") as NSString).draw(at: NSPoint(x: repBox.minX + 16, y: repBox.minY + 9), withAttributes: [
            .font: NSFont.systemFont(ofSize: 21, weight: .regular),
            .foregroundColor: NSColor(calibratedWhite: 0.78, alpha: 1)
        ])
        let repBtns = zh ? ["替换", "全部替换"] : ["Replace", "Replace All"]
        var rbx = repBox.maxX + 20
        for rb in repBtns {
            let w: CGFloat = 150
            let bRect = NSRect(x: rbx, y: repBox.minY, width: w, height: 46)
            NSColor(calibratedWhite: 1, alpha: 0.10).setFill()
            NSBezierPath(roundedRect: bRect, xRadius: 10, yRadius: 10).fill()
            let p = NSMutableParagraphStyle(); p.alignment = .center
            (rb as NSString).draw(in: NSRect(x: bRect.minX, y: bRect.minY + 9, width: w, height: 32), withAttributes: [
                .font: NSFont.systemFont(ofSize: 21, weight: .regular),
                .foregroundColor: NSColor.white,
                .paragraphStyle: p
            ])
            rbx += w + 16
        }

        let codeRect = NSRect(x: winRect.minX + 2, y: winRect.minY + 48, width: winRect.width - 4, height: winRect.height - 76 - findH - 48)
        let swiftLines: [[(String, TokKind)]] = [
            [("import ", .keyword), ("Foundation", .plain)],
            [("", .plain)],
            [(zh ? "// 无损字符编码识别与字节级往返保存" : "// Lossless character encoding detection & byte-accurate roundtrip", .comment)],
            [("public struct ", .keyword), ("TextCodec", .heading), (": ", .plain), ("Equatable ", .plain), ("{", .plain)],
            [("    public let ", .keyword), ("encoding: String.Encoding", .plain)],
            [("    public let ", .keyword), ("hasBOM: Bool", .plain)],
            [("", .plain)],
            [("    public static let ", .keyword), ("all: [TextCodec] = [", .plain)],
            [("        TextCodec(encoding: .utf8, hasBOM: ", .plain), ("false", .keyword), ("),", .plain)],
            [("        TextCodec(encoding: .utf8, hasBOM: ", .plain), ("true", .keyword), ("),", .plain)],
            [("        TextCodec(encoding: .utf16LittleEndian, hasBOM: ", .plain), ("true", .keyword), ("),", .plain)],
            [("        TextCodec(encoding: .gb18030, hasBOM: ", .plain), ("false", .keyword), (")", .plain)],
            [("    ]", .plain)],
            [("", .plain)],
            [("    public func ", .keyword), ("encode(_ text: String) ", .plain), ("throws ", .keyword), ("-> Data {", .plain)],
            [("        let ", .keyword), ("header = ", .plain), ("\"UTF-8Lossless\"", .string), (" // ", .comment), ("256", .number)],
            [("        guard let ", .keyword), (" payload = text.data(using: encoding) ", .plain), ("else ", .keyword), ("{", .plain)],
            [("            throw ", .keyword), ("CocoaError(.fileWriteInapplicableStringEncoding)", .plain)],
            [("        }", .plain)],
            [("        return ", .keyword), ("payload", .plain)],
            [("    }", .plain)],
            [("}", .plain)]
        ]
        drawCodePane(rect: codeRect, dark: true, lines: swiftLines)
    }
    try save(rep, to: "\(outDir)/\(zh ? "zh-Hans" : "en-US")/02_code_and_tabs.png")
}

// ==========================================
// Slide 3: Adaptive Light & Dark Themes + Bilingual Settings
// ==========================================
func generateSlide3(zh: Bool) throws {
    let rep = makeCanvas { cg in
        drawBackground(cg, dark: false)
        drawHeader(
            badge: zh ? "明暗主题自适应 · 中英双语实时切换" : "Adaptive Light & Dark Themes · Bilingual UI",
            title: zh ? "随系统自然变化的清雅护眼配色" : "Soothing Meadow Light & Dark Appearance",
            subtitle: zh ? "支持跟随系统 / 浅色 / 深色三种外观 · 10–40 pt 等宽字体无级缩放 · 中英界面一键切换" : "Follow System, Light, or Dark Themes · 10–40 pt Font Zooming · Instant Chinese / English Switch",
            dark: false
        )

        // Left: Light Mode Window
        let leftWin = NSRect(x: 140, y: 120, width: 1520, height: 1220)
        drawMacWindowShell(
            rect: leftWin,
            darkWindow: false,
            tabs: zh ? [("清晨笔记.md", true), ("todo.txt", false)] : [("MorningNotes.md", true), ("todo.txt", false)],
            showModeSegment: 0,
            statusText: zh ? "第 12 行，6 列  ·  UTF-8  ·  LF" : "Ln 12, Col 6  ·  UTF-8  ·  LF"
        )
        let lightBody = NSRect(x: leftWin.minX + 2, y: leftWin.minY + 48, width: leftWin.width - 4, height: leftWin.height - 76 - 48)
        let lightLines: [[(String, TokKind)]] = zh ? [
            [("# 清晨笔记 · 浅色主题", .heading)],
            [("", .plain)],
            [("在阳光充足的日间环境中，BudNote 采用柔和的", .plain)],
            [("**草木灰白底色 (#FBFDF9)**", .keyword), (" 与深林绿点缀色，", .plain)],
            [("长时间阅读与写作依然清爽舒适，不刺眼。", .plain)],
            [("", .plain)],
            [("## 今日待办清单", .heading)],
            [("- [x] ", .accent), ("完成 Mac App Store 工程配置与沙盒签名", .plain)],
            [("- [x] ", .accent), ("支持「文件 → 重命名…」快捷操作", .plain)],
            [("- [x] ", .accent), ("支持简体中文 / English 实时切换", .plain)],
            [("- [ ] ", .accent), ("使用 ", .plain), ("`⌘ + 鼠标滚轮`", .string), (" 自由缩放字体大小", .plain)],
            [("", .plain)],
            [("> 提示：按下 ⌘, 即可随时打开偏好设置。", .comment)]
        ] : [
            [("# Morning Notes · Meadow Light", .heading)],
            [("", .plain)],
            [("During bright daylight hours, BudNote uses a warm", .plain)],
            [("**Meadow Ivory (#FBFDF9)**", .keyword), (" canvas with forest green accents,", .plain)],
            [("keeping long writing sessions crisp and comfortable.", .plain)],
            [("", .plain)],
            [("## Today's Checklist", .heading)],
            [("- [x] ", .accent), ("Mac App Store sandbox & universal build", .plain)],
            [("- [x] ", .accent), ("Quick 'File → Rename…' document command", .plain)],
            [("- [x] ", .accent), ("Instant Simplified Chinese & English switch", .plain)],
            [("- [ ] ", .accent), ("Zoom font smoothly with ", .plain), ("`⌘ + Scroll Wheel`", .string)],
            [("", .plain)],
            [("> Tip: Press ⌘, anytime to customize preferences.", .comment)]
        ]
        drawCodePane(rect: lightBody, dark: false, lines: lightLines)

        // Right: Dark Mode Window + Floating Settings Card
        let rightWin = NSRect(x: 1320, y: 80, width: 1420, height: 1120)
        drawMacWindowShell(
            rect: rightWin,
            darkWindow: true,
            tabs: zh ? [("app.py", true), ("notes.md", false)] : [("app.py", true), ("notes.md", false)],
            showModeSegment: nil,
            statusText: zh ? "第 9 行，1 列  ·  GB18030  ·  CRLF" : "Ln 9, Col 1  ·  GB18030  ·  CRLF"
        )
        let darkBody = NSRect(x: rightWin.minX + 2, y: rightWin.minY + 48, width: rightWin.width - 4, height: rightWin.height - 76 - 48)
        let pyLines: [[(String, TokKind)]] = [
            [(zh ? "# 深色护眼模式 (#1D2521)" : "# Meadow Dark Theme (#1D2521)", .comment)],
            [("def ", .keyword), ("render_document", .heading), ("(path: str, encoding=", .plain), ("\"utf-8\"", .string), ("):", .plain)],
            [("    with ", .keyword), ("open(path, mode=", .plain), ("\"r\"", .string), (", encoding=encoding) ", .plain), ("as ", .keyword), ("f:", .plain)],
            [("        content = f.read()", .plain)],
            [("    lines = len(content.splitlines())", .plain)],
            [("    return ", .keyword), ("{\"lines\": lines, \"limit\": ", .plain), ("1000000", .number), ("}", .plain)]
        ]
        drawCodePane(rect: darkBody, dark: true, lines: pyLines)

        // Settings Modal Card overlay
        let setRect = NSRect(x: 1520, y: 210, width: 1120, height: 560)
        NSGraphicsContext.current?.saveGraphicsState()
        let sh = NSShadow()
        sh.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.55)
        sh.shadowBlurRadius = 45
        sh.shadowOffset = NSSize(width: 0, height: -16)
        sh.set()
        NSColor(srgbRed: 0.16, green: 0.21, blue: 0.185, alpha: 0.98).setFill()
        let setPath = NSBezierPath(roundedRect: setRect, xRadius: 22, yRadius: 22)
        setPath.fill()
        NSGraphicsContext.current?.restoreGraphicsState()
        NSColor(srgbRed: 0.45, green: 0.72, blue: 0.54, alpha: 0.45).setStroke()
        setPath.lineWidth = 2
        setPath.stroke()

        // Settings Header
        ((zh ? "⚙️  BudNote 设置" : "⚙️  BudNote Settings") as NSString).draw(at: NSPoint(x: setRect.minX + 44, y: setRect.maxY - 76), withAttributes: [
            .font: NSFont.systemFont(ofSize: 30, weight: .bold),
            .foregroundColor: NSColor.white
        ])
        NSColor(calibratedWhite: 1, alpha: 0.12).setFill()
        NSRect(x: setRect.minX + 40, y: setRect.maxY - 98, width: setRect.width - 80, height: 1.5).fill()

        let rows: [(String, String)] = zh ? [
            ("界面语言", "   [ 简体中文 ✓ ]   [ English ]"),
            ("外观主题", "   [ 跟随系统 ✓ ]   [ 浅色 ]   [ 深色 ]"),
            ("字体大小", "   ━━━━━━●━━━━━━   15 pt  (⌘+ / ⌘- / ⌘0)"),
            ("编辑器显示", "   ☑ 自动换行        ☑ 显示行号"),
            ("多编码与操作", "   UTF-8 / UTF-16 / GB18030 · 另存为 · 重命名 · 移到")
        ] : [
            ("Language", "   [ 简体中文 ]   [ English ✓ ]"),
            ("Appearance", "   [ System ✓ ]   [ Light ]   [ Dark ]"),
            ("Font Size", "   ━━━━━━●━━━━━━   15 pt  (⌘+ / ⌘- / ⌘0)"),
            ("Editor Options", "   ☑ Word Wrap       ☑ Line Numbers"),
            ("Encodings & File", "   UTF-8 / UTF-16 / GB18030 · Save As · Rename · Move")
        ]
        for (i, (label, val)) in rows.enumerated() {
            let ry = setRect.maxY - 170 - CGFloat(i) * 78
            (label as NSString).draw(at: NSPoint(x: setRect.minX + 54, y: ry), withAttributes: [
                .font: NSFont.systemFont(ofSize: 23, weight: .semibold),
                .foregroundColor: NSColor(calibratedWhite: 0.75, alpha: 1)
            ])
            (val as NSString).draw(at: NSPoint(x: setRect.minX + 270, y: ry), withAttributes: [
                .font: NSFont.systemFont(ofSize: 23, weight: .medium),
                .foregroundColor: NSColor(srgbRed: 0.68, green: 0.90, blue: 0.74, alpha: 1)
            ])
        }
    }
    try save(rep, to: "\(outDir)/\(zh ? "zh-Hans" : "en-US")/03_themes_and_encodings.png")
}

try generateSlide1(zh: true)
try generateSlide1(zh: false)
try generateSlide2(zh: true)
try generateSlide2(zh: false)
try generateSlide3(zh: true)
try generateSlide3(zh: false)
print("Successfully generated 6 App Store promotional screenshots (2880x1800).")
