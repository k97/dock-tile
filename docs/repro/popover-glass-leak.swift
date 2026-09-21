// Minimal NSPopover leak probe for macOS 26. See docs/macos-26-popover-glass-leak.md.
// build: swiftc -O -o popleak popover-glass-leak.swift     usage: popleak <fresh|reuse|swap> [cycles]
// fresh  = a NEW NSPopover + content controller every cycle (what Dock Tile did through 2.0.1) — LEAKS
// reuse  = ONE NSPopover + ONE content controller, shown and closed repeatedly — flat
// swap   = ONE NSPopover; content released on close and a NEW controller attached per open
//          (the variant Dock Tile ships) — flat
// inspect: heap <pid> | grep -E " NSGlassView|NSGlassEffectView.RootView" ; footprint <pid>
import AppKit
import SwiftUI

struct Content: View {
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(56)), count: 5), spacing: 12) {
            ForEach(0..<20, id: \.self) { i in
                RoundedRectangle(cornerRadius: 12).fill(.blue.opacity(0.4)).frame(width: 56, height: 56)
                    .overlay(Text("\(i)"))
            }
        }.padding(20)
    }
}

final class Probe: NSObject, NSApplicationDelegate {
    let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "fresh"
    let cycles = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2]) ?? 8 : 8
    var window: NSWindow!
    var shared: NSPopover?
    var current: NSPopover?
    var done = 0

    func makePopover() -> NSPopover {
        let p = NSPopover()
        p.behavior = .transient
        p.animates = false
        p.contentViewController = NSHostingController(rootView: Content())
        return p
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 120, height: 60),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "popleak \(mode)"
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if mode == "reuse" || mode == "swap" { shared = makePopover() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.cycle() }
    }

    func cycle() {
        guard done < cycles else {
            print("DONE mode=\(mode) cycles=\(cycles) pid=\(ProcessInfo.processInfo.processIdentifier)")
            fflush(stdout)
            return   // stay alive so heap/footprint can inspect us
        }
        let p = shared ?? makePopover()
        if mode == "swap" { p.contentViewController = NSHostingController(rootView: Content()) }  // one popover, fresh content each open
        current = p
        p.show(relativeTo: window.contentView!.bounds, of: window.contentView!, preferredEdge: .maxY)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            p.close()
            if self.mode == "swap" { p.contentViewController = nil }  // release content while hidden
            self.current = nil
            self.done += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.cycle() }
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let probe = Probe()
app.delegate = probe
app.run()
