import CoreGraphics
import Foundation

// Print the CGWindowID of the largest on-screen window owned by the given PID.
// Used so captures can target a window by identity rather than by screen rectangle.
let pid = Int(CommandLine.arguments.dropFirst().first ?? "") ?? 0
let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
let windows = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] ?? []

var bestID: Int = 0
var bestArea: Double = 0
for w in windows {
    guard (w[kCGWindowOwnerPID as String] as? Int) == pid,
          let bounds = w[kCGWindowBounds as String] as? [String: Any],
          let width = bounds["Width"] as? Double,
          let height = bounds["Height"] as? Double,
          let id = w[kCGWindowNumber as String] as? Int else { continue }
    if width * height > bestArea { bestArea = width * height; bestID = id }
}
print(bestID)
