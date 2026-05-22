import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? ".build/LidGuard-1024.png"
let outputURL = URL(fileURLWithPath: outputPath)
let outputDir = outputURL.deletingLastPathComponent()

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let side: CGFloat = 1024
let canvas = NSRect(x: 0, y: 0, width: side, height: side)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
    NSColor(calibratedRed: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: a)
}

func shieldPath(in rect: NSRect) -> NSBezierPath {
    let path = NSBezierPath()
    let cx = rect.midX
    path.move(to: NSPoint(x: cx, y: rect.maxY))
    path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.25))
    path.curve(
        to: NSPoint(x: cx, y: rect.minY),
        controlPoint1: NSPoint(x: rect.maxX + rect.width * 0.03, y: rect.midY),
        controlPoint2: NSPoint(x: cx + rect.width * 0.26, y: rect.minY + rect.height * 0.06)
    )
    path.curve(
        to: NSPoint(x: rect.minX, y: rect.maxY - rect.height * 0.25),
        controlPoint1: NSPoint(x: cx - rect.width * 0.26, y: rect.minY + rect.height * 0.06),
        controlPoint2: NSPoint(x: rect.minX - rect.width * 0.03, y: rect.midY)
    )
    path.close()
    return path
}

let image = NSImage(size: canvas.size, flipped: false) { rect in
    let tileRect = NSRect(x: 52, y: 52, width: 920, height: 920)
    let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: 210, yRadius: 210)

    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()

    let baseGradient = NSGradient(colorsAndLocations:
        (rgb(14, 30, 58), 0.0),
        (rgb(22, 95, 168), 0.48),
        (rgb(30, 183, 146), 1.0)
    )!
    baseGradient.draw(in: tileRect, angle: -52)

    let glowRect = NSRect(x: 90, y: 560, width: 720, height: 430)
    if let glow = NSGradient(starting: rgb(255, 255, 255, 0.24), ending: rgb(255, 255, 255, 0.02)) {
        let glowPath = NSBezierPath(ovalIn: glowRect)
        glow.draw(in: glowPath, relativeCenterPosition: NSPoint(x: -0.4, y: 0.3))
    }

    let darkPlate = NSBezierPath(roundedRect: NSRect(x: 176, y: 202, width: 672, height: 198), xRadius: 84, yRadius: 84)
    rgb(7, 18, 38, 0.27).setFill()
    darkPlate.fill()

    NSGraphicsContext.restoreGraphicsState()

    let tileBorder = NSBezierPath(roundedRect: tileRect, xRadius: 210, yRadius: 210)
    rgb(255, 255, 255, 0.34).setStroke()
    tileBorder.lineWidth = 2
    tileBorder.stroke()

    let lid = NSBezierPath(roundedRect: NSRect(x: 236, y: 614, width: 552, height: 74), xRadius: 30, yRadius: 30)
    rgb(244, 250, 255, 0.92).setFill()
    lid.fill()

    let lidSlot = NSBezierPath(roundedRect: NSRect(x: 300, y: 642, width: 424, height: 9), xRadius: 4.5, yRadius: 4.5)
    rgb(35, 92, 143, 0.46).setFill()
    lidSlot.fill()

    let base = NSBezierPath(roundedRect: NSRect(x: 212, y: 252, width: 600, height: 94), xRadius: 34, yRadius: 34)
    rgb(248, 252, 255, 0.97).setFill()
    base.fill()

    let hinge = NSBezierPath(roundedRect: NSRect(x: 324, y: 286, width: 376, height: 8), xRadius: 4, yRadius: 4)
    rgb(90, 122, 160, 0.56).setFill()
    hinge.fill()

    let shieldOuterRect = NSRect(x: 296, y: 338, width: 432, height: 430)
    let shieldOuter = shieldPath(in: shieldOuterRect)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = rgb(0, 0, 0, 0.24)
    shadow.shadowBlurRadius = 18
    shadow.shadowOffset = NSSize(width: 0, height: -5)
    shadow.set()
    rgb(242, 250, 255, 0.98).setFill()
    shieldOuter.fill()
    NSGraphicsContext.restoreGraphicsState()

    let shieldInnerRect = shieldOuterRect.insetBy(dx: 30, dy: 34)
    let shieldInner = shieldPath(in: shieldInnerRect)
    let shieldGradient = NSGradient(colorsAndLocations:
        (rgb(61, 159, 214), 0.0),
        (rgb(42, 120, 210), 0.58),
        (rgb(31, 92, 171), 1.0)
    )!
    shieldGradient.draw(in: shieldInner, angle: -90)

    let lockBody = NSBezierPath(roundedRect: NSRect(x: rect.midX - 86, y: 500, width: 172, height: 132), xRadius: 34, yRadius: 34)
    rgb(246, 252, 255, 0.98).setFill()
    lockBody.fill()

    let shacklePath = NSBezierPath()
    shacklePath.lineCapStyle = .round
    shacklePath.lineJoinStyle = .round
    shacklePath.lineWidth = 26
    shacklePath.move(to: NSPoint(x: rect.midX - 52, y: 622))
    shacklePath.curve(
        to: NSPoint(x: rect.midX + 52, y: 622),
        controlPoint1: NSPoint(x: rect.midX - 52, y: 690),
        controlPoint2: NSPoint(x: rect.midX + 52, y: 690)
    )
    rgb(246, 252, 255, 0.98).setStroke()
    shacklePath.stroke()

    let keyholeTop = NSBezierPath(ovalIn: NSRect(x: rect.midX - 14, y: 555, width: 28, height: 28))
    rgb(31, 98, 173, 0.94).setFill()
    keyholeTop.fill()

    let keyholeStem = NSBezierPath(roundedRect: NSRect(x: rect.midX - 8, y: 532, width: 16, height: 30), xRadius: 8, yRadius: 8)
    rgb(31, 98, 173, 0.94).setFill()
    keyholeStem.fill()

    return true
}

guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    fputs("Failed to render icon PNG.\n", stderr)
    exit(1)
}

try png.write(to: outputURL)
print("Created \(outputURL.path)")
