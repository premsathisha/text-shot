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

@Test
func ocrAssembleTextKeepsNumberedFinderRowsOnSeparateLines() {
    let service = OCRService()
    let fragments = block(
        [
            ("01 Code", 0.17),
            ("02 Research", 0.22),
            ("03 University of Arizona", 0.42),
            ("04 Other", 0.18)
        ],
        startY: 0.88,
        lineGap: 0.11
    )

    #expect(
        service.assembleText(from: fragments)
            == "01 Code\n02 Research\n03 University of Arizona\n04 Other"
    )
}

@Test
func ocrAssembleTextKeepsNumberedFinderRowsSeparatedFromArchiveLabel() {
    let service = OCRService()
    let fragments = block(
        [
            ("01 Code", 0.17),
            ("02 Research", 0.22),
            ("03 University of Arizona", 0.42),
            ("04 Other", 0.18),
            ("05 Other", 0.18),
            ("Archive (Do Not Add/Modify)", 0.48)
        ],
        startY: 0.88,
        lineGap: 0.11
    )

    #expect(
        service.assembleText(from: fragments)
            == "01 Code\n02 Research\n03 University of Arizona\n04 Other\n05 Other\nArchive (Do Not Add/Modify)"
    )
}

@Test
func ocrAssembleTextMergesWrappedSentenceThatStartsWithDigits() {
    let service = OCRService()
    let fragments = block(
        [
            ("100 ways this app saves time", 0.62),
            ("for people who capture text often", 0.72)
        ],
        startY: 0.82,
        lineGap: 0.11
    )

    #expect(
        service.assembleText(from: fragments)
            == "100 ways this app saves time for people who capture text often"
    )
}

@Test
func ocrAssembleTextMergesWrappedDigitLedHeadlineWithUppercaseTail() {
    let service = OCRService()
    let fragments = block(
        [
            ("10 Ways OCR Gets Better", 0.52),
            ("When Context Stays Intact", 0.56)
        ],
        startY: 0.82,
        lineGap: 0.11
    )

    #expect(
        service.assembleText(from: fragments)
            == "10 Ways OCR Gets Better When Context Stays Intact"
    )
}

@Test
func ocrAssembleTextMergesShortWrappedTitleTail() {
    let service = OCRService()
    let fragments = capture(
        block(
            [
                ("$1 vs $1,000,000,000 Nuclear", 0.66),
                ("Bunker!", 0.2),
                ("MrBeast", 0.14)
            ],
            startY: 0.88,
            lineGap: 0.11
        ),
        line("156M views • 6 months ago", y: 0.55, width: 0.42)
    )

    #expect(
        service.assembleText(from: fragments)
            == "$1 vs $1,000,000,000 Nuclear Bunker!\nMrBeast\n156M views • 6 months ago"
    )
}

@Test
func ocrAssembleTextPreservesIntentionalSentenceBreaksWhileFlatteningWrappedLines() {
    let service = OCRService()
    let fragments = block(
        [
            ("It is time to upgrade that machine!", 0.7),
            ("The new model will be better!", 0.58),
            ("It proves that no machine/system is", 0.74),
            ("perfect and failure is not an option!", 0.78),
            ("We should adjust our perceptions to", 0.7),
            ("understand this \"broken\"", 0.53),
            ("information.", 0.22)
        ],
        startY: 0.9,
        lineGap: 0.11
    )

    #expect(
        service.assembleText(from: fragments)
            == """
            It is time to upgrade that machine!
            The new model will be better!
            It proves that no machine/system is perfect and failure is not an option!
            We should adjust our perceptions to understand this "broken" information.
            """
    )
}

@Test
func ocrAssembleTextFlattensLongParagraphIntoOneBlock() {
    let service = OCRService()
    let fragments = block(
        [
            ("AI is rapidly becoming \"base-layer labor\" for software:", 0.84),
            ("it can draft code, refactor, and help debug, which", 0.82),
            ("meaningfully increases throughput for many developers", 0.83),
            ("yet it also increases the downstream need for human", 0.81),
            ("responsibility in security, reliability, and long-term maintainability.", 0.92)
        ],
        startY: 0.88,
        lineGap: 0.105
    )

    #expect(
        service.assembleText(from: fragments)
            == """
            AI is rapidly becoming "base-layer labor" for software: it can draft code, refactor, and help debug, which meaningfully increases throughput for many developers yet it also increases the downstream need for human responsibility in security, reliability, and long-term maintainability.
            """
    )
}

@Test
func ocrAssembleTextMergesWrappedSentenceThatStartsWithThreeDigits() {
    let service = OCRService()
    let fragments = block(
        [
            ("100 ways this app saves time", 0.62),
            ("for people who capture text often.", 0.7)
        ],
        startY: 0.84,
        lineGap: 0.11
    )

    #expect(
        service.assembleText(from: fragments)
            == "100 ways this app saves time for people who capture text often."
    )
}

@Test
func ocrAssembleTextPreservesDocumentsFolderOrderingWithTrailingArchiveRow() {
    let service = OCRService()
    let fragments = block(
        [
            ("01 Code", 0.17),
            ("02 Research", 0.22),
            ("03 University of Arizona", 0.42),
            ("04 Other", 0.18),
            ("05 Other", 0.18),
            ("Archive (Do Not Add/Modify)", 0.47)
        ],
        startY: 0.92,
        lineGap: 0.11
    )

    #expect(
        service.assembleText(from: fragments)
            == """
            01 Code
            02 Research
            03 University of Arizona
            04 Other
            05 Other
            Archive (Do Not Add/Modify)
            """
    )
}
