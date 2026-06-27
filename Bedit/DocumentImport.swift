import AppKit
import UniformTypeIdentifiers

private nonisolated let documentExtensions: Set<String> = ["docx", "doc", "rtf"]

nonisolated func isImportableFile(_ url: URL) -> Bool {
    let ext = url.pathExtension.lowercased()
    if documentExtensions.contains(ext) { return true }
    if let uttype = UTType(filenameExtension: ext) {
        return uttype.conforms(to: .text) || uttype.conforms(to: .plainText)
    }
    return false
}

nonisolated func outputSuffixForFile(_ url: URL) -> String {
    let ext = url.pathExtension.lowercased()
    if documentExtensions.contains(ext) { return "md" }
    return ext.isEmpty ? "bin" : ext
}

nonisolated func extractText(_ url: URL) throws -> Data? {
    let ext = url.pathExtension.lowercased()
    guard documentExtensions.contains(ext) else { return nil }
    let attributed = try NSAttributedString(
        url: url,
        options: [:],
        documentAttributes: nil
    )
    let markdown = markdownFromAttributedString(attributed)
    guard let data = markdown.data(using: .utf8) else {
        throw CocoaError(.fileReadCorruptFile)
    }
    return data
}

private nonisolated func bodyFontSize(of attrStr: NSAttributedString) -> CGFloat {
    var sizeCounts: [CGFloat: Int] = [:]
    let fullRange = NSRange(location: 0, length: attrStr.length)
    attrStr.enumerateAttribute(.font, in: fullRange) { value, range, _ in
        guard let font = value as? NSFont else { return }
        let size = font.pointSize
        sizeCounts[size, default: 0] += range.length
    }
    return sizeCounts.max(by: { $0.value < $1.value })?.key ?? 12
}

private nonisolated func markdownFromAttributedString(_ attrStr: NSAttributedString) -> String {
    guard attrStr.length > 0 else { return "" }

    let body = bodyFontSize(of: attrStr)
    let string = attrStr.string
    var result = ""
    var listCounters: [ObjectIdentifier: Int] = [:]

    string.enumerateSubstrings(
        in: string.startIndex..<string.endIndex,
        options: .byParagraphs
    ) { paragraph, paragraphRange, enclosingRange, _ in
        guard let paragraph else { return }
        let nsRange = NSRange(paragraphRange, in: string)

        if paragraph.trimmingCharacters(in: .whitespaces).isEmpty {
            result += "\n"
            return
        }

        var prefix = ""

        let paraStyle = attrStr.attribute(
            .paragraphStyle, at: nsRange.location, effectiveRange: nil
        ) as? NSParagraphStyle

        if let textLists = paraStyle?.textLists, !textLists.isEmpty {
            let depth = textLists.count
            let indent = String(repeating: "  ", count: depth - 1)
            let list = textLists[depth - 1]
            let listID = ObjectIdentifier(list)

            if list.markerFormat == .decimal {
                let count = (listCounters[listID] ?? 0) + 1
                listCounters[listID] = count
                prefix = "\(indent)\(count). "
            } else {
                prefix = "\(indent)* "
            }
        } else {
            listCounters.removeAll()

            // Block quote: indented paragraph that isn't a list
            if let style = paraStyle, style.headIndent > 0 {
                prefix = "> "
            }
        }

        // Heading detection via font size
        if prefix.isEmpty {
            let firstFont = attrStr.attribute(
                .font, at: nsRange.location, effectiveRange: nil
            ) as? NSFont
            if let size = firstFont?.pointSize, body > 0 {
                let ratio = size / body
                if ratio >= 1.6 {
                    prefix = "# "
                } else if ratio >= 1.3 {
                    prefix = "## "
                } else if ratio >= 1.1 {
                    prefix = "### "
                }
            }
        }

        result += prefix

        attrStr.enumerateAttributes(in: nsRange) { attrs, range, _ in
            let runText = (string as NSString).substring(with: range)
            if runText.isEmpty { return }

            let font = attrs[.font] as? NSFont
            let traits = font?.fontDescriptor.symbolicTraits ?? []
            let isBold = traits.contains(.bold)
            let isItalic = traits.contains(.italic)
            let isMonospace = traits.contains(.monoSpace)
            let hasStrikethrough = (attrs[.strikethroughStyle] as? Int).map { $0 != 0 } ?? false
            let link = attrs[.link]

            let trimmed = runText.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                result += runText
                return
            }
            let leading = String(runText.prefix(while: { $0 == " " }))
            let trailing = String(runText.reversed().prefix(while: { $0 == " " }))
            result += leading

            var formatted = trimmed

            if isMonospace {
                formatted = "`\(formatted)`"
            }
            if hasStrikethrough {
                formatted = "~~\(formatted)~~"
            }
            if let link {
                let url = (link as? URL)?.absoluteString ?? "\(link)"
                // Don't wrap if the text is the URL itself
                if formatted != url {
                    formatted = "[\(formatted)](\(url))"
                }
            }
            if isBold && isItalic {
                formatted = "***\(formatted)***"
            } else if isBold {
                formatted = "**\(formatted)**"
            } else if isItalic {
                formatted = "*\(formatted)*"
            }

            result += formatted
            result += trailing
        }

        result += "\n"
    }

    return result
}
