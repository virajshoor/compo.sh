import AppKit
import CompoCore

struct AppRule: Codable {
    var role: AppRole?
    var floating: Bool?
}

struct AppRules: Codable {
    var apps: [String: AppRule]
    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("compo/config.json")
    }
    static func load() throws -> AppRules {
        guard FileManager.default.fileExists(atPath: url.path) else { return AppRules(apps: [:]) }
        guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 262_144 else {
            throw NSError(domain: "compo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Rules file must be smaller than 256 KB."])
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AppRules.self, from: data)
    }
    static func open() throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let sample = AppRules(apps: ["com.apple.Safari": AppRule(role: .browser),
                                       "com.apple.Terminal": AppRule(role: .terminal),
                                       "com.apple.calculator": AppRule(floating: true)])
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(sample).write(to: url, options: .atomic)
        }
        NSWorkspace.shared.open(url)
    }
}
