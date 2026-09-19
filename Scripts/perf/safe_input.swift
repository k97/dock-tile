// Guarded synthetic input for performance measurement. Every pointer event is preceded by a check
// that the topmost window under the target point is owned by the expected pid; on any mismatch the
// tool stops.
//
//   swift safe_input.swift windows <pid>
//   swift safe_input.swift hover   <pid> <seconds>
//   swift safe_input.swift drag    <pid> <x1> <y1> <x2> <y2> <seconds>
// There is deliberately no keyboard mode: the project rule is never to synthesise keystrokes.
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count >= 3, let pid = pid_t(args[2]) else { print("usage: see header"); exit(2) }
let mode = args[1]

func onScreenWindows() -> [[String: Any]] {
    CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
}

func bounds(_ w: [String: Any]) -> CGRect? {
    guard let b = w[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
    return CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0)
}

/// Topmost on-screen window containing the point must belong to `pid`. The Dock and the Window
/// Server keep full-screen transparent overlay windows above everything; those are skipped.
func pointBelongs(_ p: CGPoint, to pid: pid_t) -> Bool {
    for w in onScreenWindows() {   // front-to-back
        let owner = w[kCGWindowOwnerName as String] as? String ?? ""
        if owner == "Dock" || owner == "Window Server" { continue }
        guard let r = bounds(w), r.contains(p) else { continue }
        return (w[kCGWindowOwnerPID as String] as? pid_t) == pid
    }
    return false
}

func post(_ type: CGEventType, _ p: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
}

let original = CGEvent(source: nil)?.location ?? .zero

switch mode {
case "windows":
    for w in onScreenWindows() where (w[kCGWindowOwnerPID as String] as? pid_t) == pid {
        print("layer=\(w[kCGWindowLayer as String] ?? 0) bounds=\(bounds(w) ?? .zero) name=\(w[kCGWindowName as String] ?? "")")
    }

case "hover":
    let seconds = Double(args[3]) ?? 5
    guard let r0 = onScreenWindows().first(where: { ($0[kCGWindowOwnerPID as String] as? pid_t) == pid && (bounds($0)?.width ?? 0) > 100 }).flatMap(bounds) else {
        print("no window for pid"); exit(1)
    }
    let r = r0.insetBy(dx: 24, dy: 48)
    let end = Date().addingTimeInterval(seconds)
    var t = 0.0, moves = 0
    while Date() < end {
        let p = CGPoint(x: r.midX + (r.width / 2) * CGFloat(sin(t * 1.7)), y: r.midY + (r.height / 2) * CGFloat(sin(t * 2.9)))
        guard pointBelongs(p, to: pid) else { print("ABORT: point left pid \(pid) after \(moves) moves"); break }
        post(.mouseMoved, p); moves += 1
        t += 0.05; usleep(16_000)
    }
    CGWarpMouseCursorPosition(original)
    print("hover done: \(moves) moves")

case "drag":
    guard args.count >= 8, let x1 = Double(args[3]), let y1 = Double(args[4]),
          let x2 = Double(args[5]), let y2 = Double(args[6]), let seconds = Double(args[7]) else { print("usage: see header"); exit(2) }
    let a = CGPoint(x: x1, y: y1), b = CGPoint(x: x2, y: y2)
    guard pointBelongs(a, to: pid), pointBelongs(b, to: pid) else { print("ABORT: drag endpoints are not over pid \(pid)"); exit(1) }
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { print("ABORT: pid \(pid) is not frontmost"); exit(1) }
    post(.leftMouseDown, a)
    let end = Date().addingTimeInterval(seconds)
    var t = 0.0, moves = 0
    while Date() < end {
        let f = CGFloat((sin(t) + 1) / 2)
        let p = CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
        guard pointBelongs(p, to: pid) else { print("ABORT mid-drag"); break }
        post(.leftMouseDragged, p); moves += 1
        t += 0.12; usleep(16_000)
    }
    post(.leftMouseUp, CGEvent(source: nil)?.location ?? a)
    CGWarpMouseCursorPosition(original)
    print("drag done: \(moves) drag events")

default:
    print("unknown mode")
}
