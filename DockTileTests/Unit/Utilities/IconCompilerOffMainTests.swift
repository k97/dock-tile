import Foundation
import Testing
@testable import Dock_Tile

/// The off-main wrapper must surface exactly the errors the synchronous compiler throws — a
/// wrapper that swallowed them would let a helper ship without a validated `Assets.car`.
/// Failing value: no error, or a different error, for a compiler that does not exist.
///
/// **What is guarded structurally rather than here, and where that stops.** Two of this wrapper's
/// three risks are not testable at this level, and pretending otherwise would add tests that cannot
/// fail:
/// - *Returning the wrong value* — `compileOffMain` is `async throws -> URL` and its body is
///   `continuation.resume(with: Result { try compile(...) })`, which cannot substitute a different
///   URL. Non-optional return plus a `Result` pass-through is the guarantee; there is no seam to
///   inject a fake compile through.
/// - *Calling the blocking version from async code* — prevented at compile time by
///   `@available(*, noasync)` on `IconCompiler.compile`, which no runtime test can assert.
/// - *Resuming the continuation twice or never* — a double resume traps and a missing resume hangs,
///   so the test below failing to complete IS that guard. It is not a `#expect`.
///
/// Genuinely NOT guarded: that the compile really runs off the main thread. Observing the executing
/// thread from inside the continuation needs a seam the type does not expose, and the success path
/// needs the vendored `docktile-actool` plus an `.icon` document that survives `assetutil`
/// validation, which is an integration test and not this suite's job. Stated plainly rather than
/// papered over.
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
