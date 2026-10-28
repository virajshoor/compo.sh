import Foundation
import CoreGraphics

public enum AppRole: String, Codable {
    case browser, terminal, document, other

    public static func classify(bundleIdentifier: String, name: String, handlesWebURLs: Bool = false) -> AppRole {
        let id = bundleIdentifier.lowercased()
        let name = name.lowercased()
        let browserIDs = ["com.apple.safari", "com.apple.safaritechnologypreview", "com.google.chrome",
                          "org.chromium.chromium", "com.microsoft.edgemac", "com.brave.browser",
                          "com.operasoftware.opera", "com.vivaldi.vivaldi", "company.thebrowser.browser",
                          "app.zen-browser.zen", "org.mozilla.firefox", "at.studio.asidebrowser"]
        if handlesWebURLs || browserIDs.contains(where: { id == $0 || id.hasPrefix($0 + ".") }) {
            return .browser
        }
        let terminalIDs = ["com.apple.terminal", "com.googlecode.iterm2", "dev.warp.warp-stable",
                           "org.alacritty", "net.kovidgoyal.kitty", "com.mitchellh.ghostty",
                           "com.github.wez.wezterm", "co.zeit.hyper", "app.crynta.terax", "com.cmuxterm.app"]
        let terminalNames = ["terminal", "iterm", "iterm2", "warp", "alacritty", "kitty", "ghostty",
                             "wezterm", "hyper", "rio", "tabby", "terax", "cmux"]
        if terminalIDs.contains(id) || terminalNames.contains(name) { return .terminal }
        if ["com.microsoft.word", "com.apple.iwork.pages", "org.libreoffice.script", "org.openoffice.script"].contains(id)
            || ["microsoft word", "pages", "libreoffice", "openoffice"].contains(name) { return .document }
        return .other
    }

}

public enum AppAwareLayout {
    /// Results retain input order so focus, swaps, and per-window state keep their identities.
    public static func frames(roles: [AppRole], in bounds: CGRect, gap: CGFloat, fallback: Layout,
                              ratio: CGFloat) -> [CGRect] {
        guard !roles.isEmpty, bounds.width > 0, bounds.height > 0 else { return [] }
        let gap = max(0, min(gap, min(bounds.width, bounds.height) / 8))
        let area = bounds.insetBy(dx: gap, dy: gap)
        if roles.count == 1 { return [area] }
        let browsers = roles.indices.filter { roles[$0] == .browser }
        let companions = roles.indices.filter { roles[$0] != .browser }
        let hasPortrait = roles.contains(.terminal) || roles.contains(.document)
        if browsers.isEmpty && !hasPortrait {
            return fallback.frames(count: roles.count, in: bounds, gap: gap, ratio: ratio)
        }
        if companions.isEmpty {
            return split(area, weights: Array(repeating: 1, count: roles.count), gap: gap, columns: false)
        }
        if browsers.isEmpty {
            return split(area, weights: Array(repeating: 1, count: roles.count), gap: gap, columns: true)
        }

        // Keep full-height companions only when their columns have usable width.
        var browserShare: CGFloat = roles.contains(.terminal) ? 0.60 : 0.50
        let companionWidth = (area.width - gap) * (1 - browserShare)
        let smallestColumn = (companionWidth - CGFloat(companions.count - 1) * gap) / CGFloat(companions.count)
        let companionColumns = hasPortrait &&
            (companions.count == 1 || smallestColumn >= min(420, area.height * 0.45))
        if companions.count > 1 && !companionColumns { browserShare = 0.50 }
        let browserFirst = browsers[0] < companions[0]
        let groups = browserFirst ? [browsers, companions] : [companions, browsers]
        let weights = browserFirst ? [browserShare, 1 - browserShare] : [1 - browserShare, browserShare]
        let groupFrames = split(area, weights: weights, gap: gap, columns: true)
        var result = Array(repeating: CGRect.zero, count: roles.count)
        for (group, frame) in zip(groups, groupFrames) {
            let columns = roles[group[0]] != .browser && companionColumns
            let panes = split(frame, weights: Array(repeating: 1, count: group.count), gap: gap, columns: columns)
            for (index, pane) in zip(group, panes) { result[index] = pane }
        }
        return result
    }

    private static func split(_ area: CGRect, weights: [CGFloat], gap: CGFloat, columns: Bool) -> [CGRect] {
        guard !weights.isEmpty else { return [] }
        let length = columns ? area.width : area.height
        let spacing = min(gap, length / CGFloat(weights.count * 2))
        let available = length - CGFloat(weights.count - 1) * spacing
        let total = weights.reduce(0, +)
        var offset: CGFloat = 0
        return weights.map { weight in
            let size = available * weight / total
            defer { offset += size + spacing }
            return columns
                ? CGRect(x: area.minX + offset, y: area.minY, width: size, height: area.height)
                : CGRect(x: area.minX, y: area.minY + offset, width: area.width, height: size)
        }
    }
}
