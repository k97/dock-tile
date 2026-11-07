import Foundation
import Testing
@testable import Dock_Tile

/// The one-main-app lock (issue #13). Failing values: Dock Tile refusing to open because the lock
/// file could not be made, a second copy running, a double-click that ends with nothing on screen,
/// or a login launch stealing focus. The real-file test pins the errno `main.swift` reads.
@Suite("Main-app lock")
struct MainAppLockTests {

    @Test("Took the lock: run")
    func acquired() {
        #expect(MainAppLock.outcome(acquired: true, busy: false, quiet: false) == .run)
        #expect(MainAppLock.outcome(acquired: true, busy: false, quiet: true) == .run)
    }

    @Test("The lock could not be made: run without it, never refuse to open")
    func lockError() {
        #expect(MainAppLock.outcome(acquired: false, busy: false, quiet: false) == .runUnlocked)
        #expect(MainAppLock.outcome(acquired: false, busy: false, quiet: true) == .runUnlocked)
    }

    @Test("Another copy holds it: the user's launch hands off, the login launch exits")
    func anotherCopy() {
        #expect(MainAppLock.outcome(acquired: false, busy: true, quiet: false) == .handOff)
        #expect(MainAppLock.outcome(acquired: false, busy: true, quiet: true) == .exit)
    }

    @Test("A held lock fails a second open with EWOULDBLOCK; a lock that cannot be made does not")
    func realLockErrno() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("MainAppLockTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = try #require(TileBuildLock.acquire(bundleId: "main-app", stagingDirectory: dir))
        let second = TileBuildLock.acquire(bundleId: "main-app", stagingDirectory: dir)
        let busyErrno = errno
        #expect(second == nil)
        #expect(busyErrno == EWOULDBLOCK)
        first.release()
        #expect(TileBuildLock.acquire(bundleId: "main-app", stagingDirectory: dir) != nil)

        // A regular file where the folder should be: the open fails, and not as "busy".
        let file = dir.appendingPathComponent("not-a-folder")
        try Data().write(to: file)
        let broken = TileBuildLock.acquire(bundleId: "main-app", stagingDirectory: file)
        let brokenErrno = errno
        #expect(broken == nil)
        #expect(brokenErrno != EWOULDBLOCK)
    }
}
