import Foundation
import LoupeCore

struct CLIError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

enum Console {
    static func error(_ message: String) {
        FileHandle.standardError.write(Data("loupe: \(message)\n".utf8))
    }

    static func error(_ error: Error, in source: InputSource) {
        Self.error("\(source.label): \(describe(error))")
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case let error as LoupeError: return error.description
        case let error as CLIError: return error.description
        default: return error.localizedDescription
        }
    }

    static func printJSON<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        print(String(decoding: try encoder.encode(value), as: UTF8.self))
    }
}
