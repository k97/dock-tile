import Foundation
import Testing
@testable import Dock_Tile

/// Multi-line messages used to leave untimestamped continuation lines in the shared log, and the
/// launch trim kept every line it could not date — so they lived forever. Failing values: a
/// message that still contains a newline; an orphan line surviving the trim.
@Suite("Diagnostics log trimming")
struct DiagnosticsLogTrimTests {

    private let cutoff = Date(timeIntervalSince1970: 1_000)
    private func parse(_ token: String) -> Date? {
        guard let seconds = TimeInterval(token) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    @Test("A message is flattened to one line")
    func messagesAreSingleLine() {
        #expect(DiagnosticsLog.singleLine("compile failed:\nassetutil: bad file\r\nexit 1") == "compile failed: ⏎ assetutil: bad file ⏎ exit 1")
        #expect(DiagnosticsLog.singleLine("plain") == "plain")
    }

    /// The boundary line is the point of this fixture. With only 500/1500/2000 against a cutoff of
    /// 1000, flipping the implementation's `date >= cutoff` to `date > cutoff` still passed — the
    /// test could not fail against the off-by-one it exists to catch. A line dated exactly at the
    /// cutoff is kept, so `>` drops it and this test fails.
    @Test("Lines older than the cutoff are dropped, the cutoff itself is kept, order preserved")
    func trimsByDate() {
        let content = "500 [main] old\n1000 [main] boundary\n1500 [main] new-a\n2000 [main] new-b\n"
        #expect(DiagnosticsLog.trimmed(content, cutoff: cutoff, parse: parse)
                == "1000 [main] boundary\n1500 [main] new-a\n2000 [main] new-b\n")
    }

    @Test("An undated line shares the fate of the dated line before it; leading orphans are dropped")
    func orphansFollowTheirParent() {
        let content = "assetutil: orphan at top\n500 [main] old\nassetutil: belongs to old\n1500 [main] new\nassetutil: belongs to new\n"
        #expect(DiagnosticsLog.trimmed(content, cutoff: cutoff, parse: parse) == "1500 [main] new\nassetutil: belongs to new\n")
    }

    @Test("Nothing kept yields an empty file, not a lone newline")
    func emptyResult() {
        #expect(DiagnosticsLog.trimmed("500 [main] old\n", cutoff: cutoff, parse: parse) == "")
    }
}
