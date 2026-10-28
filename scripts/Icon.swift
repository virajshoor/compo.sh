import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else { fatalError("Usage: swift scripts/Icon.swift OUTPUT.iconset OUTPUT.icns") }
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
var iconImages: [Int: Data] = [:]
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                           isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Cannot create icon bitmap") }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        NSColor(red: 0.067, green: 0.106, blue: 0.09, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960), xRadius: 216, yRadius: 216).fill()
        NSColor(red: 0.56, green: 0.94, blue: 0.72, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 192, y: 192, width: 264, height: 640), xRadius: 48, yRadius: 48).fill()
        NSBezierPath(roundedRect: NSRect(x: 512, y: 540, width: 320, height: 292), xRadius: 48, yRadius: 48).fill()
        NSColor(red: 0.286, green: 0.482, blue: 0.369, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 512, y: 192, width: 320, height: 292), xRadius: 48, yRadius: 48).fill()
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot encode icon") }
        iconImages[pixels] = png
        let suffix = scale == 2 ? "@2x" : ""
        try png.write(to: directory.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}

// ICNS supports PNG payloads directly; avoid iconutil's external conversion service.
func encodedLength(_ count: Int) -> Data {
    var value = UInt32(count).bigEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}
var chunks = Data()
for (pixels, tag) in [(16, "icp4"), (32, "icp5"), (64, "icp6"), (128, "ic07"),
                      (256, "ic08"), (512, "ic09"), (1024, "ic10")] {
    guard let png = iconImages[pixels] else { fatalError("Missing icon size: \(pixels)") }
    chunks.append(Data(tag.utf8))
    chunks.append(encodedLength(png.count + 8))
    chunks.append(png)
}
var icon = Data("icns".utf8)
icon.append(encodedLength(chunks.count + 8))
icon.append(chunks)
try icon.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
