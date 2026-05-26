#!/usr/bin/env swift
// Renders a 1024×1024 PNG of the Tally app icon.
// Designed as a macOS Big Sur-style squircle (22.5% corner radius) with a
// blue→purple gradient and four white tally marks crossed by a diagonal slash.
//
// Usage:
//   swift Scripts/make-icon.swift > /tmp/icon.log
//   (writes build/AppIcon-1024.png)

import AppKit
import CoreGraphics
import Foundation

let size: CGFloat = 1024
let cornerRadius: CGFloat = size * 0.225

let outURL = URL(fileURLWithPath: "build/AppIcon-1024.png")
try? FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let ctx = NSGraphicsContext.current!.cgContext

// Background: rounded squircle filled with a diagonal gradient.
let bg = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
                      xRadius: cornerRadius, yRadius: cornerRadius)
ctx.saveGState()
bg.addClip()

let gradient = NSGradient(colors: [
    NSColor(red: 0.30, green: 0.42, blue: 0.95, alpha: 1.0),   // indigo
    NSColor(red: 0.62, green: 0.28, blue: 0.92, alpha: 1.0)    // violet
])!
gradient.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -55)
ctx.restoreGState()

// Tally marks: 4 vertical strokes + 1 diagonal slash, centered.
let stroke: CGFloat = size * 0.07
let markHeight: CGFloat = size * 0.55
let centerY: CGFloat = size * 0.5
let groupCenter: CGFloat = size * 0.5
let gap: CGFloat = size * 0.105

NSColor.white.setStroke()
let marks = NSBezierPath()
marks.lineWidth = stroke
marks.lineCapStyle = .round

// Four verticals: positions -1.5, -0.5, +0.5, +1.5 * gap from centre.
for i in 0..<4 {
    let offset = -1.5 + Double(i)
    let x = groupCenter + CGFloat(offset) * gap
    marks.move(to: NSPoint(x: x, y: centerY - markHeight / 2))
    marks.line(to: NSPoint(x: x, y: centerY + markHeight / 2))
}

// Diagonal slash sweeping across all four verticals.
let slashPad = gap * 0.4
marks.move(to: NSPoint(x: groupCenter - 1.5 * gap - slashPad,
                        y: centerY - markHeight / 2 - slashPad * 0.4))
marks.line(to: NSPoint(x: groupCenter + 1.5 * gap + slashPad,
                        y: centerY + markHeight / 2 + slashPad * 0.4))
marks.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("failed to encode PNG\n", stderr)
    exit(1)
}

try png.write(to: outURL)
print("wrote \(outURL.path)")
