import CoreGraphics
import CoreImage
import CoreText
import Foundation

enum Fixtures {
    /// Black text on white, large enough for reliable recognition.
    static func textImage(_ lines: [String], size: CGSize = CGSize(width: 1400, height: 500)) -> CGImage {
        let context = bitmap(size)
        let font = CTFontCreateWithName("Helvetica" as CFString, 64, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1),
        ]
        for (index, text) in lines.enumerated() {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
            context.textPosition = CGPoint(x: 60, y: size.height - 120 - CGFloat(index) * 110)
            CTLineDraw(line, context)
        }
        return context.makeImage()!
    }

    static func qrImage(_ payload: String) -> CGImage {
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(Data(payload.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        let code = filter.outputImage!.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let padded = code.transformed(by: CGAffineTransform(translationX: 80, y: 80))
            .composited(over: CIImage(color: .white).cropped(to: code.extent.insetBy(dx: -80, dy: -80).offsetBy(dx: 80, dy: 80)))
        return CIContext().createCGImage(padded, from: padded.extent)!
    }

    /// A one-page PDF per entry, each page showing that entry's lines.
    static func pdf(pages: [[String]]) -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let consumer = CGDataConsumer(data: data as CFMutableData)!
        let context = CGContext(consumer: consumer, mediaBox: &box, nil)!
        let font = CTFontCreateWithName("Helvetica" as CFString, 28, nil)
        for lines in pages {
            context.beginPDFPage(nil)
            for (index, text) in lines.enumerated() {
                let string = NSAttributedString(string: text, attributes: [
                    NSAttributedString.Key(kCTFontAttributeName as String): font,
                ])
                context.textPosition = CGPoint(x: 72, y: 700 - CGFloat(index) * 48)
                CTLineDraw(CTLineCreateWithAttributedString(string), context)
            }
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }

    static func png(_ image: CGImage) -> Data {
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    private static func bitmap(_ size: CGSize) -> CGContext {
        let context = CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        return context
    }
}
