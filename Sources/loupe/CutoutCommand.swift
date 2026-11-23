import ArgumentParser
import Foundation
import LoupeCore

struct CutoutCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cutout",
        abstract: "Remove the background and keep the subject as a transparent PNG.",
        discussion: """
        Works on people, pets and objects. Each result is saved next to the original \
        as NAME-cutout.png, unless --output says otherwise, and its path is printed.
        """
    )

    @OptionGroup var input: InputOptions

    @Option(name: .shortAndLong, help: "Output file, or a folder when there are several results.")
    var output: String?

    @Flag(help: "Trim the empty space around the subject.")
    var crop = false

    @Flag(help: "Save a black and white mask instead of the cutout.")
    var mask = false

    @Flag(name: .shortAndLong, help: "Replace files that already exist.")
    var force = false

    func validate() throws {
        if mask && crop {
            throw ValidationError("--crop has no effect with --mask.")
        }
        var isDirectory: ObjCBool = false
        if let output, input.files.count + (input.clipboard ? 1 : 0) > 1, !output.hasSuffix("/"),
           !(FileManager.default.fileExists(atPath: output, isDirectory: &isDirectory) && isDirectory.boolValue) {
            throw ValidationError("--output must be a folder when there are several inputs.")
        }
    }

    func run() throws {
        let sources = try input.sources()
        var failed = false

        for source in sources {
            do {
                let pages = try source.pages()
                for page in pages {
                    let image = mask ? try Cutout.mask(of: page.image) : try Cutout.subject(of: page.image, crop: crop)
                    let path = try destination(for: source, page: pages.count > 1 ? page.number : nil, severalResults: sources.count > 1 || pages.count > 1)
                    if !force && FileManager.default.fileExists(atPath: path) {
                        throw CLIError("\(path) already exists, use --force to replace it")
                    }
                    try Document.writePNG(image, to: URL(fileURLWithPath: path))
                    print(path)
                }
            } catch {
                Console.error(error, in: source)
                failed = true
            }
        }
        if failed { throw ExitCode.failure }
    }

    /// Paths stay relative when the input was given relative, so the printed result reads like the command.
    private func destination(for source: InputSource, page: Int?, severalResults: Bool) throws -> String {
        let name: String
        let folder: String
        switch source {
        case .file(let path):
            name = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
            folder = (path as NSString).deletingLastPathComponent
        case .standardInput:
            name = "stdin"
            folder = ""
        case .clipboard:
            name = "clipboard"
            folder = ""
        }
        let fileName = name + (page.map { "-p\($0)" } ?? "") + (mask ? "-mask" : "-cutout") + ".png"

        guard let output else { return (folder as NSString).appendingPathComponent(fileName) }

        var isDirectory: ObjCBool = false
        if output.hasSuffix("/") || (FileManager.default.fileExists(atPath: output, isDirectory: &isDirectory) && isDirectory.boolValue) {
            try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
            return (output as NSString).appendingPathComponent(fileName)
        }
        guard !severalResults else {
            throw CLIError("--output must be a folder when there are several results")
        }
        return output
    }
}
