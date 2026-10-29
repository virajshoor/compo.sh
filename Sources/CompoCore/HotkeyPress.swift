public struct HotkeyPress {
    private var held: Set<UInt32> = []

    public init() {}

    /// Accept one action per press, regardless of keyboard repeat rate.
    public mutating func update(id: UInt32, isPressed: Bool) -> Bool {
        if isPressed { return held.insert(id).inserted }
        held.remove(id)
        return false
    }
}
