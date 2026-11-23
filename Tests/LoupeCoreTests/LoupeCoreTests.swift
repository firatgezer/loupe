import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import LoupeCore

@Suite struct PageSelectionTests {
    @Test func parsesSinglesRangesAndOpenEnds() throws {
        let selection = try #require(PageSelection("1-3, 7,9-"))
        #expect(try selection.pages(in: 10) == [1, 2, 3, 7, 9, 10])
    }

    @Test func keepsOrderAndDropsDuplicates() throws {
        #expect(try #require(PageSelection("4,2,2-4")).pages(in: 5) == [4, 2, 3])
    }

    @Test(arguments: ["", "0", "3-1", "a", "1,,2", "-2"])
    func rejectsMalformedInput(_ text: String) {
        #expect(PageSelection(text) == nil)
    }

    @Test func reportsPagesPastTheEnd() {
        #expect(throws: LoupeError.pageOutOfRange(4, count: 3)) {
            try PageSelection("2-4")!.pages(in: 3)
        }
    }
}

@Suite struct DocumentTests {
    @Test func rejectsDataThatIsNotAnImage() {
        #expect(throws: LoupeError.self) { try Document.pages(from: Data("hello".utf8)) }
    }

    @Test func rendersEveryPdfPageOrTheSelectedOnes() throws {
        let pdf = Fixtures.pdf(pages: [["one"], ["two"], ["three"]])
        #expect(try Document.pages(from: pdf).map(\.number) == [1, 2, 3])
        #expect(try Document.pages(from: pdf, selecting: PageSelection("2-")).map(\.number) == [2, 3])
    }

    @Test func rendersPdfPagesAt300DPI() throws {
        let page = try #require(Document.pages(from: Fixtures.pdf(pages: [["x"]])).first)
        #expect(page.image.width == 2550)
        #expect(page.image.height == 3300)
    }

    @Test func appliesExifOrientation() throws {
        let image = Fixtures.textImage(["wide"], size: CGSize(width: 400, height: 100))
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data as CFMutableData, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: 6] as CFDictionary)
        CGImageDestinationFinalize(destination)

        let decoded = try Document.image(from: data as Data)
        #expect(decoded.width == 100)
        #expect(decoded.height == 400)
    }
}

@Suite struct TextRecognizerTests {
    @Test func readsLinesTopToBottom() throws {
        let image = Fixtures.textImage(["Invoice 2026-118", "Total due 482.50"])
        let lines = try TextRecognizer.lines(in: image)
        #expect(lines.map(\.text) == ["Invoice 2026-118", "Total due 482.50"])
        #expect(lines[0].box.y < lines[1].box.y)
        #expect(lines.allSatisfy { $0.confidence > 0.5 })
    }

    @Test func readsTextFromPdfPages() throws {
        let pages = try Document.pages(from: Fixtures.pdf(pages: [["First page"], ["Second page"]]))
        let text = try pages.map { try TextRecognizer.lines(in: $0.image).map(\.text) }
        #expect(text == [["First page"], ["Second page"]])
    }

    @Test func findsNothingOnABlankImage() throws {
        #expect(try TextRecognizer.lines(in: Fixtures.textImage([])) == [])
    }

    @Test func listsCommonLanguages() throws {
        #expect(try TextRecognizer.supportedLanguages().contains("en-US"))
    }
}

@Suite struct CodeScannerTests {
    @Test func readsAQrCode() throws {
        let codes = try CodeScanner.codes(in: Fixtures.qrImage("https://example.com/menu?table=12"))
        #expect(codes.count == 1)
        #expect(codes.first?.payload == "https://example.com/menu?table=12")
        #expect(codes.first?.symbology == "QR")
    }

    @Test func findsNothingWithoutCodes() throws {
        #expect(try CodeScanner.codes(in: Fixtures.textImage(["no codes here"])) == [])
    }
}

@Suite struct CutoutTests {
    @Test func reportsWhenThereIsNoSubject() {
        let blank = Fixtures.textImage([], size: CGSize(width: 600, height: 400))
        #expect(throws: LoupeError.noSubject) { try Cutout.subject(of: blank) }
    }
}
