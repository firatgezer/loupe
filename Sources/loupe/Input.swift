import AppKit
import ArgumentParser
import Foundation
import LoupeCore

enum InputSource {
    case file(String)
    case standardInput
    case clipboard

    var label: String {
        switch self {
        case .file(let path): return path
        case .standardInput: return "stdin"
        case .clipboard: return "clipboard"
        }
    }

    func pages(_ selection: PageSelection? = nil) throws -> [Page] {
        switch self {
        case .file(let path):
            return try Document.pages(from: Self.read(path), selecting: selection)
        case .standardInput:
            return try Document.pages(from: FileHandle.standardInput.readDataToEndOfFile(), selecting: selection)
        case .clipboard:
            return try Document.pages(from: Self.clipboardData(), selecting: selection)
        }
    }

    private static func read(_ path: String) throws -> Data {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw CLIError("no such file")
        }
        guard !isDirectory.boolValue else { throw CLIError("is a folder") }
        return try Data(contentsOf: URL(fileURLWithPath: path))
    }

    /// A file copied in Finder wins over the icon image that Finder puts next to it.
    private static func clipboardData() throws -> Data {
        let pasteboard = NSPasteboard.general
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let url = pasteboard.readObjects(forClasses: [NSURL.self], options: options)?.first as? URL {
            return try read(url.path)
        }
        for type in [NSPasteboard.PasteboardType.pdf, .png, .tiff] {
            if let data = pasteboard.data(forType: type) { return data }
        }
        throw CLIError("the clipboard has no image, PDF or file")
    }
}

struct InputOptions: ParsableArguments {
    @Argument(help: "Image or PDF files. Use - to read from standard input.")
    var files: [String] = []

    @Flag(name: [.customShort("c"), .long], help: "Read an image, a PDF or a copied file from the clipboard.")
    var clipboard = false

    func sources() throws -> [InputSource] {
        guard !files.isEmpty || clipboard else {
            throw ValidationError("Give at least one file, or use --clipboard.")
        }
        guard files.filter({ $0 == "-" }).count <= 1 else {
            throw ValidationError("Standard input (-) can only be read once.")
        }
        let fromFiles = files.map { $0 == "-" ? InputSource.standardInput : .file($0) }
        return clipboard ? [.clipboard] + fromFiles : fromFiles
    }
}

func parsePages(_ text: String) throws -> PageSelection {
    guard let selection = PageSelection(text) else {
        throw ValidationError("Pages look like 1-3,7 or 5- (from page 5 to the end).")
    }
    return selection
}
