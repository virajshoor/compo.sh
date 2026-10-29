import Foundation

public struct Workspace: Codable, Identifiable {
    public var id: UUID
    public var name: String
    public var windows: [Pane]
    public struct Pane: Codable {
        public var bundle: String
        public var ordinal: Int
        public var display: String
        public var fallbackDisplay: Int
        public var rect: CGRect
        public var floating: Bool
        public init(bundle: String, ordinal: Int, display: String, fallbackDisplay: Int, rect: CGRect, floating: Bool) {
            self.bundle = bundle; self.ordinal = ordinal; self.display = display
            self.fallbackDisplay = fallbackDisplay; self.rect = rect; self.floating = floating
        }
    }
    public init(name: String, windows: [Pane]) { id = UUID(); self.name = name; self.windows = windows }

    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 80,
              !windows.isEmpty, windows.count <= 128 else { throw SettingsError.invalid("Workspace needs a name (1–80 characters) and 1–128 windows.") }
        var identities = Set<String>()
        for pane in windows {
            guard !pane.bundle.isEmpty, pane.bundle.count <= 255, pane.ordinal >= 0, pane.ordinal < 128,
                  pane.fallbackDisplay >= 0, pane.fallbackDisplay < 64, pane.display.count <= 100,
                  WindowPlacement.isValid(pane.rect), pane.rect.minX >= 0, pane.rect.minY >= 0,
                  pane.rect.maxX <= 1.001, pane.rect.maxY <= 1.001,
                  identities.insert("\(pane.bundle):\(pane.ordinal)").inserted else {
                throw SettingsError.invalid("Workspace contains invalid or duplicate panes.")
            }
        }
    }

    public static func normalized(_ frame: CGRect, in screen: CGRect) -> CGRect {
        let clipped = frame.intersection(screen)
        guard WindowPlacement.isValid(clipped), WindowPlacement.isValid(screen) else { return .zero }
        return CGRect(x: (clipped.minX - screen.minX) / screen.width,
                      y: (clipped.minY - screen.minY) / screen.height,
                      width: clipped.width / screen.width, height: clipped.height / screen.height)
    }

    public static func restored(_ pane: Pane, screens: [(String, CGRect)]) -> CGRect? {
        guard !screens.isEmpty, WindowPlacement.isValid(pane.rect), pane.rect.minX >= 0,
              pane.rect.minY >= 0, pane.rect.maxX <= 1.001, pane.rect.maxY <= 1.001 else { return nil }
        let index = screens.firstIndex { $0.0 == pane.display } ?? min(max(0, pane.fallbackDisplay), screens.count - 1)
        let screen = screens[index].1
        guard WindowPlacement.isValid(screen) else { return nil }
        return CGRect(x: screen.minX + pane.rect.minX * screen.width,
                      y: screen.minY + pane.rect.minY * screen.height,
                      width: pane.rect.width * screen.width, height: pane.rect.height * screen.height)
    }
}

public enum SettingsError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}
