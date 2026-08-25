import Foundation

final class RotationTrigger {
    static let shared = RotationTrigger()
    var forceTick: (() -> Void)?
    private init() {}
}
