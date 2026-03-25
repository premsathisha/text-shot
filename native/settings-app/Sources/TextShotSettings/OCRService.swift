import AppKit
import Foundation
import Vision

protocol OCRServing {
    func runOcrWithRetry(imagePath: String) throws -> String?
}

final class OCRService {
    enum RecognitionLevel {
        case accurate
        case fast
    }

    struct OCRFragment {
        let text: String
        let boundingBox: CGRect

        var minX: CGFloat { boundingBox.minX }
        var maxX: CGFloat { boundingBox.maxX }
        var minY: CGFloat { boundingBox.minY }
        var maxY: CGFloat { boundingBox.maxY }
        var width: CGFloat { boundingBox.width }
        var height: CGFloat { boundingBox.height }
        var centerY: CGFloat { boundingBox.midY }
    }

    private enum JoinDecision {
        case space
        case newline
        case blankLine
    }

    private struct OCRLine {
        var fragments: [OCRFragment]
        var centerY: CGFloat

        var minX: CGFloat { fragments.map(\.minX).min() ?? 0 }
        var maxX: CGFloat { fragments.map(\.maxX).max() ?? 0 }
        var minY: CGFloat { fragments.map(\.minY).min() ?? 0 }
        var maxY: CGFloat { fragments.map(\.maxY).max() ?? 0 }
        var width: CGFloat { maxX - minX }

        var trimmedText: String {
            text().trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var wordCount: Int {
            trimmedText.split(whereSeparator: { $0.isWhitespace }).count
        }

        func fillRatio(contentWidth: CGFloat) -> CGFloat {
            min(max(width / max(contentWidth, 0.01), 0), 1)
        }

        func text() -> String {
            let ordered = fragments.sorted {
                if abs($0.minX - $1.minX) > 0.0001 {
                    return $0.minX < $1.minX
                }
                return $0.maxX < $1.maxX
            }

            var result = ""
            var previous: OCRFragment?
            for fragment in ordered {
                guard let priorFragment = previous else {
                    result = fragment.text
                    previous = fragment
                    continue
                }

                let rawGap = max(0, fragment.minX - priorFragment.maxX)
                let normalizedCharWidth = max(priorFragment.width / CGFloat(max(priorFragment.text.count, 1)), 0.005)
                let needsSpace = rawGap >= normalizedCharWidth * 0.7 && !result.hasSuffix(" ")
                if needsSpace {
                    result.append(" ")
                }
                result.append(fragment.text)
                previous = fragment
            }

            return result
        }
    }

    private struct LayoutStats {
        let medianHeight: CGFloat
        let medianGap: CGFloat
        let contentWidth: CGFloat
    }

    private let retryChain: [(RecognitionLevel, Bool)] = [
        (.accurate, true),
        (.accurate, false),
        (.fast, true)
    ]

    func runOcrWithRetry(imagePath: String) throws -> String? {
        guard let cgImage = loadCGImage(path: imagePath) else {
            throw NSError(domain: "TextShot", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Unable to read captured image"])
        }

        for (level, correction) in retryChain {
            let text = try recognizeText(from: cgImage, level: level, correction: correction)
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return cleanupOcrText(text)
            }
        }

        return nil
    }

    func cleanupOcrText(_ input: String) -> String {
        let normalized = input.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.replacingOccurrences(of: "[ \t]+$", with: "", options: .regularExpression) }

        let filtered = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return true
            }

            return trimmed.range(of: "^[|`~.,:;]+$", options: .regularExpression) == nil
        }

        let joined = filtered.joined(separator: "\n")
        let collapsed = joined.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadCGImage(path: String) -> CGImage? {
        guard let image = NSImage(contentsOfFile: path) else {
            return nil
        }

        var rect = NSRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    private func recognizeText(from image: CGImage, level: RecognitionLevel, correction: Bool) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = level == .fast ? .fast : .accurate
        request.usesLanguageCorrection = correction

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        let fragments = (request.results ?? []).compactMap { observation -> OCRFragment? in
            guard let text = observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                return nil
            }
            return OCRFragment(text: text, boundingBox: observation.boundingBox)
        }

        return assembleText(from: fragments)
    }

    func assembleText(from fragments: [OCRFragment]) -> String {
        guard !fragments.isEmpty else {
            return ""
        }

        let orderedFragments = fragments.sorted {
            if abs($0.centerY - $1.centerY) > 0.0001 {
                return $0.centerY > $1.centerY
            }
            return $0.minX < $1.minX
        }

        let medianHeight = max(median(orderedFragments.map(\.height)), 0.01)
        let lineThreshold = max(medianHeight * 0.55, 0.01)

        var lines: [OCRLine] = []
        for fragment in orderedFragments {
            if var current = lines.last, abs(fragment.centerY - current.centerY) <= lineThreshold {
                current.fragments.append(fragment)
                let count = CGFloat(current.fragments.count)
                current.centerY = ((current.centerY * (count - 1)) + fragment.centerY) / count
                lines[lines.count - 1] = current
            } else {
                lines.append(OCRLine(fragments: [fragment], centerY: fragment.centerY))
            }
        }

        let contentMinX = lines.map(\.minX).min() ?? 0
        let contentMaxX = lines.map(\.maxX).max() ?? 1
        let contentWidth = max(contentMaxX - contentMinX, 0.01)
        let gaps = adjacentGaps(for: lines)
        let positiveGaps = gaps.filter { $0 > 0 }
        let medianGap = max(median(positiveGaps), medianHeight * 0.45)
        let stats = LayoutStats(medianHeight: medianHeight, medianGap: medianGap, contentWidth: contentWidth)

        var result = lines[0].trimmedText
        guard lines.count > 1 else {
            return result
        }

        for index in 1..<lines.count {
            let previous = lines[index - 1]
            let current = lines[index]
            let next = index + 1 < lines.count ? lines[index + 1] : nil

            switch joinDecision(previous: previous, current: current, next: next, stats: stats) {
            case .space:
                result.append(" ")
            case .newline:
                result.append("\n")
            case .blankLine:
                result.append("\n\n")
            }

            result.append(current.trimmedText)
        }

        return result
    }

    private func joinDecision(previous: OCRLine, current: OCRLine, next: OCRLine?, stats: LayoutStats) -> JoinDecision {
        let previousText = previous.trimmedText
        let currentText = current.trimmedText
        let gap = max(0, previous.minY - current.maxY)

        if gap > max(stats.medianHeight * 1.6, stats.medianGap * 2.2) {
            return .blankLine
        }

        let leftDelta = abs(previous.minX - current.minX) / stats.contentWidth
        let rightDelta = abs(previous.maxX - current.maxX) / stats.contentWidth
        let indentDelta = abs(previous.minX - current.minX)
        let previousFill = previous.fillRatio(contentWidth: stats.contentWidth)
        let currentFill = current.fillRatio(contentWidth: stats.contentWidth)

        if looksLikeListItem(previousText) || looksLikeListItem(currentText) {
            return .newline
        }

        if looksLikeFilenameOrPath(previousText) || looksLikeFilenameOrPath(currentText) {
            return .newline
        }

        if looksLikeHeading(previous, fillRatio: previousFill) {
            return .newline
        }

        if isNarrowStandaloneRow(previous) && isNarrowStandaloneRow(current) {
            return .newline
        }

        if isNarrowStandaloneRow(current) && !looksLikeParagraphContinuation(previousText: previousText, currentText: currentText) {
            return .newline
        }

        var paragraphScore = 0

        if gap <= max(stats.medianGap * 1.2, stats.medianHeight * 0.8) {
            paragraphScore += 2
        } else {
            paragraphScore -= 1
        }

        if leftDelta <= 0.035 {
            paragraphScore += 3
        } else if leftDelta >= 0.075 {
            paragraphScore -= 2
        }

        if rightDelta <= 0.12 {
            paragraphScore += 1
        } else if rightDelta >= 0.22 {
            paragraphScore -= 1
        }

        if indentDelta >= stats.contentWidth * 0.1 {
            paragraphScore -= 3
        }

        if previousFill >= 0.6 {
            paragraphScore += 2
        }
        if currentFill >= 0.58 {
            paragraphScore += 2
        }
        if previousFill <= 0.42 && currentFill <= 0.42 {
            paragraphScore -= 2
        }

        if previous.wordCount >= 5 || current.wordCount >= 5 {
            paragraphScore += 2
        }

        if isShortStandalone(previous, fillRatio: previousFill) || isShortStandalone(current, fillRatio: currentFill) {
            paragraphScore -= 2
        }

        if looksLikeParagraphContinuation(previousText: previousText, currentText: currentText) {
            paragraphScore += 3
        }

        if endsSentence(previousText) && startsLikelyNewSentence(currentText) {
            paragraphScore -= 2
        }

        if let next, supportsParagraphRun(previous: current, next: next, stats: stats) {
            paragraphScore += 1
        }

        return paragraphScore >= 5 ? .space : .newline
    }

    private func adjacentGaps(for lines: [OCRLine]) -> [CGFloat] {
        guard lines.count > 1 else {
            return []
        }

        return (1..<lines.count).map { index in
            max(0, lines[index - 1].minY - lines[index].maxY)
        }
    }

    private func looksLikeListItem(_ text: String) -> Bool {
        let markerRegex = #"^(\d+[.)]|[-*•])\s+"#
        return text.range(of: markerRegex, options: .regularExpression) != nil
    }

    private func looksLikeFilenameOrPath(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        if trimmed.contains("/") || trimmed.contains("\\") || trimmed.hasPrefix("~") {
            return true
        }

        if trimmed.range(of: #"\.[A-Za-z0-9]{1,8}$"#, options: .regularExpression) != nil {
            return true
        }

        if trimmed.range(of: #"^v?\d+(?:\.\d+){1,}$"#, options: .regularExpression) != nil {
            return true
        }

        if trimmed.range(of: #"^[A-Z0-9_\-]+$"#, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    private func looksLikeHeading(_ line: OCRLine, fillRatio: CGFloat) -> Bool {
        let text = line.trimmedText
        guard !text.isEmpty else {
            return false
        }

        if looksLikeFilenameOrPath(text) || looksLikeListItem(text) {
            return false
        }

        guard line.wordCount <= 7, fillRatio <= 0.62 else {
            return false
        }

        if text.range(of: #"[.!?]$"#, options: .regularExpression) != nil {
            return false
        }

        return startsLikelyNewSentence(text)
    }

    private func isShortStandalone(_ line: OCRLine, fillRatio: CGFloat) -> Bool {
        let text = line.trimmedText
        guard !text.isEmpty else {
            return false
        }

        if looksLikeFilenameOrPath(text) || looksLikeListItem(text) {
            return true
        }

        if line.wordCount <= 2 {
            return true
        }

        if line.wordCount <= 4 && fillRatio <= 0.46 && !looksLikeParagraphContinuation(previousText: text, currentText: text) {
            return true
        }

        return false
    }

    private func isNarrowStandaloneRow(_ line: OCRLine) -> Bool {
        let text = line.trimmedText
        guard !text.isEmpty else {
            return false
        }

        if looksLikeFilenameOrPath(text) || looksLikeListItem(text) {
            return true
        }

        if line.width <= 0.34 && line.wordCount <= 4 && !startsWithLowercase(text) {
            return true
        }

        return false
    }

    private func looksLikeParagraphContinuation(previousText: String, currentText: String) -> Bool {
        guard !previousText.isEmpty, !currentText.isEmpty else {
            return false
        }

        if endsSentence(previousText) {
            return false
        }

        if startsWithLowercase(currentText) {
            return true
        }

        if previousText.range(of: #"[,;:-]$"#, options: .regularExpression) != nil {
            return true
        }

        let connectorWords = [
            "and", "or", "but", "so", "for", "nor", "yet", "to", "of", "in", "on",
            "at", "with", "from", "by", "the", "a", "an", "is", "are", "was", "were"
        ]
        let firstWord = currentText
            .split(whereSeparator: { $0.isWhitespace })
            .first
            .map(String.init)?
            .trimmingCharacters(in: .punctuationCharacters)
            .lowercased() ?? ""

        if connectorWords.contains(firstWord) {
            return true
        }

        return false
    }

    private func supportsParagraphRun(previous: OCRLine, next: OCRLine, stats: LayoutStats) -> Bool {
        let leftDelta = abs(previous.minX - next.minX) / stats.contentWidth
        let nextGap = max(0, previous.minY - next.maxY)
        return leftDelta <= 0.04 && nextGap <= max(stats.medianGap * 1.3, stats.medianHeight * 0.85)
    }

    private func endsSentence(_ text: String) -> Bool {
        text.range(of: #"[.!?]$"#, options: .regularExpression) != nil
    }

    private func startsLikelyNewSentence(_ text: String) -> Bool {
        guard let scalar = text.unicodeScalars.first(where: { !CharacterSet.whitespacesAndNewlines.contains($0) }) else {
            return false
        }
        return CharacterSet.uppercaseLetters.contains(scalar)
    }

    private func startsWithLowercase(_ text: String) -> Bool {
        guard let scalar = text.unicodeScalars.first(where: { !CharacterSet.whitespacesAndNewlines.contains($0) }) else {
            return false
        }
        return CharacterSet.lowercaseLetters.contains(scalar)
    }

    private func median(_ values: [CGFloat]) -> CGFloat {
        guard !values.isEmpty else {
            return 0
        }

        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}

extension OCRService: OCRServing {}
