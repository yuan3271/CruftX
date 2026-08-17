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

func makeIcon(size: CGFloat) -> NSImage {
    let s = size
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()
    defer { image.unlockFocus() }

    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    let radius = s * 0.2237
    let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // 1. Base gradient: blue -> cyan -> mint (top-left to bottom-right).
    let base = NSGradient(colors: [
        rgb(0.10, 0.44, 0.98),
        rgb(0.10, 0.62, 0.95),
        rgb(0.34, 0.90, 0.70)
    ])!
    base.draw(in: squircle, angle: 135)

    // 2. Glass highlights and depth, clipped to the squircle.
    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()

    let gloss = NSGradient(colors: [rgb(1, 1, 1, 0.32), rgb(1, 1, 1, 0)])!
    gloss.draw(from: NSPoint(x: 0, y: s), to: NSPoint(x: 0, y: s * 0.52), options: [])

    let bottomShade = NSGradient(colors: [rgb(0, 0, 0, 0), rgb(0, 0, 0, 0.14)])!
    bottomShade.draw(from: NSPoint(x: 0, y: s * 0.42), to: NSPoint(x: 0, y: 0), options: [])

    // A faint diagonal light streak, like light passing through glass.
    let streak = NSBezierPath()
    streak.move(to: NSPoint(x: s * 0.06, y: s * 0.78))
    streak.line(to: NSPoint(x: s * 0.42, y: s * 1.02))
    streak.line(to: NSPoint(x: s * 0.58, y: s * 1.02))
    streak.line(to: NSPoint(x: s * 0.18, y: s * 0.76))
    streak.close()
    rgb(1, 1, 1, 0.10).setFill()
    streak.fill()

    NSGraphicsContext.restoreGraphicsState()

    // 3. Glyph: a layered sparkle cluster with a soft drop shadow.
    let shadow = NSShadow()
    shadow.shadowColor = rgb(0, 0, 0, 0.30)
    shadow.shadowBlurRadius = s * 0.035
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.018)
    shadow.set()

    rgb(1, 1, 1, 0.98).setFill()
    drawSparkle(center: CGPoint(x: s * 0.50, y: s * 0.48), radius: s * 0.25)
    rgb(1, 1, 1, 0.92).setFill()
    drawSparkle(center: CGPoint(x: s * 0.315, y: s * 0.715), radius: s * 0.105)
    drawDot(center: CGPoint(x: s * 0.735, y: s * 0.70), radius: s * 0.040)
    drawDot(center: CGPoint(x: s * 0.79, y: s * 0.43), radius: s * 0.026)

    // A tiny mint accent sparkle near the main one.
    rgb(0.85, 1.0, 0.92, 0.95).setFill()
    drawSparkle(center: CGPoint(x: s * 0.645, y: s * 0.285), radius: s * 0.075)

    return image
}

/// Classic concave four-point sparkle (like SF Symbol "sparkles").
func drawSparkle(center c: CGPoint, radius r: CGFloat) {
    let inner: CGFloat = 0.30
    let points = [
        CGPoint(x: c.x, y: c.y + r),
        CGPoint(x: c.x + r * inner, y: c.y + r * inner),
        CGPoint(x: c.x + r, y: c.y),
        CGPoint(x: c.x + r * inner, y: c.y - r * inner),
        CGPoint(x: c.x, y: c.y - r),
        CGPoint(x: c.x - r * inner, y: c.y - r * inner),
        CGPoint(x: c.x - r, y: c.y),
        CGPoint(x: c.x - r * inner, y: c.y + r * inner)
    ]

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
    path.fill()
}

func drawDot(center: CGPoint, radius: CGFloat) {
    let dot = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))
    dot.fill()
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
