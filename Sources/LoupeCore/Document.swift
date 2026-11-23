import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// One rasterised page of an input file. Images have a single page with no number.
public struct Page {
    public let number: Int?
    public let image: CGImage

    public init(number: Int?, image: CGImage) {
        self.number = number
        self.image = image
    }
}

public enum Document {
    /// Resolution used to rasterise PDF pages before running Vision on them.
    public static let pdfDPI: CGFloat = 300
    /// Keeps a poster-sized PDF page from turning into a gigantic bitmap.
    static let maxPagePixels: CGFloat = 8000

    public static func pages(from data: Data, selecting selection: PageSelection? = nil) throws -> [Page] {
        if data.starts(with: Array("%PDF".utf8)) {
            return try pdfPages(from: data, selecting: selection)
        }
        return [Page(number: nil, image: try image(from: data))]
    }

    /// Decodes the first frame of an image and applies its EXIF orientation,
    /// so photos straight off a phone come out upright.
    public static func image(from data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else {
            throw LoupeError.unreadable("unknown format")
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else {
            throw LoupeError.unreadable("missing image size")
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(width, height),
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw LoupeError.unreadable("could not decode")
        }
        return image
    }

    static func pdfPages(from data: Data, selecting selection: PageSelection?) throws -> [Page] {
        guard let provider = CGDataProvider(data: data as CFData), let pdf = CGPDFDocument(provider) else {
            throw LoupeError.unreadable("damaged PDF")
        }
        if pdf.isEncrypted && !pdf.isUnlocked && !pdf.unlockWithPassword("") {
            throw LoupeError.unreadable("the PDF is password protected")
        }
        let count = pdf.numberOfPages
        guard count > 0 else { throw LoupeError.emptyPDF }

        let numbers = try selection?.pages(in: count) ?? Array(1...count)
        return try numbers.map { number in
            guard let page = pdf.page(at: number), let image = render(page) else {
                throw LoupeError.unreadable("could not render page \(number)")
            }
            return Page(number: number, image: image)
        }
    }

    static func render(_ page: CGPDFPage) -> CGImage? {
        var size = page.getBoxRect(.cropBox).size
        if page.rotationAngle % 180 != 0 {
            size = CGSize(width: size.height, height: size.width)
        }
        let scale = min(pdfDPI / 72, maxPagePixels / max(size.width, size.height))
        let width = Int((size.width * scale).rounded())
        let height = Int((size.height * scale).rounded())

        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        // Scanned pages are often transparent where the paper is; OCR wants paper.
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.scaleBy(x: scale, y: scale)
        context.concatenate(page.getDrawingTransform(.cropBox, rect: CGRect(origin: .zero, size: size), rotate: 0, preserveAspectRatio: true))
        context.drawPDFPage(page)
        return context.makeImage()
    }

    public static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw LoupeError.encodeFailed(url.path)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw LoupeError.encodeFailed(url.path)
        }
    }
}
