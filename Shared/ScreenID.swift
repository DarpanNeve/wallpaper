import AppKit

extension NSScreen {
    var stableID: String {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return "unknown-\(ObjectIdentifier(self).hashValue)"
        }
        return String(number)
    }

    var displayName: String {
        localizedName
    }
}
