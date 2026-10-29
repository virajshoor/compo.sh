import AppKit

final class DragController {
    private var monitors: [Any] = []
    private let panel: NSPanel
    private let preview = SnapPreview()

    init(handler: @escaping (NSEvent.EventType, CGPoint) -> Void) {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = preview
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        let receive: (NSEvent) -> Void = { event in
            if let point = event.cgEvent?.location {
                handler(event.type, point)
                return
            }
            let point = NSEvent.mouseLocation
            let top = NSScreen.screens.first?.frame.maxY ?? 0
            handler(event.type, CGPoint(x: point.x, y: top - point.y))
        }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: receive) { monitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in receive(event); return event }) {
            monitors.append(monitor)
        }
    }

    func show(_ frame: CGRect?, swapping: Bool = false) {
        guard let frame else { panel.orderOut(nil); return }
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        let rect = CGRect(x: frame.minX, y: top - frame.maxY, width: frame.width, height: frame.height)
        if panel.frame != rect { panel.setFrame(rect, display: true) }
        preview.swapping = swapping
        preview.needsDisplay = true
        panel.orderFrontRegardless()
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        panel.orderOut(nil)
    }
    deinit { stop() }
}

private final class SnapPreview: NSView {
    var swapping = false
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), xRadius: 14, yRadius: 14)
        let color = NSColor(srgbRed: 0.56, green: 0.94, blue: 0.72, alpha: 1)
        color.withAlphaComponent(0.20).setFill(); path.fill()
        color.withAlphaComponent(0.95).setStroke(); path.lineWidth = 3; path.stroke()
        let text = swapping ? "Release to swap" : "Release to snap"
        let style = NSMutableParagraphStyle(); style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor.white, .paragraphStyle: style]
        let label = CGRect(x: 16, y: bounds.midY - 18, width: max(0, bounds.width - 32), height: 36)
        NSColor.black.withAlphaComponent(0.8).setFill()
        NSBezierPath(roundedRect: label, xRadius: 9, yRadius: 9).fill()
        (text as NSString).draw(in: label.insetBy(dx: 4, dy: 8), withAttributes: attributes)
    }
}
