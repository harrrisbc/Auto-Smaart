import XCTest
@testable import AutoSmaartRingOut
@testable import AutoSmaartCore
@testable import ConsoleOSC
@testable import SmaartAPI

final class SourceGuardTests: XCTestCase {
    func testRingOutSourcesStayDeterministicAndCaptureFree() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("Sources/AutoSmaartRingOut")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let source = try files.filter { $0.pathExtension == "swift" }.map { try String(contentsOf: $0) }.joined(separator: "\n")
        for forbidden in ["CGWindowListCreateImage", "screencapture", "OpenAI", "ChatGPT", "model(", "random("] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
        XCTAssertTrue(source.contains("muteAddress"))
        XCTAssertFalse(source.contains("muteAll("))
        XCTAssertTrue(source.contains("SustainedPeakDetector"))
    }
}
