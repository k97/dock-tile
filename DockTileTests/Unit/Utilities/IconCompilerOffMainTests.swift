import Foundation
import Testing
@testable import Dock_Tile

/// The off-main wrapper must surface exactly the errors the synchronous compiler throws — a
/// wrapper that swallowed them would let a helper ship without a validated `Assets.car`.
/// Failing value: no error, or a different error, for a compiler that does not exist.
@Suite("Icon compiler off the main actor")
struct IconCompilerOffMainTests {

    @Test("A missing compiler still throws compilerMissing through the async wrapper")
    func missingCompilerPropagates() async {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("offmain-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: scratch) }
        await #expect(throws: IconCompilerError.self) {
            _ = try await IconCompiler.compileOffMain(
                document: scratch.appendingPathComponent("AppIcon.icon"),
                outputDir: scratch.appendingPathComponent("out"),
                compilerURL: URL(fileURLWithPath: "/nonexistent/docktile-actool"))
        }
    }
}
