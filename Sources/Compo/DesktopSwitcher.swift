import AppKit
import CompoCore

final class DesktopSwitcher {
    private var queue = DesktopSwitchQueue()
    private var timer: Timer?

    func switchDesktop(right: Bool, reportError: @escaping (String) -> Void) {
        queue.append(right: right)
        drain(reportError: reportError)
    }

    private func drain(reportError: @escaping (String) -> Void) {
        guard timer == nil else { return }
        if let right = queue.take(at: ProcessInfo.processInfo.systemUptime),
           let error = performSwitch(right: right) { reportError(error) }
        guard !queue.isEmpty else { return }
        timer = Timer.scheduledTimer(withTimeInterval: queue.delay(at: ProcessInfo.processInfo.systemUptime),
                                     repeats: false) { [weak self] _ in
            guard let self else { return }
            self.timer = nil
            self.drain(reportError: reportError)
        }
    }

    deinit { timer?.invalidate() }

    private func performSwitch(right: Bool) -> String? {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        guard DesktopGesture.supported(version) else {
            return "Instant desktop switching requires macOS 26.6 or later. On older macOS, use the native Control–Left/Right shortcuts."
        }
        guard let spaces = currentDisplaySpaces() else {
            return "Could not read desktops for this display. Restart compo.sh to retry."
        }
        guard DesktopGesture.targetIndex(current: spaces.index, count: spaces.count, right: right) != nil else { return nil }
        let natural = CFPreferencesCopyAppValue("com.apple.swipescrolldirection" as CFString,
                                               kCFPreferencesAnyApplication) as? Bool ?? true
        guard let events = DesktopGesture.events(right: right, version: version, naturalScrolling: natural) else {
            return "This macOS version rejected the instant desktop gesture format. Use Control–Left/Right instead."
        }
        events.forEach { $0.post(tap: .cgSessionEventTap) }
        return nil
    }

    func currentDisplaySpaces() -> (index: Int, count: Int)? {
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
