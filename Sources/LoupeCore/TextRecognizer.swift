import CoreGraphics
import Vision

public struct TextLine: Codable, Equatable {
    public let text: String
    public let confidence: Double
    public let box: Box
}

public struct TextOptions {
    /// BCP 47 codes such as `en-US` or `tr-TR`. Empty means detect automatically.
    public var languages: [String]
    /// Trades accuracy for speed; also turns off language correction.
    public var fast: Bool

    public init(languages: [String] = [], fast: Bool = false) {
        self.languages = languages
        self.fast = fast
    }
}

public enum TextRecognizer {
    public static func lines(in image: CGImage, options: TextOptions = TextOptions()) throws -> [TextLine] {
        let request = makeRequest(options)
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return TextLine(
                text: candidate.string,
                confidence: (Double(candidate.confidence) * 100).rounded() / 100,
                box: Box(visionRect: observation.boundingBox)
            )
        }
    }

    public static func supportedLanguages(fast: Bool = false) throws -> [String] {
        try makeRequest(TextOptions(fast: fast)).supportedRecognitionLanguages()
    }

    private static func makeRequest(_ options: TextOptions) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = options.fast ? .fast : .accurate
        request.usesLanguageCorrection = !options.fast
        if options.languages.isEmpty {
            request.automaticallyDetectsLanguage = true
        } else {
            request.recognitionLanguages = options.languages
        }
        return request
    }
}
