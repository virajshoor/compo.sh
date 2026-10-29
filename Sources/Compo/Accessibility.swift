import AppKit
import ApplicationServices
import CompoCore

enum AX {
    static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    static func frame(_ window: AXUIElement) -> CGRect? {
        guard let p = value(window, kAXPositionAttribute), CFGetTypeID(p) == AXValueGetTypeID(),
              let s = value(window, kAXSizeAttribute), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &point),
              AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        let frame = CGRect(origin: point, size: size)
        return WindowPlacement.isValid(frame) ? frame : nil
    }

    static func setFrame(_ window: AXUIElement, _ frame: CGRect) -> Bool {
        WindowPlacement.apply(frame, read: { self.frame(window) }, resize: { size in
            var size = size
            guard let value = AXValueCreate(.cgSize, &size) else { return false }
            return AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value) == .success
        }, move: { point in
            var point = point
            guard let value = AXValueCreate(.cgPoint, &point) else { return false }
            return AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value) == .success
        })
    }

    static func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let value = value(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedWindowAttribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    static func focus(_ window: AXUIElement) {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        NSRunningApplication(processIdentifier: pid)?.activate(options: [.activateIgnoringOtherApps])
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    static func writable(_ window: AXUIElement, _ attribute: String) -> Bool {
        var settable: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(window, attribute as CFString, &settable) == .success && settable.boolValue
    }
}

struct ManagedWindow {
    let element: AXUIElement
    let pid: pid_t
    let role: AppRole
    var frame: CGRect
}
