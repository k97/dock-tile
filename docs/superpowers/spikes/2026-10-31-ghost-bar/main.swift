// THROWAWAY SPIKE — does an .accessory (Ghost) app's NSApp.dockTile draw on its pinned Dock icon?
// Mode comes from ~/…/spike/mode.txt: "accessory" (Q1) or "switch" (Q2: .regular during the bar).
import AppKit

let spikeDir = CommandLine.arguments.count > 1 ? URL(fileURLWithPath: CommandLine.arguments[1])
    : Bundle.main.bundleURL.deletingLastPathComponent()  // the folder GhostBarSpike.app was built in
let logURL = spikeDir.appendingPathComponent("spike.log")

func log(_ s: String) {
    let line = "\(ISO8601DateFormatter().string(from: Date())) \(String(format: "%.3f", Date().timeIntervalSince1970)) \(s)\n"
    if let h = try? FileHandle(forWritingTo: logURL) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close() }
    else { try? line.write(to: logURL, atomically: true, encoding: .utf8) }
}

/// Style C: the tile darkened, a thin white bar along the bottom.
final class ProgressTileView: NSView {
    var progress: CGFloat = 0
    override func draw(_ dirtyRect: NSRect) {
        let b = bounds.insetBy(dx: bounds.width * 0.0975, dy: bounds.height * 0.0975) // icon-grid margin
        let r = b.width * 0.225
        let shape = NSBezierPath(roundedRect: b, xRadius: r, yRadius: r)
        NSGradient(starting: NSColor(srgbRed: 0.56, green: 0.36, blue: 0.97, alpha: 1),
                   ending: NSColor(srgbRed: 0.36, green: 0.17, blue: 0.84, alpha: 1))!.draw(in: shape, angle: -90)
        NSColor.black.withAlphaComponent(0.45).setFill(); shape.fill()
        let barH = b.height * 0.09, inset = b.width * 0.14
        let track = NSRect(x: b.minX + inset, y: b.minY + b.height * 0.12, width: b.width - 2 * inset, height: barH)
        NSColor.black.withAlphaComponent(0.35).setFill()
        NSBezierPath(roundedRect: track, xRadius: barH / 2, yRadius: barH / 2).fill()
        var fill = track; fill.size.width = max(barH, track.width * progress)
        NSColor.white.setFill()
        NSBezierPath(roundedRect: fill, xRadius: barH / 2, yRadius: barH / 2).fill()
    }
}

final class Delegate: NSObject, NSApplicationDelegate {
    let mode = (try? String(contentsOf: spikeDir.appendingPathComponent("mode.txt"), encoding: .utf8))?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "accessory"
    let view = ProgressTileView(frame: NSRect(x: 0, y: 0, width: 128, height: 128))

    func applicationWillFinishLaunching(_ n: Notification) { NSApp.setActivationPolicy(.accessory) }

    func applicationDidFinishLaunching(_ n: Notification) {
        log("launched pid=\(getpid()) mode=\(mode) policy=\(NSApp.activationPolicy().rawValue)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.run() }
    }

    func run() {
        if mode == "switch" {
            log("frontmost before=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil")")
            let ok = NSApp.setActivationPolicy(.regular)
            log("switch → regular ok=\(ok) policy=\(NSApp.activationPolicy().rawValue) active=\(NSApp.isActive)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                log("frontmost +1s=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil") active=\(NSApp.isActive)")
            }
        }
        NSApp.dockTile.contentView = view
        log("dockTile size=\(NSApp.dockTile.size) contentView set")
        var step = 0
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            step += 1
            self.view.progress = CGFloat(step) / 15
            self.view.needsDisplay = true
            NSApp.dockTile.display()
            log("step \(step) progress=\(String(format: "%.2f", self.view.progress))")
            if step >= 15 {
                t.invalidate()
                NSApp.dockTile.contentView = nil
                NSApp.dockTile.display()
                log("bar cleared")
                if self.mode == "switch" {
                    let ok = NSApp.setActivationPolicy(.accessory)
                    log("switch → accessory ok=\(ok) policy=\(NSApp.activationPolicy().rawValue)")
                }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        log("REOPEN (Dock click) policy=\(NSApp.activationPolicy().rawValue)")
        return false
    }
}

let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.run()
