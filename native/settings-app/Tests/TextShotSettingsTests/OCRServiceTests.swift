import CoreGraphics
import Testing
@testable import TextShotSettings

private func fragment(
    _ text: String,
    x: CGFloat,
    y: CGFloat,
    width: CGFloat,
    height: CGFloat = 0.08
) -> OCRService.OCRFragment {
    OCRService.OCRFragment(text: text, boundingBox: CGRect(x: x, y: y, width: width, height: height))
}

private func line(
    _ text: String,
    y: CGFloat,
    x: CGFloat = 0.1,
    width: CGFloat,
    height: CGFloat = 0.08
) -> [OCRService.OCRFragment] {
    [fragment(text, x: x, y: y, width: width, height: height)]
}

private func splitLine(
    _ parts: [(text: String, x: CGFloat, width: CGFloat)],
    y: CGFloat,
    height: CGFloat = 0.08
) -> [OCRService.OCRFragment] {
    parts.map { fragment($0.text, x: $0.x, y: y, width: $0.width, height: height) }
}

private func block(
    _ lines: [(text: String, width: CGFloat)],
    startY: CGFloat,
    lineGap: CGFloat,
    x: CGFloat = 0.1,
    height: CGFloat = 0.08
) -> [OCRService.OCRFragment] {
    lines.enumerated().flatMap { index, entry in
        line(entry.text, y: startY - CGFloat(index) * lineGap, x: x, width: entry.width, height: height)
    }
}

private func capture(_ blocks: [OCRService.OCRFragment]...) -> [OCRService.OCRFragment] {
    blocks.flatMap { $0 }
}

@Test
func ocrCleanupTrimsWhitespaceAndExcessNewlines() {
    let service = OCRService()
    let input = "Hello   \n\n\nWorld   \n"
    #expect(service.cleanupOcrText(input) == "Hello\n\nWorld")
}

@Test
func ocrCleanupDropsPunctuationArtifacts() {
    let service = OCRService()
    let input = "Actual\n....\n|\nText"
    #expect(service.cleanupOcrText(input) == "Actual\nText")
}

@Test
func ocrCleanupPreservesSingleCharacterLines() {
    let service = OCRService()
    let input = "A\n1\nText"
    #expect(service.cleanupOcrText(input) == "A\n1\nText")
}

@Test
func ocrAssembleTextFlattensThreeLineParagraph() {
    let service = OCRService()
    let fragments = block(
        [
            ("We need to", 0.46),
            ("ship this now", 0.51),
            ("before Friday", 0.49)
        ],
        startY: 0.82,
        lineGap: 0.11
    )

    #expect(service.assembleText(from: fragments) == "We need to ship this now before Friday")
}

@Test
func ocrAssembleTextFlattensParagraphWithContinuationPunctuation() {
    let service = OCRService()
    let fragments = block(
        [
            ("This app should be fast,", 0.67),
            ("stable, and easy", 0.55),
            ("to trust.", 0.33)
        ],
        startY: 0.82,
        lineGap: 0.11
    )

    #expect(service.assembleText(from: fragments) == "This app should be fast, stable, and easy to trust.")
}

@Test
func ocrAssembleTextPreservesNewlinesForShortListItems() {
    let service = OCRService()
    let fragments = block(
        [
            ("Applications", 0.2),
            ("Desktop", 0.15),
            ("Documents", 0.2)
        ],
        startY: 0.82,
        lineGap: 0.12
    )

    #expect(service.assembleText(from: fragments) == "Applications\nDesktop\nDocuments")
}

@Test
func ocrAssembleTextPreservesNewlinesForLongFilenames() {
    let service = OCRService()
    let fragments = block(
        [
            ("Quarterly Report Final Revised.pdf", 0.62),
            ("Expense Export March 2026.csv", 0.58)
        ],
        startY: 0.8,
        lineGap: 0.12
    )

    #expect(service.assembleText(from: fragments) == "Quarterly Report Final Revised.pdf\nExpense Export March 2026.csv")
}

@Test
func ocrAssembleTextDoesNotTreatSentenceWithPeriodsAsFilenameList() {
    let service = OCRService()
    let fragments = block(
        [
            ("We changed the parser.", 0.56),
            ("It now joins lines", 0.5),
            ("more carefully.", 0.42)
        ],
        startY: 0.82,
        lineGap: 0.11
    )

    #expect(service.assembleText(from: fragments) == "We changed the parser. It now joins lines more carefully.")
}

@Test
func ocrAssembleTextHeadingThenParagraph() {
    let service = OCRService()
    let fragments = capture(
        block([("Release Notes", 0.24)], startY: 0.85, lineGap: 0.11),
        block(
            [
                ("This build fixes OCR line", 0.6),
                ("joining for wrapped paragraphs.", 0.71)
            ],
            startY: 0.72,
            lineGap: 0.11
        )
    )

    #expect(service.assembleText(from: fragments) == "Release Notes\nThis build fixes OCR line joining for wrapped paragraphs.")
}

@Test
func ocrAssembleTextListThenParagraph() {
    let service = OCRService()
    let fragments = capture(
        block(
            [
                ("Applications", 0.2),
                ("Desktop", 0.15)
            ],
            startY: 0.85,
            lineGap: 0.12
        ),
        block(
            [
                ("This is a wrapped paragraph line", 0.74),
                ("that should continue naturally", 0.7)
            ],
            startY: 0.62,
            lineGap: 0.11
        )
    )

    #expect(service.assembleText(from: fragments) == "Applications\nDesktop\nThis is a wrapped paragraph line that should continue naturally")
}

@Test
func ocrAssembleTextParagraphThenList() {
    let service = OCRService()
    let fragments = capture(
        block(
            [
                ("This is a wrapped paragraph line", 0.74),
                ("that should continue naturally", 0.7)
            ],
            startY: 0.84,
            lineGap: 0.11
        ),
        block(
            [
                ("Applications", 0.2),
                ("Desktop", 0.15)
            ],
            startY: 0.6,
            lineGap: 0.12
        )
    )

    #expect(service.assembleText(from: fragments) == "This is a wrapped paragraph line that should continue naturally\nApplications\nDesktop")
}

@Test
func ocrAssembleTextListParagraphList() {
    let service = OCRService()
    let fragments = capture(
        block(
            [
                ("Applications", 0.2),
                ("Desktop", 0.15)
            ],
            startY: 0.9,
            lineGap: 0.12
        ),
        block(
            [
                ("This text still belongs to one", 0.67),
                ("sentence even though it wraps", 0.7)
            ],
            startY: 0.66,
            lineGap: 0.11
        ),
        block(
            [
                ("Downloads", 0.19),
                ("Documents", 0.2)
            ],
            startY: 0.42,
            lineGap: 0.12
        )
    )

    #expect(service.assembleText(from: fragments) == "Applications\nDesktop\nThis text still belongs to one sentence even though it wraps\nDownloads\nDocuments")
}

@Test
func ocrAssembleTextPreservesBlankLineBetweenParagraphBlocks() {
    let service = OCRService()
    let fragments = capture(
        block(
            [
                ("This text should flatten", 0.52),
                ("into one sentence", 0.44)
            ],
            startY: 0.82,
            lineGap: 0.11
        ),
        block(
            [
                ("This should start", 0.39),
                ("a new paragraph", 0.37)
            ],
            startY: 0.45,
            lineGap: 0.11
        )
    )

    #expect(service.assembleText(from: fragments) == "This text should flatten into one sentence\n\nThis should start a new paragraph")
}

@Test
func ocrAssembleTextMergesSplitFragmentsOnSingleVisualLine() {
    let service = OCRService()
    let fragments = capture(
        splitLine(
            [
                ("This formatter", 0.1, 0.28),
                ("should stay", 0.43, 0.22)
            ],
            y: 0.82
        ),
        line("fast and predictable.", y: 0.71, width: 0.48)
    )

    #expect(service.assembleText(from: fragments) == "This formatter should stay fast and predictable.")
}

@Test
func ocrAssembleTextMixedCaptureWithSplitListAndParagraph() {
    let service = OCRService()
    let fragments = capture(
        splitLine(
            [
                ("Quarterly", 0.1, 0.16),
                ("Report.pdf", 0.31, 0.19)
            ],
            y: 0.88
        ),
        line("Next Item", y: 0.76, width: 0.17),
        splitLine(
            [
                ("This paragraph", 0.1, 0.25),
                ("line was split", 0.39, 0.22)
            ],
            y: 0.56
        ),
        line("and should merge naturally.", y: 0.45, width: 0.58)
    )

    #expect(service.assembleText(from: fragments) == "Quarterly Report.pdf\nNext Item\nThis paragraph line was split and should merge naturally.")
}
