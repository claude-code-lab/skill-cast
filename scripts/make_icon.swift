#!/usr/bin/env swift
// Generates the AppIcon (1024x1024 PNG) for SkillCast.app.
// Purple gradient background + white wand.and.stars (same symbol as the menu bar).
import AppKit

let size = 1024
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let image = NSImage(size: rect.size)

image.lockFocus()

// Background: rounded gradient (inset slightly to match macOS icon margin convention)
let inset: CGFloat = 60
let bgRect = rect.insetBy(dx: inset, dy: inset)
let cornerRadius = bgRect.width * 0.22
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.42, green: 0.35, blue: 0.92, alpha: 1.0),
    NSColor(calibratedRed: 0.60, green: 0.32, blue: 0.85, alpha: 1.0),
])
gradient?.draw(in: bgPath, angle: -60)

// Symbol: wand.and.stars in white, centered
let symbolConfig = NSImage.SymbolConfiguration(pointSize: bgRect.width * 0.5, weight: .medium)
if let symbol = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: nil)?
    .withSymbolConfiguration(symbolConfig) {
    let tinted = NSImage(size: symbol.size)
    tinted.lockFocus()
    NSColor.white.set()
    let symbolRect = NSRect(origin: .zero, size: symbol.size)
    symbol.draw(in: symbolRect)
    symbolRect.fill(using: .sourceAtop)
    tinted.unlockFocus()

    let symbolSize = tinted.size
    let symbolOrigin = NSPoint(
        x: bgRect.midX - symbolSize.width / 2,
        y: bgRect.midY - symbolSize.height / 2
    )
    tinted.draw(at: symbolOrigin, from: .zero, operation: .sourceOver, fraction: 1.0)
}

image.unlockFocus()

guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("PNG生成に失敗しました\n".utf8))
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
try pngData.write(to: URL(fileURLWithPath: outputPath))
print("wrote: \(outputPath)")
