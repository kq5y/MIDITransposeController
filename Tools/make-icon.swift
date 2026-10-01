// Renders the app icon set. Usage: swift Tools/make-icon.swift Resources/Assets.xcassets/AppIcon.appiconset
import AppKit

func render(size: CGFloat) -> NSBitmapImageRep {
    let px = Int(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: size / 1024, y: size / 1024)

    // macOS icon grid: 824pt body with a 100pt margin
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(shape)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        NSColor(red: 0.42, green: 0.45, blue: 1.00, alpha: 1).cgColor,
        NSColor(red: 0.22, green: 0.12, blue: 0.55, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    let keys = CGRect(x: 172, y: 172, width: 680, height: 300)
    let whiteWidth = keys.width / 7
    for i in 0..<7 {
        let key = CGRect(x: keys.minX + CGFloat(i) * whiteWidth + 5, y: keys.minY,
                         width: whiteWidth - 10, height: keys.height)
        ctx.addPath(CGPath(roundedRect: key, cornerWidth: 22, cornerHeight: 22, transform: nil))
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.96).cgColor)
        ctx.fillPath()
    }
    for i in [1, 2, 4, 5, 6] {
        let width = whiteWidth * 0.58
        let key = CGRect(x: keys.minX + CGFloat(i) * whiteWidth - width / 2, y: keys.maxY - 190,
                         width: width, height: 190)
        ctx.addPath(CGPath(roundedRect: key, cornerWidth: 14, cornerHeight: 14, transform: nil))
        ctx.setFillColor(NSColor(red: 0.12, green: 0.08, blue: 0.30, alpha: 1).cgColor)
        ctx.fillPath()
    }

    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(54)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    for (x, up) in [(CGFloat(412), true), (CGFloat(612), false)] {
        let (tail, tip): (CGFloat, CGFloat) = up ? (560, 830) : (830, 560)
        let head: CGFloat = up ? -72 : 72
        ctx.move(to: CGPoint(x: x, y: tail))
        ctx.addLine(to: CGPoint(x: x, y: tip))
        ctx.move(to: CGPoint(x: x - 66, y: tip + head))
        ctx.addLine(to: CGPoint(x: x, y: tip))
        ctx.addLine(to: CGPoint(x: x + 66, y: tip + head))
    }
    ctx.strokePath()
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        let png = render(size: CGFloat(base * scale)).representation(using: .png, properties: [:])!
        try! png.write(to: out.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(base)x\(base)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: out.appendingPathComponent("Contents.json"))
