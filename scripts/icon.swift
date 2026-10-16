import AppKit
let destination = CommandLine.arguments[1]
let sizes = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for (size, scale) in sizes {
    let pixels = size * scale
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let transform = NSAffineTransform(); transform.scale(by: CGFloat(pixels) / 1024); transform.concat()
    // A flat evergreen tile with one generous, ivory bud mark.
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
    NSGraphicsContext.restoreGraphicsState()
    let suffix = scale == 2 ? "@2x" : ""
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination + "/icon_\(size)x\(size)\(suffix).png"))
}
