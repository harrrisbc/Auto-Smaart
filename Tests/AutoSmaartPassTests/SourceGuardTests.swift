import XCTest

final class SourceGuardTests: XCTestCase {
    func testSourcesStayInsideTheSpec() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources")
        var text = ""
        let enumerator = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)!
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            text += try String(contentsOf: url)
        }
        for forbidden in ["CGWindowListCreateImage", "screencapture", "openai", "Double.random", "Yamaha", "PM10", "X32"] {
            XCTAssertFalse(text.contains(forbidden), forbidden)
        }
        XCTAssertTrue(text.contains("ws://127.0.0.1:26000/api/v4/"))
        XCTAssertTrue(text.contains("/sd/Matrix_Outputs/"))
    }
}
