import Foundation

public enum LoupeError: Error, CustomStringConvertible, Equatable {
    case unreadable(String)
    case emptyPDF
    case pageOutOfRange(Int, count: Int)
    case noSubject
    case encodeFailed(String)

    public var description: String {
        switch self {
        case .unreadable(let reason):
            return "not an image or PDF that can be read (\(reason))"
        case .emptyPDF:
            return "the PDF has no pages"
        case .pageOutOfRange(let page, let count):
            return "page \(page) does not exist (the document has \(count))"
        case .noSubject:
            return "no foreground subject found"
        case .encodeFailed(let path):
            return "could not write \(path)"
        }
    }
}
