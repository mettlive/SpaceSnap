import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func bolt(in card: NSRect) -> NSBezierPath {
    let points: [(CGFloat, CGFloat)] = [
        (0.58, 0.86), (0.30, 0.45), (0.49, 0.45),
        (0.42, 0.14), (0.71, 0.56), (0.52, 0.56),
    ]
    let path = NSBezierPath()
    for (index, point) in points.enumerated() {
        let location = NSPoint(x: card.minX + card.width * point.0, y: card.minY + card.height * point.1)
        if index == 0 { path.move(to: location) } else { path.line(to: location) }
    }
    path.close()
    path.lineJoinStyle = .round
    return path
}

func drawIcon() {
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    NSGradient(starting: color(0x4F7BFF), ending: color(0x7A3FE4))?.draw(in: squircle, angle: -55)
    NSGradient(starting: color(0xFFFFFF, alpha: 0.18), ending: color(0xFFFFFF, alpha: 0))?
        .draw(in: squircle, angle: -90)

    let backCard = NSRect(x: 232, y: 440, width: 400, height: 280)
    color(0xFFFFFF, alpha: 0.32).setFill()
    NSBezierPath(roundedRect: backCard, xRadius: 52, yRadius: 52).fill()

    let frontCard = NSRect(x: 392, y: 304, width: 400, height: 280)
    let frontPath = NSBezierPath(roundedRect: frontCard, xRadius: 52, yRadius: 52)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x1B0F5C, alpha: 0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.shadowBlurRadius = 36
    shadow.set()
    color(0xFFFFFF).setFill()
    frontPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    let boltPath = bolt(in: frontCard)
    NSGradient(starting: color(0x4F7BFF), ending: color(0x7A3FE4))?.draw(in: boltPath, angle: -70)

    let streak = NSBezierPath()
    streak.lineWidth = 26
    streak.lineCapStyle = .round
    for (y, length) in [(CGFloat(352), CGFloat(140)), (412, 92)] {
        streak.move(to: NSPoint(x: 352 - length, y: y))
        streak.line(to: NSPoint(x: 352, y: y))
    }
    color(0xFFFFFF, alpha: 0.55).setStroke()
    streak.stroke()
}

func renderPNG(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: canvas, height: canvas)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: generate-icon.swift <output.iconset>\n".utf8))
    exit(1)
}
let iconset = URL(fileURLWithPath: arguments[1])
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 1 ? "" : "@2x"
        let file = iconset.appendingPathComponent("icon_\(points)x\(points)\(suffix).png")
        try renderPNG(pixels: points * scale).write(to: file)
    }
}
