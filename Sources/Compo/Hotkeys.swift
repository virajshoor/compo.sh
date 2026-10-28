import Carbon
import CompoCore

enum HotkeyAction: Equatable {
    case focus(Direction), swap(Direction), cycle, float, zoom, toggle, retile
}

final class Hotkeys {
    private var handler: EventHandlerRef?
    private var references: [EventHotKeyRef] = []
    private let callback: (HotkeyAction) -> Void
    private var actions: [UInt32: HotkeyAction] = [:]
    private(set) var error: String?
    private let signature: OSType = 0x434F4D50 // COMP

    init(callback: @escaping (HotkeyAction) -> Void) {
        self.callback = callback
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let keys = Unmanaged<Hotkeys>.fromOpaque(context).takeUnretainedValue()
            var id = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                          EventParamType(typeEventHotKeyID), nil,
                                          MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard result == noErr, id.signature == keys.signature,
                  let action = keys.actions[id.id] else { return OSStatus(eventNotHandledErr) }
            keys.callback(action)
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { error = "Couldn’t install keyboard shortcuts (\(status)). Restart compo to retry."; return }
        let modifiers = UInt32(controlKey | optionKey)
        let directions: [(Int, Direction)] = [(kVK_LeftArrow, .left), (kVK_RightArrow, .right),
                                               (kVK_UpArrow, .up), (kVK_DownArrow, .down)]
        for (key, direction) in directions {
            register(key, modifiers, .focus(direction))
            register(key, modifiers | UInt32(shiftKey), .swap(direction))
        }
        register(kVK_ANSI_L, modifiers, .cycle)
        register(kVK_Space, modifiers, .float)
        register(kVK_Return, modifiers, .zoom)
        register(kVK_ANSI_P, modifiers, .toggle)
        register(kVK_ANSI_R, modifiers, .retile)
    }

    private func register(_ key: Int, _ modifiers: UInt32, _ action: HotkeyAction) {
        let id = UInt32(actions.count + 1)
        var reference: EventHotKeyRef?
        let result = RegisterEventHotKey(UInt32(key), modifiers, EventHotKeyID(signature: signature, id: id),
                                        GetApplicationEventTarget(), 0, &reference)
        if result == noErr, let reference {
            actions[id] = action
            references.append(reference)
        } else {
            error = "A shortcut is already in use (\(result)). Disable conflicting Control–Option shortcuts in other apps, then restart compo."
        }
    }

    deinit {
        references.forEach { UnregisterEventHotKey($0) }
        if let handler { RemoveEventHandler(handler) }
    }
}
