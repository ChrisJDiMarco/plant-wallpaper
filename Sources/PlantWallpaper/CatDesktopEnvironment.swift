import CoreGraphics
import Foundation

struct CatDesktopEnvironment: Codable, Equatable {
    struct WallInsets: Codable, Equatable {
        var left: Double
        var right: Double
        var bottom: Double
    }

    enum DockSide: String, Codable {
        case none
        case bottom
        case left
        case right
    }

    static let dockInsetThreshold = 8.0

    var screenWidthPx: Double
    var screenHeightPx: Double
    var dockVisible: Bool
    var dockSide: DockSide
    var dockThicknessPx: Double
    var wallInsetsPx: WallInsets
    var effectiveGroundFraction: Double

    var fingerprint: String {
        [
            rounded(screenWidthPx),
            rounded(screenHeightPx),
            dockVisible ? "1" : "0",
            dockSide.rawValue,
            rounded(dockThicknessPx),
            rounded(wallInsetsPx.left),
            rounded(wallInsetsPx.right),
            rounded(wallInsetsPx.bottom),
            String(format: "%.4f", effectiveGroundFraction)
        ].joined(separator: "|")
    }

    init(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        baseGroundFraction: Double
    ) {
        let width = max(1, Double(screenFrame.width))
        let height = max(1, Double(screenFrame.height))
        let leftInset = max(0, Double(visibleFrame.minX - screenFrame.minX))
        let rightInset = max(0, Double(screenFrame.maxX - visibleFrame.maxX))
        let bottomInset = max(0, Double(visibleFrame.minY - screenFrame.minY))

        let candidates: [(DockSide, Double)] = [
            (.bottom, bottomInset),
            (.left, leftInset),
            (.right, rightInset)
        ].filter { $0.1 > Self.dockInsetThreshold }

        let dock = candidates.max { lhs, rhs in lhs.1 < rhs.1 }
        let dockSide = dock?.0 ?? .none
        let dockThickness = dock?.1 ?? 0
        let bottomWallInset = dockSide == .bottom ? dockThickness : 0
        let leftWallInset = dockSide == .left ? dockThickness : 0
        let rightWallInset = dockSide == .right ? dockThickness : 0

        self.screenWidthPx = width
        self.screenHeightPx = height
        self.dockVisible = dockSide != .none
        self.dockSide = dockSide
        self.dockThicknessPx = dockThickness
        self.wallInsetsPx = WallInsets(
            left: leftWallInset,
            right: rightWallInset,
            bottom: bottomWallInset
        )
        self.effectiveGroundFraction = dockSide == .bottom
            ? dockThickness / height
            : 0
    }

    func javaScriptLiteral() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private func rounded(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
