import SwiftUI

extension Color {
    /// Parses a "#RRGGBB" hex string. Falls back to system blue on malformed input rather than
    /// crashing - this is fed persisted config data, which should never take the app down.
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("#") {
            sanitized.removeFirst()
        }
        guard sanitized.count == 6, let value = UInt32(sanitized, radix: 16) else {
            self = Color(red: 0.039, green: 0.518, blue: 1.0)
            return
        }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self = Color(red: red, green: green, blue: blue)
    }

    var hexString: String {
        let components = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(red: 0.039, green: 0.518, blue: 1.0, alpha: 1)
        let red = Int((components.redComponent * 255).rounded())
        let green = Int((components.greenComponent * 255).rounded())
        let blue = Int((components.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
