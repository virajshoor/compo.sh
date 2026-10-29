import AppKit
import CompoCore

final class DesktopSwitcher {
    private var lastSwitch = Date.distantPast

    func switchDesktop(right: Bool) -> String? {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        guard DesktopGesture.supported(version) else {
            return "Instant desktop switching requires macOS 26.6 or later. On older macOS, use the native Control–Left/Right shortcuts."
        }
        // Avoid reading stale Space state while Dock commits the preceding gesture.
        guard Date().timeIntervalSince(lastSwitch) >= 0.45 else { return nil }
        guard let spaces = currentDisplaySpaces() else {
            return "Could not read desktops for this display. Restart compo.sh to retry."
        }
        guard DesktopGesture.targetIndex(current: spaces.index, count: spaces.count, right: right) != nil else { return nil }
        let natural = CFPreferencesCopyAppValue("com.apple.swipescrolldirection" as CFString,
                                               kCFPreferencesAnyApplication) as? Bool ?? true
        guard let events = DesktopGesture.events(right: right, version: version, naturalScrolling: natural) else {
            return "This macOS version rejected the instant desktop gesture format. Use Control–Left/Right instead."
        }
        lastSwitch = Date()
        events.forEach { $0.post(tap: .cgSessionEventTap) }
        return nil
    }

    private func currentDisplaySpaces() -> (index: Int, count: Int)? {
        // shortcut: private read-only Spaces metadata; replace if Apple exposes a supported API.
        guard let library = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) else { return nil }
        defer { dlclose(library) }
        typealias Connection = @convention(c) () -> UInt32
        typealias CopySpaces = @convention(c) (UInt32) -> Unmanaged<CFArray>?
        guard let connectionSymbol = dlsym(library, "SLSMainConnectionID"),
              let spacesSymbol = dlsym(library, "SLSCopyManagedDisplaySpaces") else { return nil }
        let connection = unsafeBitCast(connectionSymbol, to: Connection.self)
        let copySpaces = unsafeBitCast(spacesSymbol, to: CopySpaces.self)
        guard let displays = copySpaces(connection())?.takeRetainedValue() as? [[String: Any]],
              let point = CGEvent(source: nil)?.location else { return nil }
        var displayID = CGDirectDisplayID(), count: UInt32 = 0
        guard CGGetDisplaysWithPoint(point, 1, &displayID, &count) == .success, count > 0,
              let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else { return nil }
        let identifier = CFUUIDCreateString(nil, uuid) as String
        guard let display = displays.first(where: { $0["Display Identifier"] as? String == identifier })
                ?? (displays.count == 1 ? displays.first : nil),
              let current = (display["Current Space"] as? [String: Any])?["id64"] as? NSNumber,
              let spaces = display["Spaces"] as? [[String: Any]] else { return nil }
        let ids = spaces.compactMap { ($0["id64"] as? NSNumber)?.uint64Value }
        guard let index = ids.firstIndex(of: current.uint64Value) else { return nil }
        return (index, ids.count)
    }
}
