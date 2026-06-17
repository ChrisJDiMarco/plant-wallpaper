import Foundation

public struct GardenScreenSaverSnapshot: Codable, Equatable, Sendable {
    public static let filename = "screen-saver-current-garden.json"
    public static let primaryImageFilename = "screen-saver-current-garden.png"

    public var sceneKey: String?
    public var state: GardenState
    public var wallpaperImagePath: String?
    public var compositedImagePath: String?
    public var isCatCompanionEnabled: Bool?
    public var savedAt: Date

    public init(
        sceneKey: String?,
        state: GardenState,
        wallpaperImagePath: String?,
        compositedImagePath: String?,
        isCatCompanionEnabled: Bool? = nil,
        savedAt: Date = Date()
    ) {
        self.sceneKey = sceneKey
        self.state = state
        self.wallpaperImagePath = wallpaperImagePath
        self.compositedImagePath = compositedImagePath
        self.isCatCompanionEnabled = isCatCompanionEnabled
        self.savedAt = savedAt
    }

    public static func fileURL(directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent(filename)
    }

    public static func primaryImageURL(directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent(primaryImageFilename)
    }

    public static func load(from directoryURL: URL, fileManager: FileManager = .default) throws -> GardenScreenSaverSnapshot? {
        let url = fileURL(directoryURL: directoryURL)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GardenScreenSaverSnapshot.self, from: Data(contentsOf: url))
    }

    public func save(to directoryURL: URL, fileManager: FileManager = .default) throws {
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: Self.fileURL(directoryURL: directoryURL), options: [.atomic])
    }
}
