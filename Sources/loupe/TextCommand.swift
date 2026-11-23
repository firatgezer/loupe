import ArgumentParser
import Foundation
import LoupeCore

struct TextCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "text",
        abstract: "Print the text found in images and PDFs.",
        discussion: """
        Works on photos, screenshots and scanned documents. PDF pages are separated by a \
        form feed, as pdftotext does. The exit status is 1 when no text is found.
        """
    )

    @OptionGroup var input: InputOptions

    @Option(
        name: [.short, .customLong("language")],
        help: "Language to expect, such as en-US or tr-TR. Repeat it or separate with commas. Detected automatically by default."
    )
    var languages: [String] = []

    @Option(help: "PDF pages to read, such as 1-3,7 or 5- for page 5 to the end.", transform: parsePages)
    var pages: PageSelection?

    @Flag(help: "Faster but less accurate, without language correction.")
    var fast = false

    @Flag(help: "Print JSON with the confidence and position of every line.")
    var json = false

    @Flag(help: "List the languages that --language accepts.")
    var listLanguages = false

    private struct Result: Encodable {
        let file: String
        let page: Int?
        let lines: [TextLine]
    }

    func run() throws {
        if listLanguages {
            try TextRecognizer.supportedLanguages(fast: fast).forEach { print($0) }
            return
        }

        let options = TextOptions(languages: try checkedLanguages(), fast: fast)
        let sources = try input.sources()
        var results: [Result] = []
        var failed = false

        for source in sources {
            do {
                let pages = try source.pages(pages)
                let pageResults = try pages.map { page in
                    Result(file: source.label, page: page.number, lines: try TextRecognizer.lines(in: page.image, options: options))
                }
                if !json { printPlain(pageResults, header: sources.count > 1 ? source.label : nil) }
                results += pageResults
            } catch {
                Console.error(error, in: source)
                failed = true
            }
        }

        if json { try Console.printJSON(results) }
        if failed { throw ExitCode.failure }
        if results.allSatisfy({ $0.lines.isEmpty }) {
            Console.error("no text found")
            throw ExitCode.failure
        }
    }

    private func printPlain(_ results: [Result], header: String?) {
        if let header { print("==> \(header) <==") }
        for (index, result) in results.enumerated() {
            if index > 0 { print("\u{0C}", terminator: "") }
            result.lines.forEach { print($0.text) }
        }
        if header != nil { print() }
    }

    private func checkedLanguages() throws -> [String] {
        let requested = languages
            .flatMap { $0.split(separator: ",") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !requested.isEmpty else { return [] }

        let supported = try TextRecognizer.supportedLanguages(fast: fast)
        return try requested.map { code in
            if let match = supported.first(where: { $0.caseInsensitiveCompare(code) == .orderedSame }) {
                return match
            }
            // Accept a bare language such as "tr" when Vision only knows "tr-TR".
            if let match = supported.first(where: { $0.lowercased().hasPrefix(code.lowercased() + "-") }) {
                return match
            }
            throw ValidationError("Unsupported language \"\(code)\". See loupe text --list-languages\(fast ? " --fast" : "").")
        }
    }
}
