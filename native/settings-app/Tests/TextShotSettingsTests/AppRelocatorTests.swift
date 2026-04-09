import Foundation
import Testing
@testable import TextShotSettings

private func makeBundle(at url: URL, marker: String) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    guard let markerData = marker.data(using: .utf8) else {
        throw NSError(domain: "AppRelocatorTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode marker"])
    }
    try markerData.write(to: url.appendingPathComponent("marker.txt"))
}

private func marker(at url: URL) throws -> String {
    try String(contentsOf: url.appendingPathComponent("marker.txt"), encoding: .utf8)
}

@MainActor
@Test
func appRelocatorMovesBundleIntoEmptyDestination() throws {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let sourceURL = tempDir.appendingPathComponent("Downloads/Text Shot.app")
    let destinationURL = tempDir.appendingPathComponent("Applications/Text Shot.app")
    try makeBundle(at: sourceURL, marker: "new")

    let relocator = AppRelocator(fileManager: .default, openApplication: { _, _, _ in })
    let finalURL = try relocator.relocateAppBundle(from: sourceURL, to: destinationURL)

    #expect(finalURL.path == destinationURL.path)
    #expect(try marker(at: destinationURL) == "new")
}

@MainActor
@Test
func appRelocatorReplacesExistingDestinationBundle() throws {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let sourceURL = tempDir.appendingPathComponent("Downloads/Text Shot.app")
    let destinationURL = tempDir.appendingPathComponent("Applications/Text Shot.app")
    let backupURL = tempDir.appendingPathComponent("Applications/.Text Shot.app.backup")
    try makeBundle(at: sourceURL, marker: "new")
    try makeBundle(at: destinationURL, marker: "old")

    let relocator = AppRelocator(fileManager: .default, openApplication: { _, _, _ in })
    _ = try relocator.relocateAppBundle(from: sourceURL, to: destinationURL)

    #expect(try marker(at: destinationURL) == "new")
    #expect(FileManager.default.fileExists(atPath: backupURL.path) == false)
}

@MainActor
@Test
func appRelocatorFailedCopyLeavesExistingDestinationUntouched() throws {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let sourceURL = tempDir.appendingPathComponent("Missing/Text Shot.app")
    let destinationURL = tempDir.appendingPathComponent("Applications/Text Shot.app")
    try makeBundle(at: destinationURL, marker: "old")

    let relocator = AppRelocator(fileManager: .default, openApplication: { _, _, _ in })

    #expect(throws: Error.self) {
        _ = try relocator.relocateAppBundle(from: sourceURL, to: destinationURL)
    }
    #expect(try marker(at: destinationURL) == "old")
}
