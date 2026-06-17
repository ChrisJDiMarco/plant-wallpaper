import Foundation

extension Bundle {
    /// The processed resource bundle (`WallpaperGarden_PlantWallpaper.bundle`).
    ///
    /// In a packaged, code-signed `.app` the resource bundle must live inside
    /// `Contents/Resources/` — code signing forbids any item at the bundle root,
    /// but SwiftPM's generated `Bundle.module` only looks for the bundle next to
    /// `Bundle.main` (the app root). This helper checks `Contents/Resources/`
    /// first so the signed app finds its resources, and falls back to
    /// `Bundle.module` for `swift run`, unit tests, and unsigned dev builds.
    static let appResources: Bundle = {
        let bundleName = "WallpaperGarden_PlantWallpaper.bundle"
        if let resourceURL = Bundle.main.resourceURL,
           let bundle = Bundle(url: resourceURL.appendingPathComponent(bundleName)) {
            return bundle
        }
        return .module
    }()
}
