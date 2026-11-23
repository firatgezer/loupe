import ArgumentParser
import Foundation
import LoupeCore

struct CodesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "codes",
        abstract: "Read QR codes and barcodes in images and PDFs.",
        discussion: """
        Prints the content of every code found, one per line. With several inputs each line \
        starts with the file name. The exit status is 1 when no code is found.
        """
    )

    @OptionGroup var input: InputOptions

    @Option(help: "PDF pages to read, such as 1-3,7 or 5- for page 5 to the end.", transform: parsePages)
    var pages: PageSelection?

    @Flag(help: "Print JSON with the type and position of every code.")
    var json = false

    private struct Result: Encodable {
        let file: String
        let page: Int?
        let codes: [ScannedCode]
    }

    func run() throws {
        let sources = try input.sources()
        var results: [Result] = []
        var failed = false

        for source in sources {
            do {
                for page in try source.pages(pages) {
                    let result = Result(file: source.label, page: page.number, codes: try CodeScanner.codes(in: page.image))
                    if !json {
                        let prefix = sources.count > 1 ? "\(source.label): " : ""
                        result.codes.forEach { print(prefix + $0.payload) }
                    }
                    results.append(result)
                }
            } catch {
                Console.error(error, in: source)
                failed = true
            }
        }

        if json { try Console.printJSON(results) }
        if failed { throw ExitCode.failure }
        if results.allSatisfy({ $0.codes.isEmpty }) {
            Console.error("no codes found")
            throw ExitCode.failure
        }
    }
}
