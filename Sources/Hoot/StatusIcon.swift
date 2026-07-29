import AppKit

/// Draws the owl template glyphs for the menu bar.
/// Eyes open = Hoot is keeping the Mac awake. Eyes closed = normal sleep.
enum StatusIcon {
    static let awake = owl(awake: true)
    static let asleep = owl(awake: false)

    private static func owl(awake: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            // Head: a plump circle with two ear tufts.
            let head = NSBezierPath(ovalIn: NSRect(x: 1.5, y: 0.75, width: 15, height: 14))

            let leftTuft = NSBezierPath()
            leftTuft.move(to: NSPoint(x: 2.8, y: 10.5))
            leftTuft.line(to: NSPoint(x: 0.8, y: 15.8))
            leftTuft.line(to: NSPoint(x: 6.5, y: 13.6))
            leftTuft.close()

            let rightTuft = NSBezierPath()
            rightTuft.move(to: NSPoint(x: 15.2, y: 10.5))
            rightTuft.line(to: NSPoint(x: 17.2, y: 15.8))
            rightTuft.line(to: NSPoint(x: 11.5, y: 13.6))
            rightTuft.close()

            NSColor.black.setFill()
            NSColor.black.setStroke()
            head.fill()
            leftTuft.fill()
            rightTuft.fill()

            // Punch the face features out of the silhouette.
            ctx.setBlendMode(.destinationOut)

            if awake {
                NSBezierPath(ovalIn: NSRect(x: 3.0, y: 5.4, width: 5.8, height: 5.8)).fill()
                NSBezierPath(ovalIn: NSRect(x: 9.2, y: 5.4, width: 5.8, height: 5.8)).fill()
            } else {
                for centerX: CGFloat in [5.9, 12.1] {
                    let eye = NSBezierPath()
                    eye.move(to: NSPoint(x: centerX - 1.9, y: 8.7))
                    eye.curve(to: NSPoint(x: centerX + 1.9, y: 8.7),
                              controlPoint1: NSPoint(x: centerX - 1.1, y: 6.7),
                              controlPoint2: NSPoint(x: centerX + 1.1, y: 6.7))
                    eye.lineWidth = 1.5
                    eye.lineCapStyle = .round
                    eye.stroke()
                }
            }

            // Beak — a narrow triangle right beneath where the eyes meet.
            let beak = NSBezierPath()
            beak.move(to: NSPoint(x: 8.2, y: 5.2))
            beak.line(to: NSPoint(x: 9.8, y: 5.2))
            beak.line(to: NSPoint(x: 9.0, y: 3.2))
            beak.close()
            beak.fill()

            ctx.setBlendMode(.normal)
            return true
        }
        image.isTemplate = true
        return image
    }
}
