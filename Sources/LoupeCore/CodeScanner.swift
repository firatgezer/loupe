import CoreGraphics
import Vision

public struct ScannedCode: Codable, Equatable {
    public let payload: String
    /// Short name such as `QR`, `EAN13` or `PDF417`.
    public let symbology: String
    public let box: Box
}

public enum CodeScanner {
    public static func codes(in image: CGImage) throws -> [ScannedCode] {
        let request = VNDetectBarcodesRequest()
        try VNImageRequestHandler(cgImage: image).perform([request])

        var seen = Set<String>()
        return (request.results ?? []).compactMap { observation in
            guard let payload = observation.payloadStringValue else { return nil }
            let symbology = shortName(observation.symbology)
            // Vision can report the same code more than once for a single image.
            guard seen.insert(symbology + "\u{0}" + payload).inserted else { return nil }
            return ScannedCode(payload: payload, symbology: symbology, box: Box(visionRect: observation.boundingBox))
        }
    }

    static func shortName(_ symbology: VNBarcodeSymbology) -> String {
        let raw = symbology.rawValue
        let prefix = "VNBarcodeSymbology"
        return raw.hasPrefix(prefix) ? String(raw.dropFirst(prefix.count)) : raw
    }
}
