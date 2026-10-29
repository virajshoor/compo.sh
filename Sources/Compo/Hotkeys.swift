import Carbon
import CompoCore

enum HotkeyAction: Equatable {
    case desktop(Bool), focus(Direction), swap(Direction), cycle, float, zoom, toggle, retile, undo
}

final class Hotkeys {
    private var handler: EventHandlerRef?
    private var references: [EventHotKeyRef] = []
    private let callback: (HotkeyAction) -> Void
    private var actions: [UInt32: HotkeyAction] = [:]
    private var desktopPress = HotkeyPress()
    private(set) var error: String?
    private let signature: OSType = 0x434F4D50 // COMP

    init(callback: @escaping (HotkeyAction) -> Void) {
        self.callback = callback
        var events = [kEventHotKeyPressed, kEventHotKeyReleased].map {
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32($0))
        }
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let keys = Unmanaged<Hotkeys>.fromOpaque(context).takeUnretainedValue()
            var id = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                          EventParamType(typeEventHotKeyID), nil,
                                          MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard result == noErr, id.signature == keys.signature,
                  let action = keys.actions[id.id] else { return OSStatus(eventNotHandledErr) }
            let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
            if case .desktop = action {
                guard keys.desktopPress.update(id: id.id, isPressed: pressed) else { return noErr }
            } else if !pressed { return noErr }
            keys.callback(action)
            return noErr
        }, events.count, &events, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { error = "Couldn’t install keyboard shortcuts (\(status)). Restart compo to retry."; return }
        apply(ShortcutBinding.defaults)
    }

    @discardableResult
    func apply(_ bindings: [ShortcutBinding]) -> Bool {
        do { try ShortcutBinding.validate(bindings) }
        catch { self.error = error.localizedDescription; return false }
        let previous = activeBindings
        unregister()
        error = nil
        if register(bindings) { activeBindings = bindings; return true }
        let failure = error
        unregister()
        _ = register(previous)
        activeBindings = previous
        error = failure
        return false
    }

    private var activeBindings: [ShortcutBinding] = []
    private func unregister() {
        references.forEach { UnregisterEventHotKey($0) }
        references = []; actions = [:]; desktopPress = HotkeyPress()
    }

    private func register(_ bindings: [ShortcutBinding]) -> Bool {
        for binding in bindings where binding.enabled {
            guard let key = Self.codes[binding.key], let action = Self.action(binding.action) else { return false }
            let id = UInt32(actions.count + 1)
            var reference: EventHotKeyRef?
            let flags: [String: Int] = ["control": controlKey, "option": optionKey, "command": cmdKey, "shift": shiftKey]
            let modifiers = binding.modifiers.reduce(UInt32(0)) { $0 | UInt32(flags[$1] ?? 0) }
            let result = RegisterEventHotKey(UInt32(key), modifiers, EventHotKeyID(signature: signature, id: id),
                                            GetApplicationEventTarget(), 0, &reference)
            guard result == noErr, let reference else {
                error = "Shortcut \(binding.display) (\(binding.action)) is unavailable (\(result)). Change or disable it in Edit Shortcuts, then Reload Shortcuts. Previous working bindings kept."
                return false
            }
            actions[id] = action; references.append(reference)
        }
        return true
    }

    private static func action(_ name: String) -> HotkeyAction? {
        let parts = name.split(separator: ".")
        let directions: [String: Direction] = ["left": .left, "right": .right, "up": .up, "down": .down]
        if parts.count == 2, let direction = directions[String(parts[1])] {
            if parts[0] == "focus" { return .focus(direction) }
            if parts[0] == "swap" { return .swap(direction) }
            if parts[0] == "desktop" { return .desktop(parts[1] == "right") }
        }
        return ["cycle": .cycle, "float": .float, "zoom": .zoom, "toggle": .toggle, "retile": .retile, "undo": .undo][name]
    }

    private static let codes: [String: Int] = [
        "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
        "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
        "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
        "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
        "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
        "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
        "y": kVK_ANSI_Y, "z": kVK_ANSI_Z, "0": kVK_ANSI_0, "1": kVK_ANSI_1,
        "2": kVK_ANSI_2, "3": kVK_ANSI_3, "4": kVK_ANSI_4, "5": kVK_ANSI_5,
        "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8, "9": kVK_ANSI_9,
        "left": kVK_LeftArrow, "right": kVK_RightArrow, "up": kVK_UpArrow,
        "down": kVK_DownArrow, "space": kVK_Space, "return": kVK_Return, "escape": kVK_Escape]

    deinit {
        references.forEach { UnregisterEventHotKey($0) }
        if let handler { RemoveEventHandler(handler) }
    }
}
