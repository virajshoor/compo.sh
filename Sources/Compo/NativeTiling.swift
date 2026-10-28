import Foundation

/// macOS has no public tiling takeover API. Keep these preferences isolated and reversible.
final class NativeTiling {
    private let domain = "com.apple.WindowManager" as CFString
    private let keys = ["EnableTilingByEdgeDrag", "EnableTopTilingByEdgeDrag", "EnableTilingOptionAccelerator"]
    private let backupKey = "nativeTilingBackup"

    func takeOver(_ active: Bool) -> Bool {
        if #unavailable(macOS 15) { return true }
        let defaults = UserDefaults.standard
        if active && defaults.dictionary(forKey: backupKey) == nil {
            var backup: [String: Any] = [:]
            for key in keys {
                backup[key] = CFPreferencesCopyValue(key as CFString, domain,
                    kCFPreferencesCurrentUser, kCFPreferencesAnyHost) ?? "unset" as CFString
            }
            defaults.set(backup, forKey: backupKey)
        }
        let backup = defaults.dictionary(forKey: backupKey)
        guard active || backup != nil else { return true }
        for key in keys {
            let original = backup?[key]
            let value: CFPropertyList? = active ? kCFBooleanFalse
                : ((original as? String) == "unset" ? nil : original as CFPropertyList?)
            CFPreferencesSetValue(key as CFString, value, domain,
                                  kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
        let saved = CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        if saved && !active { defaults.removeObject(forKey: backupKey) }
        return saved
    }
}
