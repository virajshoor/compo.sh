import AppKit
import ApplicationServices
import Combine
import CompoCore
import ServiceManagement

final class WindowManager: ObservableObject {
    @Published var trusted = AXIsProcessTrusted()
    @Published var enabled = UserDefaults.standard.bool(forKey: "tilingEnabled") {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "tilingEnabled")
            resetPlacement(); updateNativeTiling(); schedule()
        }
    }
    @Published var layout = CompoCore.Layout(rawValue: UserDefaults.standard.string(forKey: "layout") ?? "") ?? .stack {
        didSet { UserDefaults.standard.set(layout.rawValue, forKey: "layout"); resetPlacement(); schedule() }
    }
    @Published var appAwareLayout = UserDefaults.standard.object(forKey: "appAwareLayout") as? Bool ?? true {
        didSet { UserDefaults.standard.set(appAwareLayout, forKey: "appAwareLayout"); resetPlacement(); schedule() }
    }
    @Published var gap: Double = UserDefaults.standard.object(forKey: "gap") as? Double ?? 12 {
        didSet { UserDefaults.standard.set(gap, forKey: "gap"); resetPlacement(); schedule() }
    }
    @Published var ratio: Double = UserDefaults.standard.object(forKey: "ratio") as? Double ?? 0.58 {
        didSet { UserDefaults.standard.set(ratio, forKey: "ratio"); resetPlacement(); schedule() }
    }
    @Published var snapEdges = UserDefaults.standard.object(forKey: "snapEdges") as? Bool ?? true {
        didSet { UserDefaults.standard.set(snapEdges, forKey: "snapEdges"); updateNativeTiling(); cancelDrag(); schedule() }
    }
    @Published var dragSwap = UserDefaults.standard.object(forKey: "dragSwap") as? Bool ?? true {
        didSet { UserDefaults.standard.set(dragSwap, forKey: "dragSwap"); cancelDrag(); schedule() }
    }
    @Published var disableAnimations = UserDefaults.standard.object(forKey: "disableAnimations") as? Bool ?? true {
        didSet { UserDefaults.standard.set(disableAnimations, forKey: "disableAnimations") }
    }
    @Published var edgeDistance = UserDefaults.standard.object(forKey: "edgeDistance") as? Double ?? 24 {
        didSet { UserDefaults.standard.set(edgeDistance, forKey: "edgeDistance") }
    }
    @Published var windowCount = 0
    @Published var floatingCount = 0
    @Published var message: String?
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    @Published var loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval

    private var windows: [ManagedWindow] = []
    private var floating: [AXUIElement] = []
    private var observers: [pid_t: AXObserver] = [:]
    private var workspaceTokens: [NSObjectProtocol] = []
    private var screenToken: NSObjectProtocol?
    private var permissionTimer: Timer?
    private var pending: DispatchWorkItem?
    private var verification: DispatchWorkItem?
    private var recoveryBudget = 3
    private var applyingFrames = false
    private var lastPlacement = Date.distantPast
    private var sizeLimits: [(AXUIElement, CGSize)] = []
    private var requestedFrames: [(AXUIElement, CGRect)] = []
    private var missingSamples: [(AXUIElement, Int)] = []
    private var hotkeys: Hotkeys?
    private var zoomed: AXUIElement?

    private let nativeTiling = NativeTiling()
    private var rules = AppRules(apps: [:])
    private var appRoles: [pid_t: AppRole] = [:]
    private var ruleFloats: [AXUIElement] = []
    private var dragController: DragController?
    private var dragWindow: AXUIElement?
    private var dragOriginal = CGRect.zero
    private var dragPointerStart = CGPoint.zero
    private var hasDragged = false
    private var dragFrames: [(AXUIElement, CGRect)] = []
    private var dropFrames: [(AXUIElement, CGRect)] = []
    private var manualFrames: [(AXUIElement, CGRect)] = []
    private var animation: Timer?
    private var lastDragUpdate = Date.distantPast

    func start() {
        if !trusted { enabled = false }
        reloadRules()
        updateNativeTiling()
        dragController = DragController { [weak self] type, point in self?.drag(type, point: point) }
        hotkeys = Hotkeys { [weak self] action in self?.perform(action) }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification,
                     NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didWakeNotification] {
            workspaceTokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.resetPlacement()
                self?.schedule()
            })
        }
        screenToken = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                             object: nil, queue: .main) { [weak self] _ in self?.resetPlacement(); self?.schedule() }
        workspaceTokens.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                  object: nil, queue: .main) { [weak self] _ in self?.schedule() })
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            let allowed = AXIsProcessTrusted()
            if self.trusted != allowed {
                self.trusted = allowed
                self.updateNativeTiling()
                self.schedule()
            }
            self.loginEnabled = SMAppService.mainApp.status == .enabled
            self.loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
            if self.dragWindow != nil && NSEvent.pressedMouseButtons & 1 == 0 {
                self.cancelDrag(); self.schedule()
            }
        }
        if let error = hotkeys?.error { message = error }
        schedule()
    }

    func stop() {
        animation?.invalidate()
        dragController?.stop()
        _ = nativeTiling.takeOver(false)
        pending?.cancel()
        verification?.cancel()
        permissionTimer?.invalidate()
        workspaceTokens.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        if let screenToken { NotificationCenter.default.removeObserver(screenToken) }
        for observer in observers.values {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observers.removeAll()
        hotkeys = nil
    }

    func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            message = "In Accessibility settings, enable compo. If it is missing, use + to add /Applications/compo.sh.app. Return here after granting access."
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            if !NSWorkspace.shared.open(url) {
                message = "Open System Settings → Privacy & Security → Accessibility, then enable compo. Use + to add /Applications/compo.sh.app if needed."
            }
        }
    }

    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
            if loginNeedsApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch {
            message = "Couldn’t change launch at login: \(error.localizedDescription)"
            loginEnabled = SMAppService.mainApp.status == .enabled
        }
    }

    func schedule(recover: Bool = true) {
        if recover { recoveryBudget = 3 }
        guard pending == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.pending = nil
            self?.refresh()
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func observe(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard observers[pid] == nil else { return }
        var observer: AXObserver?
        let callback: AXObserverCallback = { _, element, name, context in
            guard let context else { return }
            let manager = Unmanaged<WindowManager>.fromOpaque(context).takeUnretainedValue()
            manager.windowEvent(element, name: name as String)
        }
        guard AXObserverCreate(pid, callback, &observer) == .success, let observer else { return }
        observers[pid] = observer
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        let element = AXUIElementCreateApplication(pid)
        let context = Unmanaged.passUnretained(self).toOpaque()
        for name in [kAXWindowCreatedNotification, kAXUIElementDestroyedNotification,
                     kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification,
                     kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification] {
            AXObserverAddNotification(observer, element, name as CFString, context)
        }
    }

    private func windowEvent(_ element: AXUIElement, name: String) {
        if name == kAXWindowMovedNotification || name == kAXWindowResizedNotification {
            guard enabled, !applyingFrames, dragWindow == nil, animation == nil,
                  let known = windows.first(where: { CFEqual($0.element, element) }), !isFloating(element),
                  let frame = AX.frame(element), !WindowPlacement.matches(frame, known.frame) else { return }
            let recentWrite = Date().timeIntervalSince(lastPlacement) < 1
            guard !recentWrite || recoveryBudget > 0 else { return }
            schedule(recover: !recentWrite)
        } else { schedule() }
    }

    private func verifyPlacement() {
        guard enabled, recoveryBudget > 0, verification == nil else { return }
        recoveryBudget -= 1
        let work = DispatchWorkItem { [weak self] in
            self?.verification = nil
            self?.schedule(recover: false)
        }
        verification = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func refresh() {
        guard dragWindow == nil, animation == nil else { return }
        guard trusted else { windows = []; windowCount = 0; return }
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
        let livePids = Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier))
        appRoles = appRoles.filter { livePids.contains($0.key) }
        for pid in Array(observers.keys) where !livePids.contains(pid) {
            if let observer = observers.removeValue(forKey: pid) {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            }
        }
        // Public WindowServer metadata limits management to windows visible in the current Spaces.
        // No screen image capture or Screen Recording permission is used.
        guard let visible = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] else { verifyPlacement(); return }
        var discovered: [ManagedWindow] = []
        var allElements: [AXUIElement] = []
        ruleFloats = []
        for app in apps {
            let pid = app.processIdentifier
            let visibleFrames = visible.compactMap { info -> CGRect? in
                guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                      (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                      let bounds = info[kCGWindowBounds as String] as? [String: Any] else { return nil }
                return CGRect(dictionaryRepresentation: bounds as CFDictionary)
            }
            if appRoles[pid] == nil {
                let urlTypes = app.bundleURL.flatMap { Bundle(url: $0) }?
                    .object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
                let schemes = Set(urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }.map { $0.lowercased() })
                appRoles[pid] = AppRole.classify(bundleIdentifier: app.bundleIdentifier ?? "", name: app.localizedName ?? "",
                    handlesWebURLs: schemes.contains("http") && schemes.contains("https"))
            }
            let rule = rules.apps[app.bundleIdentifier ?? ""]
            let role = rule?.role ?? appRoles[pid] ?? .other
            let element = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(element, 0.15)
            observe(app)
            guard let appWindows = AX.value(element, kAXWindowsAttribute) as? [AXUIElement] else {
                if !app.isHidden {
                    let retained = windows.filter { old in
                        old.pid == pid && WindowPlacement.visible(old.frame, previous: nil,
                            targets: requestedFrames.filter { CFEqual($0.0, old.element) }.map(\.1), among: visibleFrames)
                    }
                    // A transient AX timeout must not erase the entire application's layout state.
                    discovered += retained
                    allElements += retained.map(\.element)
                    if rule?.floating == true { ruleFloats += retained.map(\.element) }
                }
                verifyPlacement()
                continue
            }
            allElements += appWindows
            guard !app.isHidden else { continue }
            for window in appWindows {
                AXUIElementSetMessagingTimeout(window, 0.15)
                guard AX.value(window, kAXSubroleAttribute) as? String == kAXStandardWindowSubrole,
                      AX.value(window, kAXMinimizedAttribute) as? Bool != true,
                      AX.value(window, "AXFullScreen") as? Bool != true,
                      AX.writable(window, kAXPositionAttribute), AX.writable(window, kAXSizeAttribute) else { continue }
                guard let frame = AX.frame(window), frame.width > 80, frame.height > 60 else {
                    if let old = windows.first(where: { CFEqual($0.element, window) }),
                       visibleFrames.contains(where: { WindowPlacement.matches($0, old.frame, tolerance: 3) }) {
                        discovered.append(old)
                        if rule?.floating == true { ruleFloats.append(window) }
                        verifyPlacement()
                    }
                    continue
                }
                let old = windows.first { CFEqual($0.element, window) }
                let targets = requestedFrames.filter { CFEqual($0.0, window) }.map(\.1)
                // Read settled geometry, not an application's asynchronous resize response.
                if Date().timeIntervalSince(lastPlacement) >= 0.2, let requested = targets.first {
                    let previous = sizeLimits.first { CFEqual($0.0, window) }?.1 ?? .zero
                    let minimum = WindowPlacement.minimumSize(requested: requested, actual: frame, previous: previous)
                    sizeLimits.removeAll { CFEqual($0.0, window) }
                    sizeLimits.append((window, minimum))
                }
                let onScreen = WindowPlacement.visible(frame, previous: old?.frame, targets: targets, among: visibleFrames)
                if !onScreen {
                    let misses = missingSamples.first { CFEqual($0.0, window) }?.1 ?? 0
                    missingSamples.removeAll { CFEqual($0.0, window) }
                    missingSamples.append((window, misses + 1))
                    guard old != nil, misses < 2 else { continue }
                    verifyPlacement()
                } else { missingSamples.removeAll { CFEqual($0.0, window) } }
                if let observer = observers[app.processIdentifier] {
                    let context = Unmanaged.passUnretained(self).toOpaque()
                    for name in [kAXUIElementDestroyedNotification, kAXWindowMiniaturizedNotification,
                                 kAXWindowDeminiaturizedNotification, kAXWindowMovedNotification, kAXWindowResizedNotification] {
                        AXObserverAddNotification(observer, window, name as CFString, context)
                    }
                }
                if rule?.floating == true { ruleFloats.append(window) }
                discovered.append(ManagedWindow(element: window, pid: app.processIdentifier, role: role, frame: frame))
            }
        }
        floating.removeAll { old in !allElements.contains { CFEqual($0, old) } }
        sizeLimits.removeAll { old in !allElements.contains { CFEqual($0, old.0) } }
        requestedFrames.removeAll { old in !allElements.contains { CFEqual($0, old.0) } }
        missingSamples.removeAll { old in !allElements.contains { CFEqual($0, old.0) } }
        floatingCount = windows.filter { isFloating($0.element) }.count
        // Preserve user order through app launches, closes, and swaps.
        var ordered = windows.compactMap { old in discovered.first { CFEqual($0.element, old.element) } }
        ordered += discovered.filter { candidate in !ordered.contains { CFEqual($0.element, candidate.element) } }
        if ordered.count != windows.count || ordered.contains(where: { candidate in
            !windows.contains { CFEqual($0.element, candidate.element) }
        }) { manualFrames = []; zoomed = nil }
        windows = ordered
        floatingCount = windows.filter { isFloating($0.element) }.count
        windowCount = windows.count
        guard enabled else { return }
        tile()
    }

    private var displays: [CGRect] {
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        return NSScreen.screens.map { screen in
            let frame = screen.visibleFrame
            return CGRect(x: frame.minX, y: top - frame.maxY, width: frame.width, height: frame.height)
        }
    }

    private func displayIndex(for frame: CGRect, in screens: [CGRect]) -> Int? {
        WindowPlacement.displayIndex(for: frame, in: screens)
    }

    private func tile(animated: Bool = false) {
        let screens = displays
        var targets: [(AXUIElement, CGRect)] = []
        for (index, screen) in screens.enumerated() {
            let group = windows.indices.filter { i in
                !isFloating(windows[i].element)
                    && displayIndex(for: windows[i].frame, in: screens) == index
            }
            let frames = appAwareLayout
                ? AppAwareLayout.frames(roles: group.map { windows[$0].role }, in: screen,
                                        gap: gap, fallback: layout, ratio: ratio)
                : layout.frames(count: group.count, in: screen, gap: gap, ratio: ratio)
            if let zoomed, group.contains(where: { CFEqual(windows[$0].element, zoomed) }) {
                targets.append((zoomed, screen.insetBy(dx: gap, dy: gap)))
                continue
            }
            let preferred = zip(group, frames).map { i, target in
                manualFrames.first { CFEqual($0.0, windows[i].element) }?.1 ?? target
            }
            let minimums = group.map { i in sizeLimits.first { CFEqual($0.0, windows[i].element) }?.1 ?? .zero }
            guard let fitted = FittingLayout.frames(preferred: preferred, minimums: minimums, in: screen, gap: gap) else {
                message = "These windows cannot fit on this display at their minimum sizes. Float a window, close one, or use a larger display. Retile Now retries size limits."
                continue
            }
            targets += zip(group, fitted).map { (windows[$0.0].element, $0.1) }
        }
        move(targets, animated: animated)
    }

    func perform(_ action: HotkeyAction) {
        if action == .toggle { enabled.toggle(); return }
        guard trusted, enabled else { return }
        if action == .retile { resetPlacement(); schedule(); return }
        if action == .cycle {
            appAwareLayout = false
            let layouts = CompoCore.Layout.allCases
            layout = layouts[(layouts.firstIndex(of: layout)! + 1) % layouts.count]
            return
        }
        guard let focused = AX.focusedWindow(),
              let index = windows.firstIndex(where: { CFEqual($0.element, focused) }) else { return }
        switch action {
        case .float:
            resetPlacement()
            if let i = floating.firstIndex(where: { CFEqual($0, focused) }) { floating.remove(at: i) }
            else { floating.append(focused) }
            floatingCount = windows.filter { isFloating($0.element) }.count
            schedule()
        case .zoom:
            guard !isFloating(focused) else { return }
            zoomed = zoomed.map { CFEqual($0, focused) } == true ? nil : focused
            tile()
            AX.focus(focused)
        case .focus(let direction), .swap(let direction):
            let frames = windows.map { AX.frame($0.element) ?? $0.frame }
            guard let next = direction.neighbor(from: frames[index], among: frames) else { return }
            if case .swap = action {
                guard !isFloating(focused), !isFloating(windows[next].element) else { return }
                zoomed = nil
                manualFrames = windows.filter { !isFloating($0.element) }.map { ($0.element, AX.frame($0.element) ?? $0.frame) }
                let other = windows[next].element
                manualFrames = manualFrames.map { element, frame in
                    (element, CFEqual(element, focused) ? frames[next] : CFEqual(element, other) ? frames[index] : frame)
                }
                assignDisplays(manualFrames)
                tile(animated: true)
                AX.focus(focused)
            } else { AX.focus(windows[next].element) }
        default: break
        }
    }
    func reloadRules() {
        do { rules = try AppRules.load(); resetPlacement(); schedule() }
        catch { message = "Couldn’t load app rules: \(error.localizedDescription). Previous rules kept." }
    }

    func editRules() {
        do { try AppRules.open() }
        catch { message = "Couldn’t open app rules: \(error.localizedDescription)" }
    }

    private func isFloating(_ element: AXUIElement) -> Bool {
        (floating + ruleFloats).contains { CFEqual($0, element) }
    }

    private func updateNativeTiling() {
        if !nativeTiling.takeOver(enabled && trusted && snapEdges) {
            message = "Couldn’t update macOS tiling preferences. In System Settings → Desktop & Dock, turn off edge, menu-bar and Option-drag tiling while Snap Edges is enabled."
        }
    }

    private func resetPlacement() {
        zoomed = nil
        manualFrames = []
        sizeLimits = []; requestedFrames = []; missingSamples = []
        verification?.cancel(); verification = nil
        animation?.invalidate(); animation = nil
        cancelDrag()
    }

    private func cancelDrag() {
        dragWindow = nil
        hasDragged = false
        dragFrames = []; dropFrames = []
        dragController?.show(nil)
    }

    private func drag(_ type: NSEvent.EventType, point: CGPoint) {
        guard enabled, trusted else { cancelDrag(); return }
        if type == .leftMouseDown {
            guard animation == nil else { return }
            cancelDrag()
            var hit: AXUIElement?
            guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &hit) == .success,
                  let hit else { return }
            let window: AXUIElement
            if AX.value(hit, kAXRoleAttribute) as? String == kAXWindowRole { window = hit }
            else if let value = AX.value(hit, kAXWindowAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() {
                window = value as! AXUIElement
            } else { return }
            guard windows.contains(where: { CFEqual($0.element, window) }), !isFloating(window),
                  let frame = AX.frame(window) else { return }
            dragWindow = window; dragOriginal = frame
            dragPointerStart = point
            dragFrames = windows.filter { !isFloating($0.element) }.map { ($0.element, AX.frame($0.element) ?? $0.frame) }
            pending?.cancel()
            pending = nil
            return
        }
        guard let window = dragWindow else { return }
        guard snapEdges || dragSwap else {
            if type == .leftMouseUp { cancelDrag(); schedule() }
            return
        }
        if type == .leftMouseDragged || type == .leftMouseUp {
            if type == .leftMouseDragged { hasDragged = true }
            // One AX read per display frame at most; ignore content drags and live resizing.
            if type == .leftMouseDragged && Date().timeIntervalSince(lastDragUpdate) < 1.0 / 30 { return }
            lastDragUpdate = Date()
            guard let frame = AX.frame(window),
                  WindowDrag.isMove(original: dragOriginal, current: frame, pointerStart: dragPointerStart,
                                    pointer: point, hasDragged: hasDragged) else {
                dropFrames = []; dragController?.show(nil)
                if type == .leftMouseUp { cancelDrag(); schedule() }
                return
            }
            dropFrames = []
            let top = NSScreen.screens.first?.frame.maxY ?? 0
            let screen = NSScreen.screens.first { screen in
                CGRect(x: screen.frame.minX, y: top - screen.frame.maxY,
                       width: screen.frame.width, height: screen.frame.height).contains(point)
            }
            var preview: CGRect?
            var swapping = false
            var filling = false
            if snapEdges, let screen {
                let full = CGRect(x: screen.frame.minX, y: top - screen.frame.maxY,
                                  width: screen.frame.width, height: screen.frame.height)
                let visible = CGRect(x: screen.visibleFrame.minX, y: top - screen.visibleFrame.maxY,
                                     width: screen.visibleFrame.width, height: screen.visibleFrame.height)
                if let zone = SnapZone.detect(point: point, screen: full, threshold: edgeDistance) {
                    filling = zone == .top
                    let target = zone.frame(in: visible, gap: gap)
                    preview = target
                    dropFrames = [(window, target)]
                    if let remainder = zone.remainder(in: visible, gap: gap) {
                        let others = dragFrames.filter { !CFEqual($0.0, window) && visible.intersects($0.1) }
                        let panes = layout.frames(count: others.count, in: remainder.insetBy(dx: -gap, dy: -gap), gap: gap, ratio: ratio)
                        dropFrames += zip(others, panes).map { ($0.0.0, $0.1) }
                    }
                }
            }
            if preview == nil, dragSwap,
               let other = dragFrames.first(where: { !CFEqual($0.0, window) && $0.1.insetBy(dx: 12, dy: 12).contains(point) }) {
                preview = other.1; swapping = true
                dropFrames = [(window, other.1), (other.0, dragOriginal)]
            }
            dragController?.show(preview, swapping: swapping)
            if type == .leftMouseUp {
                let targets = dropFrames
                let original = dragFrames
                cancelDrag()
                if !targets.isEmpty {
                    zoomed = nil
                    manualFrames = original.map { element, frame in
                        (element, targets.first { CFEqual($0.0, element) }?.1 ?? frame)
                    }
                    if filling { zoomed = window }
                    assignDisplays(targets)
                    tile(animated: swapping)
                } else { schedule() }
            }
        }
    }

    private func move(_ targets: [(AXUIElement, CGRect)], animated: Bool = true) {
        animation?.invalidate(); animation = nil
        let starts = targets.map { AX.frame($0.0) ?? $0.1 }
        let moving = targets.enumerated().filter { !WindowPlacement.matches(starts[$0.offset], $0.element.1) }
        guard !moving.isEmpty else { return }
        guard animated, !disableAnimations, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            for (_, target) in moving { place(target.0, at: target.1) }
            verifyPlacement(); return
        }
        let began = Date()
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let progress = min(1, Date().timeIntervalSince(began) / 0.16)
            let eased = 1 - pow(1 - progress, 3)
            for (index, target) in moving {
                let start = starts[index], end = target.1
                let frame = CGRect(x: start.minX + (end.minX - start.minX) * eased,
                                   y: start.minY + (end.minY - start.minY) * eased,
                                   width: start.width + (end.width - start.width) * eased,
                                   height: start.height + (end.height - start.height) * eased)
                self.place(target.0, at: frame, remember: false)
            }
            if progress >= 1 {
                timer.invalidate(); self.animation = nil
                for (_, target) in moving { self.place(target.0, at: target.1) }
                self.verifyPlacement()
            }
        }
        animation = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func assignDisplays(_ targets: [(AXUIElement, CGRect)]) {
        for (element, frame) in targets {
            if let index = windows.firstIndex(where: { CFEqual($0.element, element) }) { windows[index].frame = frame }
        }
    }

    private func place(_ element: AXUIElement, at target: CGRect, remember: Bool = true) {
        applyingFrames = true
        defer { applyingFrames = false }
        let before = AX.frame(element)
        if before.map({ !WindowPlacement.matches($0, target) }) ?? true { lastPlacement = Date() }
        let succeeded = AX.setFrame(element, target)
        if remember {
            requestedFrames.removeAll { CFEqual($0.0, element) }
            if succeeded { requestedFrames.append((element, target)) }
        }
        guard let actual = AX.frame(element) else { return }
        if let index = windows.firstIndex(where: { CFEqual($0.element, element) }) { windows[index].frame = actual }
        if !succeeded {
            message = "An app rejected a window position or size update. compo.sh retries briefly; use Retile Now or float the window if it persists."
        }
    }

}
