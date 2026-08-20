import AppKit

// Generates the AppIcon.iconset PNGs for CruftX with a vector-designed
// glyph, then make_icns.py assembles the .icns.
// Usage: swift gen_icon.swift <output-iconset-dir> [preview.png]

guard CommandLine.arguments.count > 1 else {
    fputs("usage: swift gen_icon.swift <iconset-dir> [preview.png]\n", stderr)
    exit(1)
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
let previewPath = CommandLine.arguments.count > 2 ? URL(fileURLWithPath: CommandLine.arguments[2]) : nil

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
}

/// Apple-style continuous-corner squircle (superellipse with n = 5), the
/// shape used by modern macOS app icons.
func squirclePath(in rect: NSRect) -> NSBezierPath {
    let n: CGFloat = 5.0
    let cx = rect.midX
    let cy = rect.midY
    let rx = rect.width / 2
    let ry = rect.height / 2
    let steps = 240
    let path = NSBezierPath()

    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let cosT = cos(t)
        let sinT = sin(t)
        let x = cx + rx * (cosT >= 0 ? 1 : -1) * pow(abs(cosT), 2 / n)
        let y = cy + ry * (sinT >= 0 ? 1 : -1) * pow(abs(sinT), 2 / n)
        let point = NSPoint(x: x, y: y)
        if i == 0 {
            path.move(to: point)
        } else {
            path.line(to: point)
        }
    }
    path.close()
    return path
}

/// Concave four-point sparkle (like SF Symbol "sparkles"), optionally rotated.
func sparklePath(center c: CGPoint, radius r: CGFloat, angle: CGFloat = 0) -> NSBezierPath {
    let inner: CGFloat = 0.30
    let rawPoints = [
        CGPoint(x: c.x, y: c.y + r),
        CGPoint(x: c.x + r * inner, y: c.y + r * inner),
        CGPoint(x: c.x + r, y: c.y),
        CGPoint(x: c.x + r * inner, y: c.y - r * inner),
        CGPoint(x: c.x, y: c.y - r),
        CGPoint(x: c.x - r * inner, y: c.y - r * inner),
        CGPoint(x: c.x - r, y: c.y),
        CGPoint(x: c.x - r * inner, y: c.y + r * inner)
    ]

    let radians = angle * .pi / 180
    let points = rawPoints.map { p -> CGPoint in
        let dx = p.x - c.x
        let dy = p.y - c.y
        return CGPoint(
            x: c.x + dx * cos(radians) - dy * sin(radians),
            y: c.y + dx * sin(radians) + dy * cos(radians)
        )
    }

    let path = NSBezierPath()
    path.move(to: points[0])
    for i in 0..<points.count {
        let next = points[(i + 1) % points.count]
        let mid = CGPoint(x: (points[i].x + next.x) / 2, y: (points[i].y + next.y) / 2)
        // Pull the control point toward the center to create concave edges.
        let control = CGPoint(
            x: mid.x + (c.x - mid.x) * 0.62,
            y: mid.y + (c.y - mid.y) * 0.62
        )
        path.curve(to: next, controlPoint1: control, controlPoint2: control)
    }
    path.close()
    return path
}

func drawSparkle(center c: CGPoint, radius r: CGFloat, angle: CGFloat = 0,
                 top: NSColor, bottom: NSColor) {
    let path = sparklePath(center: c, radius: r, angle: angle)
    let gradient = NSGradient(colors: [bottom, top])!
    gradient.draw(in: path, angle: 90)
}

func drawDot(center: CGPoint, radius: CGFloat, color: NSColor = .white) {
    color.setFill()
    let dot = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))
    dot.fill()
}

func makeIcon(size: CGFloat) -> NSImage {
    let s = size
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()
    defer { image.unlockFocus() }

    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    let squircle = squirclePath(in: rect)

    // 1. Base gradient: deep blue -> cyan -> mint (top-left to bottom-right).
    let base = NSGradient(colors: [
        rgb(0.07, 0.36, 0.95),
        rgb(0.10, 0.58, 0.94),
        rgb(0.14, 0.76, 0.86),
        rgb(0.35, 0.91, 0.68)
    ])!
    base.draw(in: squircle, angle: 132)

    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()

    // Soft radial light behind the glyph, like a glow through frosted glass.
    let glow = NSGradient(colors: [rgb(0.60, 0.88, 1.0, 0.34), rgb(0.60, 0.88, 1.0, 0)])!
    glow.draw(
        fromCenter: NSPoint(x: s * 0.50, y: s * 0.46),
        radius: 0,
        toCenter: NSPoint(x: s * 0.50, y: s * 0.46),
        radius: s * 0.72,
        options: [.drawsAfterEndingLocation]
    )

    // Glass highlights: crisp top gloss + soft diagonal streak.
    let gloss = NSGradient(colors: [rgb(1, 1, 1, 0.34), rgb(1, 1, 1, 0)])!
    gloss.draw(from: NSPoint(x: 0, y: s), to: NSPoint(x: 0, y: s * 0.50), options: [])

    let streak = NSBezierPath()
    streak.move(to: NSPoint(x: s * 0.06, y: s * 0.80))
    streak.line(to: NSPoint(x: s * 0.40, y: s * 1.03))
    streak.line(to: NSPoint(x: s * 0.56, y: s * 1.03))
    streak.line(to: NSPoint(x: s * 0.17, y: s * 0.78))
    streak.close()
    rgb(1, 1, 1, 0.09).setFill()
    streak.fill()

    // A soft vignette keeps the bottom from feeling flat.
    let bottomShade = NSGradient(colors: [rgb(0, 0, 0, 0), rgb(0, 0, 0, 0.13)])!
    bottomShade.draw(from: NSPoint(x: 0, y: s * 0.42), to: NSPoint(x: 0, y: 0), options: [])

    NSGraphicsContext.restoreGraphicsState()

    // 2. Glyph: a layered sparkle cluster with glow, gradient and shadow.
    let shadow = NSShadow()
    shadow.shadowColor = rgb(0, 0, 0, 0.30)
    shadow.shadowBlurRadius = s * 0.045
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.018)
    shadow.set()

    drawSparkle(
        center: CGPoint(x: s * 0.50, y: s * 0.465),
        radius: s * 0.245,
        top: rgb(1, 1, 1),
        bottom: rgb(0.88, 0.95, 1.0)
    )
    drawSparkle(
        center: CGPoint(x: s * 0.325, y: s * 0.715),
        radius: s * 0.100,
        angle: 18,
        top: rgb(1, 1, 1),
        bottom: rgb(0.92, 0.98, 1.0)
    )
    drawDot(center: CGPoint(x: s * 0.735, y: s * 0.705), radius: s * 0.040)
    drawDot(center: CGPoint(x: s * 0.795, y: s * 0.425), radius: s * 0.026, color: rgb(1, 1, 1, 0.92))
    drawDot(center: CGPoint(x: s * 0.435, y: s * 0.80), radius: s * 0.015, color: rgb(1, 1, 1, 0.70))

    // Mint accent sparkle near the main one.
    drawSparkle(
        center: CGPoint(x: s * 0.655, y: s * 0.275),
        radius: s * 0.072,
        angle: -14,
        top: rgb(0.95, 1.0, 0.95),
        bottom: rgb(0.65, 0.95, 0.80)
    )

    // 3. A whisper of an inner rim gives the squircle a crisp edge.
    let rimInset = s * 0.015
    let rim = squirclePath(in: rect.insetBy(dx: rimInset, dy: rimInset))
    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()
    rim.lineWidth = s * 0.014
    rgb(1, 1, 1, 0.10).setStroke()
    rim.stroke()
    NSGraphicsContext.restoreGraphicsState()

    return image
}

let specs: [(name: String, points: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for spec in specs {
    let image = makeIcon(size: CGFloat(spec.points))
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else {
        fputs("failed to render \(spec.name)\n", stderr)
        exit(1)
    }
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fputs("failed to encode \(spec.name)\n", stderr)
        exit(1)
    }
    try png.write(to: outputDir.appendingPathComponent(spec.name))
}

if let previewPath {
    let preview = makeIcon(size: 1024)
    guard let tiff = preview.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fputs("failed to write preview\n", stderr)
        exit(1)
    }
    try png.write(to: previewPath)
}

print("iconset written to \(outputDir.path)")
