import Foundation

/// A page list such as `1-3,7,10-`, using 1-based page numbers.
public struct PageSelection: Equatable {
    enum Part: Equatable {
        case single(Int)
        case range(Int, Int?)
    }

    let parts: [Part]

    public init?(_ text: String) {
        var parts: [Part] = []
        for piece in text.split(separator: ",", omittingEmptySubsequences: false) {
            let piece = piece.trimmingCharacters(in: .whitespaces)
            if let dash = piece.firstIndex(of: "-") {
                let start = Int(piece[..<dash])
                let endText = piece[piece.index(after: dash)...]
                guard let start, start >= 1 else { return nil }
                if endText.isEmpty {
                    parts.append(.range(start, nil))
                } else {
                    guard let end = Int(endText), end >= start else { return nil }
                    parts.append(.range(start, end))
                }
            } else {
                guard let page = Int(piece), page >= 1 else { return nil }
                parts.append(.single(page))
            }
        }
        guard !parts.isEmpty else { return nil }
        self.parts = parts
    }

    /// Page numbers in the order given, without duplicates.
    public func pages(in count: Int) throws -> [Int] {
        var result: [Int] = []
        func add(_ page: Int) throws {
            guard page <= count else { throw LoupeError.pageOutOfRange(page, count: count) }
            if !result.contains(page) { result.append(page) }
        }
        for part in parts {
            switch part {
            case .single(let page):
                try add(page)
            case .range(let start, let end):
                for page in start...(end ?? max(start, count)) { try add(page) }
            }
        }
        return result
    }
}
