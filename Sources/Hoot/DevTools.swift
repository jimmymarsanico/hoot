import AppKit

/// `Hoot --smoke-test`
/// Verifies that the app can spawn and stop `caffeinate`. Used by CI.
func runSmokeTest() -> Int32 {
    let controller = CaffeinateController()
    controller.keepAwake(for: 60)

    guard let pid = controller.caffeinatePID else {
        print("smoke-test: caffeinate failed to launch")
        return 1
    }

    guard waitFor({ kill(pid, 0) == 0 }) else {
        print("smoke-test: caffeinate (pid \(pid)) is not running")
        return 1
    }
    print("smoke-test: caffeinate running (pid \(pid), mode \(controller.mode))")

    controller.letSleep()
    guard waitFor({ kill(pid, 0) != 0 }) else {
        print("smoke-test: caffeinate (pid \(pid)) survived deactivation")
        return 1
    }
    print("smoke-test: caffeinate stopped cleanly — OK")
    return 0
}

/// `Hoot --dump-icons <dir>`
/// Renders the menu bar glyphs to PNGs so they can be eyeballed outside the menu bar.
func dumpIcons(to directory: String) -> Int32 {
    let dir = URL(fileURLWithPath: directory, isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try writePNG(StatusIcon.awake, to: dir.appendingPathComponent("menubar-awake.png"))
        try writePNG(StatusIcon.asleep, to: dir.appendingPathComponent("menubar-asleep.png"))
    } catch {
        print("dump-icons: \(error.localizedDescription)")
        return 1
    }
    print("dump-icons: wrote menubar-awake.png and menubar-asleep.png to \(dir.path)")
    return 0
}

private func waitFor(_ condition: () -> Bool, timeout: TimeInterval = 3) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        // Let Process termination handlers and main-queue work run.
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    return condition()
}

private func writePNG(_ image: NSImage, to url: URL, scale: CGFloat = 8) throws {
    let pixelSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: Int(pixelSize.width),
                                     pixelsHigh: Int(pixelSize.height),
                                     bitsPerSample: 8,
                                     samplesPerPixel: 4,
                                     hasAlpha: true,
                                     isPlanar: false,
                                     colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0,
                                     bitsPerPixel: 0) else {
        throw CocoaError(.fileWriteUnknown)
    }
    rep.size = pixelSize
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(origin: .zero, size: pixelSize))
    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: url)
}
