import Foundation

/// Presents assistant prose as readable text without rewriting the stored reply.
enum ReplyText {
    private static let codeFence = pattern(#"^[ \t]{0,3}(`{3,}|~{3,})"#)
    private static let literal = pattern(#"`+([^`]+?)`+|(?:https?://|mailto:)[^\s<>]+"#)
    private static let listOrHeading = pattern(#"^[ \t]*(?:#{1,6}|[-+*•]|\d+[.)])[ \t]+"#)
    private static let emphasis = pattern(#"(?<![\\\p{L}\p{N}])(\*{1,3}|_{1,3}|~~)(?=\S)(.*?\S)\1(?![\p{L}\p{N}])"#)
    private static let unfinishedEmphasis = pattern(#"(?<![\\\p{L}\p{N}])(?:\*{2,3}|_{2,3}|~~)(?=\S|$)"#)
    private static let oldToolStatus = pattern(#"^_Using [A-Za-z0-9_ ]+…_\s*$"#)
    private static let dashAfterPunctuation = pattern(#"(?<=[.,!?;:])[ \t]+[—–][ \t]+"#)
    private static let proseDash = pattern(#"[ \t]+[—–][ \t]+"#)
    private static let doneDash = pattern(#"^(Done|All set)[ \t]+[—–][ \t]+"#)
    private static let spokenLink = pattern(#"\[([^\]]+)\]\([^)]+\)"#)

    static func display(_ text: String, streaming: Bool = false) -> String {
        formatted(text, streaming: streaming, spoken: false)
    }

    static func speech(_ text: String) -> String {
        formatted(text, streaming: false, spoken: true)
    }

    private static func formatted(_ text: String, streaming: Bool, spoken: Bool) -> String {
        var fence: Substring?
        var lines: [String] = []
        for value in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(value)
            if let match = codeFence.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)),
               let marker = Range(match.range(at: 1), in: line) {
                let code = line[marker]
                if let open = fence {
                    if code.first == open.first, code.count >= open.count,
                       line[marker.upperBound...].trimmingCharacters(in: .whitespaces).isEmpty {
                        fence = nil
                        continue
                    }
                } else {
                    fence = code
                    if spoken { lines.append("Code block.") }
                    continue
                }
            }
            if fence != nil {
                if !spoken { lines.append(line) }
            } else {
                lines.append(cleanLine(line, streaming: streaming, spoken: spoken))
            }
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanLine(_ source: String, streaming: Bool, spoken: Bool) -> String {
        var line = replace(oldToolStatus, in: source, with: "")
        line = replace(listOrHeading, in: line, with: "")
        if spoken { line = replace(spokenLink, in: line, with: "$1") }
        let matches = literal.matches(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line))
        var text = ""
        var edge = line.startIndex
        for match in matches {
            guard let range = Range(match.range, in: line) else { continue }
            text += cleanProse(String(line[edge..<range.lowerBound]), streaming: streaming)
            if let code = Range(match.range(at: 1), in: line) {
                text += line[code]
            } else {
                text += line[range]
            }
            edge = range.upperBound
        }
        return text + cleanProse(String(line[edge...]), streaming: streaming)
    }

    private static func cleanProse(_ text: String, streaming: Bool) -> String {
        var cleaned = replace(emphasis, in: text, with: "$2")
        if streaming { cleaned = replace(unfinishedEmphasis, in: cleaned, with: "") }
        cleaned = replace(doneDash, in: cleaned, with: "$1. ")
        cleaned = replace(dashAfterPunctuation, in: cleaned, with: " ")
        return replace(proseDash, in: cleaned, with: ", ")
    }

    private static func pattern(_ pattern: String) -> NSRegularExpression {
        // Patterns are constants defined above.
        try! NSRegularExpression(pattern: pattern)
    }

    private static func replace(_ pattern: NSRegularExpression, in text: String, with replacement: String) -> String {
        pattern.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text), withTemplate: replacement)
    }
}
