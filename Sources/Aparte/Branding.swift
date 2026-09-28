import AppKit
import SwiftUI

/// Scalable rendition of the owner-selected voice-to-text mark (logo 3).
/// The same geometry supplies SwiftUI, the menu template and the exported icon.
enum AparteBrand {
    static func path(in rect: CGRect) -> CGPath {
        let strokes = CGMutablePath()
        strokes.move(to: CGPoint(x: 15, y: 49)); strokes.addLine(to: CGPoint(x: 15, y: 65))
        strokes.move(to: CGPoint(x: 39, y: 37)); strokes.addLine(to: CGPoint(x: 39, y: 77))
        strokes.move(to: CGPoint(x: 63, y: 24)); strokes.addLine(to: CGPoint(x: 63, y: 81))
        // Branch from the tallest speech bar into the first line of text.
        strokes.move(to: CGPoint(x: 63, y: 40))
        strokes.addCurve(to: CGPoint(x: 87, y: 65), control1: CGPoint(x: 63, y: 58), control2: CGPoint(x: 72, y: 65))
        strokes.addLine(to: CGPoint(x: 132, y: 65))
        strokes.move(to: CGPoint(x: 88, y: 85)); strokes.addLine(to: CGPoint(x: 132, y: 85))
        let filled = strokes.copy(strokingWithWidth: 17, lineCap: .round, lineJoin: .round, miterLimit: 2)
        let scale = min(rect.width / 150, rect.height / 108)
        var transform = CGAffineTransform(translationX: rect.midX - 75 * scale, y: rect.midY - 54 * scale).scaledBy(x: scale, y: scale)
        return filled.copy(using: &transform)!
    }
    static let menuImage: NSImage = {
        let image = NSImage(size: NSSize(width: 23, height: 18), flipped: true) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setFillColor(NSColor.black.cgColor); context.addPath(path(in: bounds)); context.fillPath(); return true
        }
        image.isTemplate = true; image.accessibilityDescription = "Aparté"; return image
    }()
}
struct AparteLogo: Shape {
    func path(in rect: CGRect) -> Path { Path(AparteBrand.path(in: rect)) }
}
