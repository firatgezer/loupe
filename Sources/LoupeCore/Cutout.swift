import CoreGraphics
import CoreImage
import Vision

public enum Cutout {
    /// Returns the image with everything except the foreground subjects made transparent.
    public static func subject(of image: CGImage, crop: Bool = false) throws -> CGImage {
        let (observation, handler) = try foreground(of: image)
        let buffer = try observation.generateMaskedImage(
            ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: crop
        )
        return try render(CIImage(cvPixelBuffer: buffer), colorSpace: image.colorSpace)
    }

    /// Returns a greyscale mask the size of the input: white for the subject, black elsewhere.
    public static func mask(of image: CGImage) throws -> CGImage {
        let (observation, handler) = try foreground(of: image)
        let buffer = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
        return try render(CIImage(cvPixelBuffer: buffer), colorSpace: CGColorSpace(name: CGColorSpace.linearGray))
    }

    private static func foreground(of image: CGImage) throws -> (VNInstanceMaskObservation, VNImageRequestHandler) {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            throw LoupeError.noSubject
        }
        return (observation, handler)
    }

    private static func render(_ image: CIImage, colorSpace: CGColorSpace?) throws -> CGImage {
        let space = colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let format: CIFormat = space.model == .monochrome ? .L8 : .RGBA8
        guard let result = CIContext().createCGImage(image, from: image.extent, format: format, colorSpace: space) else {
            throw LoupeError.encodeFailed("cutout image")
        }
        return result
    }
}
