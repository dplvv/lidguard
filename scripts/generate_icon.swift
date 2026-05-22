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

let image = NSImage(size: canvas.size, flipped: false) { rect in
    let background = NSBezierPath(roundedRect: NSRect(x: 44, y: 44, width: 936, height: 936), xRadius: 220, yRadius: 220)
    let gradient = NSGradient(colorsAndLocations:
        (rgb(22, 102, 156), 0.0),
        (rgb(36, 147, 120), 0.55),
        (rgb(15, 74, 132), 1.0)
    )!
    gradient.draw(in: background, angle: -58)

    // Soft highlight for depth.
    let highlight = NSBezierPath(roundedRect: NSRect(x: 100, y: 520, width: 824, height: 380), xRadius: 160, yRadius: 160)
    rgb(255, 255, 255, 0.12).setFill()
    highlight.fill()

    // Laptop base.
    let base = NSBezierPath(roundedRect: NSRect(x: 190, y: 252, width: 644, height: 86), xRadius: 32, yRadius: 32)
    rgb(250, 253, 255, 0.95).setFill()
    base.fill()

    // Laptop screen frame.
    let screenOuter = NSBezierPath(roundedRect: NSRect(x: 230, y: 328, width: 564, height: 320), xRadius: 44, yRadius: 44)
    rgb(250, 253, 255, 0.96).setFill()
    screenOuter.fill()

    let screenInner = NSBezierPath(roundedRect: NSRect(x: 258, y: 356, width: 508, height: 264), xRadius: 28, yRadius: 28)
    rgb(34, 82, 121, 0.92).setFill()
    screenInner.fill()

    // Shield body.
    let shield = NSBezierPath()
    shield.move(to: NSPoint(x: rect.midX, y: 760))
    shield.line(to: NSPoint(x: 720, y: 682))
    shield.curve(to: NSPoint(x: rect.midX, y: 430), controlPoint1: NSPoint(x: 728, y: 545), controlPoint2: NSPoint(x: 620, y: 448))
    shield.curve(to: NSPoint(x: 304, y: 682), controlPoint1: NSPoint(x: 404, y: 448), controlPoint2: NSPoint(x: 296, y: 545))
    shield.close()
    rgb(233, 246, 255, 0.97).setFill()
    shield.fill()

    // Lock icon inside shield.
    let shackle = NSBezierPath(roundedRect: NSRect(x: 452, y: 612, width: 120, height: 108), xRadius: 48, yRadius: 48)
    rgb(33, 94, 144, 0.95).setStroke()
    shackle.lineWidth = 24
    shackle.stroke()

    let lockBody = NSBezierPath(roundedRect: NSRect(x: 430, y: 520, width: 164, height: 132), xRadius: 28, yRadius: 28)
    rgb(33, 94, 144, 0.95).setFill()
    lockBody.fill()

    let keyHole = NSBezierPath(ovalIn: NSRect(x: 495, y: 560, width: 34, height: 34))
    rgb(233, 246, 255, 0.98).setFill()
    keyHole.fill()

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
