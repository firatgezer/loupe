import CoreGraphics

/// A rectangle in normalised coordinates (0...1) with the origin at the top left,
/// which is what most image tools expect. Vision itself uses a bottom-left origin.
public struct Box: Codable, Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    init(visionRect rect: CGRect) {
        x = Self.round(rect.minX)
        y = Self.round(1 - rect.maxY)
        width = Self.round(rect.width)
        height = Self.round(rect.height)
    }

    private static func round(_ value: CGFloat) -> Double {
        (Double(value) * 10_000).rounded() / 10_000
    }
}
