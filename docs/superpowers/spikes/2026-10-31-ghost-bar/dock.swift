// THROWAWAY SPIKE Dock tool. Usage: dock.swift backup <file> | pin <app> | unpin | wid
// pin/unpin write persistent-apps then SIGKILL the Dock (the 2.6.2 write-then-SIGKILL rule).
import Foundation
import CoreGraphics

let dock = "com.apple.dock" as CFString
let spikeId = "com.k97.spike.ghostbar"
let args = CommandLine.arguments

func apps() -> [[String: Any]] {
    CFPreferencesAppSynchronize(dock)
    return CFPreferencesCopyAppValue("persistent-apps" as CFString, dock) as? [[String: Any]] ?? []
}
func write(_ a: [[String: Any]]) {
    CFPreferencesSetAppValue("persistent-apps" as CFString, a as CFArray, dock)
    guard CFPreferencesAppSynchronize(dock) else { print("SYNC FAILED"); exit(1) }
    let k = Process(); k.executableURL = URL(fileURLWithPath: "/usr/bin/killall"); k.arguments = ["-KILL", "Dock"]
    try! k.run(); k.waitUntilExit()
}
func isSpike(_ e: [String: Any]) -> Bool { ((e["tile-data"] as? [String: Any])?["bundle-identifier"] as? String) == spikeId }

switch args.count > 1 ? args[1] : "" {
case "backup":
    let data = try! PropertyListSerialization.data(fromPropertyList: apps(), format: .xml, options: 0)
    try! data.write(to: URL(fileURLWithPath: args[2])); print("backed up \(apps().count) entries")
case "pin":
    var a = apps().filter { !isSpike($0) }
    a.append(["GUID": Int(Date().timeIntervalSince1970) % Int(Int32.max), "tile-type": "file-tile",
              "tile-data": ["bundle-identifier": spikeId, "dock-extra": 0, "file-label": "GhostBarSpike",
                            "file-type": 41, "file-data": ["_CFURLString": "file://\(args[2])/", "_CFURLStringType": 15]]])
    write(a); print("pinned; entries=\(a.count)")
case "unpin":
    let before = apps(); let a = before.filter { !isSpike($0) }
    guard a.count < before.count else { print("not pinned; nothing written"); exit(0) }
    write(a); print("unpinned; entries=\(a.count)")
case "check":
    print("spike entries: \(apps().filter(isSpike).count) of \(apps().count)")
case "wid":
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    let w = info.filter { ($0[kCGWindowOwnerName as String] as? String) == "Dock" && ($0[kCGWindowLayer as String] as? Int) == 20 }
        .max { (($0[kCGWindowBounds as String] as? [String: CGFloat])?["Width"] ?? 0) < (($1[kCGWindowBounds as String] as? [String: CGFloat])?["Width"] ?? 0) }
    print(w?[kCGWindowNumber as String] as? Int ?? -1)
default:
    print("usage: backup <file> | pin <app> | unpin | check | wid"); exit(2)
}
