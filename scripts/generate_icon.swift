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
    path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.30))
    path.curve(
        to: NSPoint(x: cx, y: rect.minY),
        controlPoint1: NSPoint(x: rect.maxX + rect.width * 0.02, y: rect.midY),
        controlPoint2: NSPoint(x: cx + rect.width * 0.28, y: rect.minY + rect.height * 0.10)
    )
    path.curve(
        to: NSPoint(x: rect.minX, y: rect.maxY - rect.height * 0.30),
        controlPoint1: NSPoint(x: cx - rect.width * 0.28, y: rect.minY + rect.height * 0.10),
        controlPoint2: NSPoint(x: rect.minX - rect.width * 0.02, y: rect.midY)
    )
    path.close()
    return path
}

func strokeNeon(_ path: NSBezierPath, lineWidth: CGFloat, color: NSColor) {
    path.lineJoinStyle = .round
    path.lineCapStyle = .round

    NSGraphicsContext.saveGraphicsState()
    let outerGlow = NSShadow()
    outerGlow.shadowColor = color.withAlphaComponent(0.50)
    outerGlow.shadowBlurRadius = 30
    outerGlow.shadowOffset = .zero
    outerGlow.set()
    color.setStroke()
    path.lineWidth = lineWidth
    path.stroke()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    let innerGlow = NSShadow()
    innerGlow.shadowColor = color.withAlphaComponent(0.40)
    innerGlow.shadowBlurRadius = 10
    innerGlow.shadowOffset = .zero
    innerGlow.set()
    rgb(236, 255, 173, 0.95).setStroke()
    path.lineWidth = max(2, lineWidth * 0.38)
    path.stroke()
    NSGraphicsContext.restoreGraphicsState()
}

let image = NSImage(size: canvas.size, flipped: false) { rect in
    let tileRect = NSRect(x: 58, y: 58, width: 908, height: 908)
    let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: 190, yRadius: 190)

    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()

    let baseGradient = NSGradient(colorsAndLocations:
        (rgb(5, 7, 13), 0.0),
        (rgb(6, 10, 20), 0.55),
        (rgb(10, 16, 34), 1.0)
    )!
    baseGradient.draw(in: tileRect, angle: -90)

    if let softLight = NSGradient(starting: rgb(25, 43, 96, 0.36), ending: rgb(6, 8, 14, 0.0)) {
        let softLightPath = NSBezierPath(ovalIn: NSRect(x: 120, y: 540, width: 790, height: 510))
        softLight.draw(in: softLightPath, relativeCenterPosition: NSPoint(x: -0.18, y: 0.30))
    }

    if let neonFog = NSGradient(starting: rgb(144, 255, 53, 0.11), ending: rgb(120, 210, 35, 0.0)) {
        let fogPath = NSBezierPath(ovalIn: NSRect(x: 196, y: 150, width: 632, height: 560))
        neonFog.draw(in: fogPath, relativeCenterPosition: .zero)
    }

    NSGraphicsContext.restoreGraphicsState()

    let tileBorder = NSBezierPath(roundedRect: tileRect, xRadius: 190, yRadius: 190)
    rgb(115, 124, 163, 0.28).setStroke()
    tileBorder.lineWidth = 2.5
    tileBorder.stroke()

    let neon = rgb(176, 255, 56, 1.0)
    let shield = shieldPath(in: NSRect(x: 232, y: 212, width: 560, height: 560))
    strokeNeon(shield, lineWidth: 26, color: neon)

    let screen = NSBezierPath(roundedRect: NSRect(x: 378, y: 442, width: 268, height: 165), xRadius: 24, yRadius: 24)
    strokeNeon(screen, lineWidth: 20, color: neon)

    let base = NSBezierPath(roundedRect: NSRect(x: 307, y: 360, width: 410, height: 30), xRadius: 16, yRadius: 16)
    strokeNeon(base, lineWidth: 10, color: neon)

    let notch = NSBezierPath(roundedRect: NSRect(x: 466, y: 376, width: 92, height: 16), xRadius: 8, yRadius: 8)
    strokeNeon(notch, lineWidth: 7, color: neon)

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
