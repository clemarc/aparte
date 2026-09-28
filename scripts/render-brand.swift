import AppKit
import Foundation

// Compile together with Sources/Aparte/Branding.swift (see generate-brand.sh).
@main struct BrandExport {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { fatalError("Expected an output .iconset directory") }
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for points in [16, 32, 128, 256, 512] {
            for multiplier in [1, 2] {
                let size = points * multiplier
                let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                let scale = CGFloat(size) / 1024
                context.scaleBy(x: scale, y: scale)
                context.translateBy(x: 0, y: 1024); context.scaleBy(x: 1, y: -1)
                let plate = CGRect(x: 64, y: 64, width: 896, height: 896)
                context.setFillColor(CGColor(red: 0.14, green: 0.23, blue: 0.32, alpha: 1))
                context.addPath(CGPath(roundedRect: plate, cornerWidth: 200, cornerHeight: 200, transform: nil)); context.fillPath()
                context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
                context.addPath(AparteBrand.path(in: CGRect(x: 204, y: 285, width: 616, height: 444))); context.fillPath()
                let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
                let suffix = multiplier == 2 ? "@2x" : ""
                try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
            }
        }
    }
}
