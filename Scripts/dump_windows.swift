import CoreGraphics
import Foundation

// Diagnostic: prints every on-screen window at layer >= 0 (the ones that can
// block desktop garden interaction). Run a baseline normally, then run again
// WHILE a macOS screen recording is active to spot the screen-capture overlay
// window that breaks cat mouse tracking.

func numericValue(_ value: Any?) -> Double? {
    switch value {
    case let number as NSNumber: return number.doubleValue
    case let value as Double: return value
    case let value as Int: return Double(value)
    default: return nil
    }
}

guard let windowInfo = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
    print("Could not read window list")
    exit(1)
}

let mainHeight = CGDisplayPixelsHigh(CGMainDisplayID())
let mainWidth = CGDisplayPixelsWide(CGMainDisplayID())
print("=== macOS window dump | main display \(mainWidth)x\(mainHeight) ===")
print(String(format: "%-26@ %-30@ %6@ %6@  bounds", "OWNER" as NSString, "NAME" as NSString, "LAYER" as NSString, "ALPHA" as NSString))

let rows = windowInfo.compactMap { info -> (Int, String)? in
    guard let bounds = info[kCGWindowBounds as String] as? [String: Any],
          let x = numericValue(bounds["X"]),
          let y = numericValue(bounds["Y"]),
          let w = numericValue(bounds["Width"]),
          let h = numericValue(bounds["Height"]) else { return nil }
    let layer = Int(numericValue(info[kCGWindowLayer as String]) ?? 0)
    let alpha = numericValue(info[kCGWindowAlpha as String]) ?? 1
    let owner = info[kCGWindowOwnerName as String] as? String ?? ""
    let name = info[kCGWindowName as String] as? String ?? ""
    // Only windows that could block: layer >= 0, visible, and sizable.
    guard layer >= 0, alpha > 0.01, w * h >= 200 * 200 else { return nil }
    let line = String(
        format: "%-26@ %-30@ %6d %6.2f  [%.0f,%.0f %.0fx%.0f]",
        owner as NSString, name as NSString, layer, alpha, x, y, w, h
    )
    return (layer, line)
}

for (_, line) in rows.sorted(by: { $0.0 > $1.0 }) {
    print(line)
}
print("=== \(rows.count) blocking-capable windows ===")
