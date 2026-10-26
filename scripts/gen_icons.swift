import Foundation
import AppKit

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "/Users/mabedalj/athkari_app/Dikhr/Dikhr/Resources/AppIcons"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

struct IconVariant { let id: String; let bg1: NSColor; let bg2: NSColor; let fg: NSColor }

let variants: [IconVariant] = [
    IconVariant(id: "AppIcon-10", bg1: NSColor(calibratedRed: 0.06, green: 0.29, blue: 0.36, alpha: 1), bg2: NSColor(calibratedRed: 0.03, green: 0.16, blue: 0.21, alpha: 1), fg: NSColor(calibratedWhite: 0.95, alpha: 1)),
    IconVariant(id: "AppIcon-11", bg1: NSColor(calibratedRed: 0.32, green: 0.07, blue: 0.16, alpha: 1), bg2: NSColor(calibratedRed: 0.18, green: 0.04, blue: 0.09, alpha: 1), fg: NSColor(calibratedWhite: 0.95, alpha: 1)),
    IconVariant(id: "AppIcon-12", bg1: NSColor(calibratedRed: 0.07, green: 0.16, blue: 0.35, alpha: 1), bg2: NSColor(calibratedRed: 0.04, green: 0.09, blue: 0.22, alpha: 1), fg: NSColor(calibratedWhite: 0.95, alpha: 1)),
    IconVariant(id: "AppIcon-13", bg1: NSColor(calibratedRed: 0.10, green: 0.32, blue: 0.22, alpha: 1), bg2: NSColor(calibratedRed: 0.05, green: 0.19, blue: 0.13, alpha: 1), fg: NSColor(calibratedWhite: 0.95, alpha: 1)),
    IconVariant(id: "AppIcon-14", bg1: NSColor(calibratedRed: 0.78, green: 0.51, blue: 0.10, alpha: 1), bg2: NSColor(calibratedRed: 0.62, green: 0.38, blue: 0.05, alpha: 1), fg: NSColor(calibratedWhite: 1, alpha: 1)),
    IconVariant(id: "AppIcon-15", bg1: NSColor(calibratedRed: 0.28, green: 0.11, blue: 0.42, alpha: 1), bg2: NSColor(calibratedRed: 0.17, green: 0.06, blue: 0.27, alpha: 1), fg: NSColor(calibratedWhite: 0.95, alpha: 1)),
    IconVariant(id: "AppIcon-16", bg1: NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.18, alpha: 1), bg2: NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.09, alpha: 1), fg: NSColor(calibratedWhite: 0.95, alpha: 1)),
    IconVariant(id: "AppIcon-17", bg1: NSColor(calibratedRed: 0.88, green: 0.88, blue: 0.86, alpha: 1), bg2: NSColor(calibratedRed: 0.72, green: 0.72, blue: 0.70, alpha: 1), fg: NSColor(calibratedRed: 0.02, green: 0.25, blue: 0.29, alpha: 1)),
]

let size: CGFloat = 1024

for v in variants {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { continue }
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // Background gradient
    let colors = [v.bg1.cgColor, v.bg2.cgColor] as CFArray
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

    // Crescent moon: solid circle punched by a background-toned circle
    ctx.saveGState()
    let full = CGRect(x: 640, y: 660, width: 280, height: 280)
    ctx.setFillColor(v.fg.withAlphaComponent(0.92).cgColor)
    ctx.fillEllipse(in: full)
    let cut = CGRect(x: 700, y: 690, width: 280, height: 280)
    ctx.setFillColor(v.bg1.cgColor)
    ctx.fillEllipse(in: cut)
    let cut2 = CGRect(x: 640, y: 800, width: 380, height: 380)
    ctx.setFillColor(v.bg1.cgColor)
    ctx.fillEllipse(in: cut2)
    ctx.restoreGState()

    // Main dhikr glyph
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 430, weight: .bold),
        .foregroundColor: v.fg
    ]
    let text = NSAttributedString(string: "ذ", attributes: attrs)
    let line = CTLineCreateWithAttributedString(text)
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    ctx.textPosition = CGPoint(x: (size - bounds.width) / 2 - 40, y: 360)
    CTLineDraw(line, ctx)

    // Baseline dots strip (tasbih dots)
    ctx.setFillColor(v.fg.withAlphaComponent(0.55).cgColor)
    for i in 0..<3 {
        ctx.fillEllipse(in: CGRect(x: 512 - 60 + CGFloat(i) * 60, y: 250, width: 26, height: 26))
    }

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:])
    else { continue }
    try? png.write(to: URL(fileURLWithPath: "\(outDir)/\(v.id).png"))
    print("wrote \(v.id).png")
}