import Foundation

public struct ShortcutBinding: Codable, Identifiable, Equatable {
    public var action: String
    public var key: String
    public var modifiers: [String]
    public var enabled: Bool
    public var id: String { action }
    public init(_ action: String, _ key: String, _ modifiers: [String] = ["control", "option"], enabled: Bool = true) {
        self.action = action; self.key = key; self.modifiers = modifiers; self.enabled = enabled
    }
    public static let defaults: [Self] = ["left", "right", "up", "down"].flatMap {
        [Self("focus.\($0)", $0), Self("swap.\($0)", $0, ["control", "option", "shift"])]
    } + [Self("desktop.left", "left", ["control", "option", "command"]),
         Self("desktop.right", "right", ["control", "option", "command"]),
         Self("cycle", "l"), Self("float", "space"), Self("zoom", "return"),
         Self("toggle", "p"), Self("retile", "r"), Self("undo", "z")]

    public static let keys = Set(Array("abcdefghijklmnopqrstuvwxyz0123456789").map(String.init)
        + ["left", "right", "up", "down", "space", "return", "escape"])

    public static func validate(_ bindings: [Self]) throws {
        let actions = Set(defaults.map(\.action))
        guard bindings.count == actions.count, Set(bindings.map(\.action)) == actions else {
            throw SettingsError.invalid("Keep exactly one entry for every action; use enabled: false to disable one.")
        }
        var chords = Set<String>()
        for binding in bindings {
            let modifiers = Set(binding.modifiers)
            guard keys.contains(binding.key), modifiers.count == binding.modifiers.count,
                  modifiers.isSubset(of: ["control", "option", "command", "shift"]),
                  !binding.enabled || !modifiers.intersection(["control", "option", "command"]).isEmpty else {
                throw SettingsError.invalid("Invalid shortcut for \(binding.action). Use a supported key and Control, Option or Command.")
            }
            if binding.enabled && !chords.insert(binding.modifiers.sorted().joined(separator: "+") + ":" + binding.key).inserted {
                throw SettingsError.invalid("Duplicate shortcut: \(binding.display). Previous shortcuts kept.")
            }
        }
    }

    public var display: String {
        guard enabled else { return "Disabled" }
        let symbols = [("control", "⌃"), ("option", "⌥"), ("shift", "⇧"), ("command", "⌘")]
        let keyLabel = ["left": "←", "right": "→", "up": "↑", "down": "↓", "space": "Space", "return": "Return", "escape": "Esc"][key] ?? key.uppercased()
        return symbols.filter { modifiers.contains($0.0) }.map(\.1).joined() + " " + keyLabel
    }
}
