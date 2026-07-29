#!/usr/bin/env swift
//
// Generates Hoot's app icon (Support/AppIcon.icns) and the README logo
// (assets/logo.png). Pure CoreGraphics — no design tools required.
//
// Usage (from the repo root): swift Scripts/make_icon.swift

import AppKit
import UniformTypeIdentifiers

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

// All geometry lives in a 1024x1024 canvas and is scaled down per size.
func drawIcon(into ctx: CGContext, canvas: CGFloat) {
    ctx.saveGState()
    let s = canvas / 1024
    ctx.scaleBy(x: s, y: s)

    // Background: rounded square, midnight sky.
    let bgRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    ctx.addPath(CGPath(roundedRect: bgRect, cornerWidth: 185, cornerHeight: 185, transform: nil))
    ctx.clip()

    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [color(0x4A3AA8), color(0x241B52)] as CFArray,
                              locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 512, y: 924),
                           end: CGPoint(x: 512, y: 100),
                           options: [])

    // Stars.
    ctx.setFillColor(color(0xFFFFFF, 0.85))
    let stars: [(CGFloat, CGFloat, CGFloat)] = [
        (200, 800, 7), (300, 720, 5), (430, 830, 6), (585, 795, 5),
        (835, 640, 6), (180, 620, 5), (640, 870, 6), (880, 700, 5),
        (250, 520, 4)
    ]
    for (x, y, r) in stars {
        ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    // Crescent moon. The punch happens inside a transparency layer so it
    // does not erase the sky behind the moon.
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setFillColor(color(0xFFE39A))
    ctx.fillEllipse(in: CGRect(x: 740, y: 760, width: 130, height: 130))
    ctx.setBlendMode(.destinationOut)
    ctx.fillEllipse(in: CGRect(x: 715, y: 783, width: 120, height: 120))
    ctx.setBlendMode(.normal)
    ctx.endTransparencyLayer()

    drawOwl(ctx)
    ctx.restoreGState()
}

func drawOwl(_ ctx: CGContext) {
    let body = color(0xC98A5B)
    let wing = color(0xA96B3F)
    let belly = color(0xF2D9B0)
    let pupil = color(0x2A2140)
    let accent = color(0xF5A840)

    // Ear tufts.
    ctx.setFillColor(body)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 330, y: 610))
    ctx.addLine(to: CGPoint(x: 285, y: 775))
    ctx.addLine(to: CGPoint(x: 445, y: 685))
    ctx.closePath()
    ctx.fillPath()
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 694, y: 610))
    ctx.addLine(to: CGPoint(x: 739, y: 775))
    ctx.addLine(to: CGPoint(x: 579, y: 685))
    ctx.closePath()
    ctx.fillPath()

    // Body.
    ctx.fillEllipse(in: CGRect(x: 262, y: 170, width: 500, height: 540))

    // Wings.
    ctx.setFillColor(wing)
    ctx.fillEllipse(in: CGRect(x: 250, y: 260, width: 130, height: 330))
    ctx.fillEllipse(in: CGRect(x: 644, y: 260, width: 130, height: 330))

    // Belly.
    ctx.setFillColor(belly)
    ctx.fillEllipse(in: CGRect(x: 377, y: 195, width: 270, height: 280))

    // Eyes — wide awake.
    for center in [CGPoint(x: 420, y: 555), CGPoint(x: 604, y: 555)] {
        ctx.setFillColor(color(0xFFFFFF))
        ctx.fillEllipse(in: CGRect(x: center.x - 92, y: center.y - 92, width: 184, height: 184))
        ctx.setFillColor(pupil)
        ctx.fillEllipse(in: CGRect(x: center.x - 40, y: center.y - 40, width: 80, height: 80))
        ctx.setFillColor(color(0xFFFFFF))
        ctx.fillEllipse(in: CGRect(x: center.x + 8, y: center.y + 10, width: 26, height: 26))
    }

    // Beak.
    ctx.setFillColor(accent)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 478, y: 468))
    ctx.addLine(to: CGPoint(x: 546, y: 468))
    ctx.addLine(to: CGPoint(x: 512, y: 405))
    ctx.closePath()
    ctx.fillPath()

    // Feet.
    ctx.fillEllipse(in: CGRect(x: 407, y: 152, width: 82, height: 44))
    ctx.fillEllipse(in: CGRect(x: 535, y: 152, width: 82, height: 44))
}

func render(_ pixels: Int) -> CGImage {
    let ctx = CGContext(data: nil,
                        width: pixels,
                        height: pixels,
                        bitsPerComponent: 8,
                        bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    drawIcon(into: ctx, canvas: CGFloat(pixels))
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

do {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let iconset = root.appendingPathComponent("build/AppIcon.iconset")
    try? FileManager.default.removeItem(at: iconset)
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

    let entries: [(String, Int)] = [
        ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
    ]
    for (name, pixels) in entries {
        writePNG(render(pixels), to: iconset.appendingPathComponent(name))
    }

    try FileManager.default.createDirectory(at: root.appendingPathComponent("Support"), withIntermediateDirectories: true)
    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Support/AppIcon.icns").path]
    try iconutil.run()
    iconutil.waitUntilExit()
    guard iconutil.terminationStatus == 0 else {
        print("iconutil failed with status \(iconutil.terminationStatus)")
        exit(1)
    }

    try FileManager.default.createDirectory(at: root.appendingPathComponent("assets"), withIntermediateDirectories: true)
    writePNG(render(512), to: root.appendingPathComponent("assets/logo.png"))

    print("Wrote Support/AppIcon.icns and assets/logo.png")
} catch {
    print("make_icon failed: \(error.localizedDescription)")
    exit(1)
}
