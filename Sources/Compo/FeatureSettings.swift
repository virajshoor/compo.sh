import AppKit
import CompoCore

enum FeatureSettings {
    static func url(_ name: String) -> URL { AppRules.url.deletingLastPathComponent().appendingPathComponent(name + ".json") }
    static func load<T: Decodable>(_ type: T.Type, name: String, fallback: T) throws -> T {
        let file = url(name)
        guard FileManager.default.fileExists(atPath: file.path) else { return fallback }
        guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 2_097_152 else {
            throw SettingsError.invalid("\(name).json exceeds 2 MB.")
        }
        return try JSONDecoder().decode(type, from: Data(contentsOf: file))
    }
    static func save<T: Encodable>(_ value: T, name: String) throws {
        let file = url(name)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: file, options: .atomic)
    }
}

final class DesktopIndicator {
    private var panel: NSPanel?
    private var timer: Timer?
    func show(index: Int, count: Int) {
        guard count > 0, (0..<count).contains(index) else { return }
        timer?.invalidate()
        let panel = self.panel ?? NSPanel(contentRect: NSRect(x: 0, y: 0, width: 190, height: 44),
                                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        self.panel = panel
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.ignoresMouseEvents = true; panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let background = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 190, height: 44))
        background.material = .hudWindow; background.state = .active
        background.wantsLayer = true; background.layer?.cornerRadius = 12
        let label = NSTextField(labelWithString: "Desktop \(index + 1) of \(count)")
        label.font = .systemFont(ofSize: 15, weight: .semibold); label.alignment = .center
        label.frame = NSRect(x: 6, y: 12, width: 178, height: 22)
        background.addSubview(label); panel.contentView = background
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let bounds = screen?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(x: bounds.midX - 95, y: bounds.minY + 28))
        panel.orderFrontRegardless()
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in self?.panel?.orderOut(nil) }
    }
    deinit { timer?.invalidate(); panel?.orderOut(nil) }
}
