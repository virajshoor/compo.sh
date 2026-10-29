import Foundation

public struct ArrangementSnapshot<Element> {
    public var frames: [(Element, CGRect)]
    public var floating: [Element]
    public var zoomed: Element?
    public init(frames: [(Element, CGRect)], floating: [Element], zoomed: Element?) {
        self.frames = frames; self.floating = floating; self.zoomed = zoomed
    }
    public func surviving(in live: [Element], equal: @escaping (Element, Element) -> Bool) -> Self {
        let exists: (Element) -> Bool = { element in live.contains { equal($0, element) } }
        return Self(frames: frames.filter { exists($0.0) && WindowPlacement.isValid($0.1) },
                    floating: floating.filter(exists), zoomed: zoomed.flatMap { exists($0) ? $0 : nil })
    }
}
