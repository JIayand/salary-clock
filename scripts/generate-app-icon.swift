import AppKit
import CoreGraphics

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("No graphics context") }
ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)

let rect = CGRect(x: 0, y: 0, width: size, height: size)
let outer = CGRect(x: 22, y: 22, width: 980, height: 980)
let bgPath = CGPath(roundedRect: outer, cornerWidth: 220, cornerHeight: 220, transform: nil)
ctx.addPath(bgPath)
ctx.clip()
let colors = [
    CGColor(red: 0.035, green: 0.075, blue: 0.16, alpha: 1),
    CGColor(red: 0.055, green: 0.16, blue: 0.29, alpha: 1),
    CGColor(red: 0.015, green: 0.045, blue: 0.105, alpha: 1)
] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.52, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 100, y: 980), end: CGPoint(x: 920, y: 30), options: [])

func stroke(_ path: CGPath, color: CGColor, width: CGFloat, shadow: Bool = false) {
    ctx.saveGState()
    if shadow {
        ctx.setShadow(offset: CGSize(width: 0, height: -9), blur: 20, color: CGColor(gray: 0, alpha: 0.48))
    }
    ctx.addPath(path)
    ctx.setStrokeColor(color)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()
    ctx.restoreGState()
}
func fillRound(_ r: CGRect, radius: CGFloat, color: CGColor) {
    ctx.saveGState()
    ctx.setFillColor(color)
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.fillPath()
    ctx.restoreGState()
}

// Subtle halo
ctx.saveGState()
ctx.setFillColor(CGColor(red: 0.05, green: 0.45, blue: 0.68, alpha: 0.15))
ctx.fillEllipse(in: CGRect(x: 90, y: 95, width: 845, height: 845))
ctx.restoreGState()

// Clock rim
let ring = CGMutablePath()
ring.addEllipse(in: CGRect(x: 155, y: 180, width: 650, height: 650))
stroke(ring, color: CGColor(red: 0.98, green: 0.66, blue: 0.22, alpha: 1), width: 42, shadow: true)
let innerRing = CGMutablePath()
innerRing.addEllipse(in: CGRect(x: 178, y: 203, width: 604, height: 604))
stroke(innerRing, color: CGColor(red: 1, green: 0.88, blue: 0.58, alpha: 0.9), width: 7)

// Clock markers
for angle in [0.0, 90.0, 180.0, 270.0] {
    let a = angle * Double.pi / 180
    let cx: CGFloat = 480, cy: CGFloat = 505, r: CGFloat = 270
    let x = cx + cos(a) * r, y = cy + sin(a) * r
    let marker = CGRect(x: x - 10, y: y - 28, width: 20, height: 56)
    fillRound(marker, radius: 10, color: CGColor(red: 1, green: 0.91, blue: 0.68, alpha: 1))
}

// Hands
let hands = CGMutablePath()
hands.move(to: CGPoint(x: 480, y: 505))
hands.addLine(to: CGPoint(x: 480, y: 700))
hands.move(to: CGPoint(x: 480, y: 505))
hands.addLine(to: CGPoint(x: 650, y: 610))
stroke(hands, color: CGColor(red: 1, green: 0.88, blue: 0.62, alpha: 1), width: 27, shadow: true)

// Rising income bars
let barColors = [
    CGColor(red: 0.94, green: 0.49, blue: 0.12, alpha: 1),
    CGColor(red: 1, green: 0.65, blue: 0.20, alpha: 1),
    CGColor(red: 1, green: 0.79, blue: 0.36, alpha: 1)
]
let bars: [(CGRect, CGFloat)] = [
    (CGRect(x: 560, y: 95, width: 105, height: 210), 22),
    (CGRect(x: 690, y: 95, width: 105, height: 300), 22),
    (CGRect(x: 820, y: 95, width: 105, height: 410), 22)
]
for (i, item) in bars.enumerated() {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: CGColor(red: 0.95, green: 0.48, blue: 0.1, alpha: 0.25))
    ctx.setFillColor(barColors[i])
    ctx.addPath(CGPath(roundedRect: item.0, cornerWidth: item.1, cornerHeight: item.1, transform: nil))
    ctx.fillPath()
    ctx.restoreGState()
    let shine = CGRect(x: item.0.minX + 9, y: item.0.minY + 10, width: 12, height: item.0.height - 20)
    fillRound(shine, radius: 6, color: CGColor(red: 1, green: 0.92, blue: 0.68, alpha: 0.22))
}

// Orbit / progress sweep
let orbit = CGMutablePath()
orbit.move(to: CGPoint(x: 130, y: 235))
orbit.addCurve(to: CGPoint(x: 930, y: 520), control1: CGPoint(x: 220, y: 20), control2: CGPoint(x: 760, y: 10))
stroke(orbit, color: CGColor(red: 1, green: 0.76, blue: 0.31, alpha: 1), width: 18, shadow: true)

// Center pin
ctx.setFillColor(CGColor(red: 1, green: 0.77, blue: 0.31, alpha: 1))
ctx.fillEllipse(in: CGRect(x: 450, y: 475, width: 60, height: 60))
ctx.setStrokeColor(CGColor(red: 1, green: 0.95, blue: 0.78, alpha: 1))
ctx.setLineWidth(6)
ctx.strokeEllipse(in: CGRect(x: 450, y: 475, width: 60, height: 60))

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("PNG encode failed") }
let output = CommandLine.arguments[1]
try png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
