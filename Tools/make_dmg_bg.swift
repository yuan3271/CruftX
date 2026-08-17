import AppKit
import ImageIO

// Renders the Finder window background for the CruftX DMG directly into a
// bitmap context (headless-safe, unlike NSImage.lockFocus).
// Usage: swift make_dmg_bg.swift <output.png>

guard CommandLine.arguments.count > 1 else {
    fputs("usage: swift make_dmg_bg.swift <output.png>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let w: CGFloat = 660
let h: CGFloat = 400

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
}

let colorSpace = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(
    data: nil,
    width: Int(w),
    height: Int(h),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

let nsContext = NSGraphicsContext(cgContext: ctx, flipped: true)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsContext

// Background gradient.
let rect = NSRect(x: 0, y: 0, width: w, height: h)
let gradient = NSGradient(colors: [
    rgb(0.10, 0.44, 0.98),
    rgb(0.10, 0.62, 0.95),
    rgb(0.34, 0.90, 0.70)
])!
gradient.draw(in: NSBezierPath(rect: rect), angle: 135)

// Top gloss.
let gloss = NSGradient(colors: [rgb(1, 1, 1, 0.28), rgb(1, 1, 1, 0)])!
gloss.draw(from: NSPoint(x: 0, y: 0), to: NSPoint(x: 0, y: h * 0.38), options: [])

// Drop zones.
func drawZone(centerX: CGFloat) {
    let zone = NSRect(x: centerX - 105, y: 105, width: 210, height: 185)
    let path = NSBezierPath(roundedRect: zone, xRadius: 22, yRadius: 22)
    rgb(1, 1, 1, 0.35).setFill()
    path.fill()
    rgb(1, 1, 1, 0.85).setStroke()
    path.lineWidth = 2
    let dash: [CGFloat] = [10, 6]
    path.setLineDash(dash, count: 2, phase: 0)
    path.stroke()
}

drawZone(centerX: 170)
drawZone(centerX: 490)

func drawLabel(_ text: String, centerX: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor.white
    ]
    let string = NSAttributedString(string: text, attributes: attributes)
    let textSize = string.size()
    string.draw(at: NSPoint(x: centerX - textSize.width / 2, y: y))
}

drawLabel("CruftX", centerX: 170, y: 60, size: 22, weight: .semibold)
drawLabel("Applications", centerX: 490, y: 60, size: 22, weight: .semibold)
drawLabel("拖入 Applications 文件夹即可安装", centerX: w / 2, y: 18, size: 13, weight: .regular)

let arrow = NSAttributedString(string: "→", attributes: [
    .font: NSFont.systemFont(ofSize: 40, weight: .semibold),
    .foregroundColor: NSColor.white.withAlphaComponent(0.95)
])
let arrowSize = arrow.size()
arrow.draw(at: NSPoint(x: 330 - arrowSize.width / 2, y: 185))

NSGraphicsContext.restoreGraphicsState()

guard let cgImage = ctx.makeImage() else {
    fputs("failed to create image\n", stderr)
    exit(1)
}
guard let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL, "public.png" as CFString, 1, nil
) else {
    fputs("failed to create destination\n", stderr)
    exit(1)
}
CGImageDestinationAddImage(destination, cgImage, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("failed to write PNG\n", stderr)
    exit(1)
}
print("background written to \(outputURL.path)")
