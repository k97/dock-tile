// Launch an app bundle and report the time until its first normal-layer window is on screen.
// usage: swift launch_timer.swift "/path/to/App.app"
import AppKit
import CoreGraphics

let appURL = URL(fileURLWithPath: CommandLine.arguments[1])
let config = NSWorkspace.OpenConfiguration()
config.activates = true
var launchedPID: pid_t = 0
let sema = DispatchSemaphore(value: 0)
let t0 = DispatchTime.now()
NSWorkspace.shared.openApplication(at: appURL, configuration: config) { app, error in
    if let error { FileHandle.standardError.write("launch failed: \(error)\n".data(using: .utf8)!) }
    launchedPID = app?.processIdentifier ?? 0
    sema.signal()
}
sema.wait()
guard launchedPID != 0 else { exit(1) }

func ms(_ a: DispatchTime, _ b: DispatchTime) -> Double { Double(b.uptimeNanoseconds - a.uptimeNanoseconds) / 1e6 }

var windowMs: Double = -1
let deadline = DispatchTime.now() + .seconds(30)
while DispatchTime.now() < deadline {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    let hit = list.contains { w in
        guard (w[kCGWindowOwnerPID as String] as? pid_t) == launchedPID,
              (w[kCGWindowLayer as String] as? Int) == 0,
              let b = w[kCGWindowBounds as String] as? [String: CGFloat] else { return false }
        return (b["Width"] ?? 0) > 300 && (b["Height"] ?? 0) > 300
    }
    if hit { windowMs = ms(t0, DispatchTime.now()); break }
    usleep(4000)
}
guard windowMs >= 0 else {
    print(String(format: "pid=%d  TIMEOUT: no window on screen within 30s", launchedPID))
    exit(1)
}
print(String(format: "pid=%d  first-window-on-screen=%.0f ms", launchedPID, windowMs))
