//
//  MarkdownFormatter.swift
//  Idioma
//
//  Converts Markdown text into a formatted NSMutableAttributedString with
//  paragraph breaks, bold headings, and bold key terms. The resulting
//  plain text (attributedString.string) is suitable for vocabulary matching
//  because it has the same character content — only attributes differ.
//

import Foundation
import UIKit

struct MarkdownFormatter {

    struct Result {
        /// Plain text (same chars as attributedString.string) for vocab matching
        let plainText: String
        /// Formatted attributed string with heading + bold styling
        let attributedString: NSMutableAttributedString
    }

    /// Converts Markdown content to a styled `NSMutableAttributedString`.
    /// HTML entities are stripped first, then Markdown headings and bold
    /// markers are converted to font attributes with paragraph breaks preserved.
    static func format(_ content: String, bodySize: CGFloat = 17, headingSize: CGFloat = 21) -> Result {
        let cleaned = stripHTML(content)

        let bodyFont = serifFont(ofSize: bodySize)
        let boldBodyFont = serifFont(ofSize: bodySize, bold: true)
        let headingFont = serifFont(ofSize: headingSize, bold: true)

        let mutable = NSMutableAttributedString()
        let paragraphs = cleaned.components(separatedBy: "\n\n")
        var isFirst = true

        for rawParagraph in paragraphs {
            let trimmed = rawParagraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if !isFirst { mutable.append(NSAttributedString(string: "\n\n")) }
            isFirst = false

            // Markdown heading: lines starting with # (1–6)
            if let match = trimmed.range(of: #"^#{1,6}\s*"#, options: .regularExpression) {
                let headingText = String(trimmed[match.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                mutable.append(NSAttributedString(string: headingText, attributes: [.font: headingFont]))
            } else {
                // Regular paragraph — collapse internal whitespace, parse **bold**
                let normalized = trimmed.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                appendWithBold(normalized, to: mutable, bodyFont: bodyFont, boldFont: boldBodyFont)
            }
        }

        return Result(plainText: mutable.string, attributedString: mutable)
    }

    // MARK: - Private

    private static func appendWithBold(
        _ text: String,
        to mutable: NSMutableAttributedString,
        bodyFont: UIFont,
        boldFont: UIFont
    ) {
        var remaining = text[...]

        while let start = remaining.range(of: "**") {
            let before = String(remaining[remaining.startIndex..<start.lowerBound])
            if !before.isEmpty {
                mutable.append(NSAttributedString(string: before, attributes: [.font: bodyFont]))
            }

            let after = remaining[start.upperBound...]
            if let end = after.range(of: "**") {
                let boldText = String(after[after.startIndex..<end.lowerBound])
                mutable.append(NSAttributedString(string: boldText, attributes: [.font: boldFont]))
                remaining = after[end.upperBound...]
            } else {
                // No closing ** — keep as literal
                mutable.append(NSAttributedString(string: "**", attributes: [.font: bodyFont]))
                remaining = remaining[start.upperBound...]
            }
        }

        if !remaining.isEmpty {
            mutable.append(NSAttributedString(string: String(remaining), attributes: [.font: bodyFont]))
        }
    }

    private static func serifFont(ofSize size: CGFloat, bold: Bool = false) -> UIFont {
        let weight: UIFont.Weight = bold ? .bold : .regular
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let descriptor = base.fontDescriptor.withDesign(.serif) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return base
    }

    private static func stripHTML(_ content: String) -> String {
        var text = content
        for (pattern, replacement) in [
            ("<[^>]+>", " "), ("&nbsp;", " "), ("&amp;", "&"),
            ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"),
        ] {
            text = text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return text
    }
}
