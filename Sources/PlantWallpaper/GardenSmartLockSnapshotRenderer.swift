import AppKit
import PlantGardenCore

@MainActor
enum GardenSmartLockSnapshotRenderer {
    enum SmartLockSnapshotError: Error, LocalizedError {
        case noScreenAvailable
        case couldNotEncodeImage

        var errorDescription: String? {
            switch self {
            case .noScreenAvailable:
                "No screen is available for the AI lock snapshot."
            case .couldNotEncodeImage:
                "Could not encode the AI lock snapshot."
            }
        }
    }

    static func sourceImageData(
        store: GardenStore,
        screen: NSScreen? = nil,
        wallpaperImageURL: URL? = nil
    ) throws -> Data {
        guard let screen = screen ?? NSScreen.screens.first ?? NSScreen.main else {
            throw SmartLockSnapshotError.noScreenAvailable
        }

        let screenIndex = NSScreen.screens.firstIndex(of: screen) ?? 0
        // Use the app's clean snapshot renderer instead of raw screen capture so
        // AI Lock View never sends desktop icons, windows, Dock, or menu bar UI.
        return try GardenDesktopSnapshotRenderer.snapshotPNGData(
            store: store,
            screen: screen,
            screenIndex: screenIndex,
            wallpaperImageURL: wallpaperImageURL
        )
    }
}
