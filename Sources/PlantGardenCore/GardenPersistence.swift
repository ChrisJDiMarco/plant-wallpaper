import Foundation

public enum GardenPersistenceError: Error, Equatable {
    case couldNotCreateDirectory(URL)
}

public final class GardenPersistence {
    public let directoryURL: URL
    public let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL ?? GardenPersistence.defaultDirectoryURL(fileManager: fileManager)
        self.fileURL = self.directoryURL.appendingPathComponent("garden.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func load() throws -> GardenState? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(GardenState.self, from: data)
    }

    public func load(sceneKey: String) throws -> GardenState? {
        let sceneFileURL = fileURL(forSceneKey: sceneKey)
        guard fileManager.fileExists(atPath: sceneFileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: sceneFileURL)
        return try decoder.decode(GardenState.self, from: data)
    }

    public func save(_ state: GardenState) throws {
        guard ensureDirectoryExists() else {
            throw GardenPersistenceError.couldNotCreateDirectory(directoryURL)
        }

        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func save(_ state: GardenState, sceneKey: String) throws {
        guard ensureDirectoryExists() else {
            throw GardenPersistenceError.couldNotCreateDirectory(directoryURL)
        }

        let data = try encoder.encode(state)
        try data.write(to: fileURL(forSceneKey: sceneKey), options: [.atomic])
    }

    @discardableResult
    public func quarantineGardenFile(sceneKey: String? = nil, at date: Date = Date()) throws -> URL? {
        let sourceURL = sceneKey.map(fileURL(forSceneKey:)) ?? fileURL
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: date)
        let destinationURL = sourceURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(sourceURL.lastPathComponent).corrupt-\(stamp)")
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    public func fileURL(forSceneKey sceneKey: String) -> URL {
        let safeKey = Self.safeFilenameComponent(sceneKey)
        let filename = safeKey.isEmpty ? "garden-scene.json" : "garden-\(safeKey).json"
        return directoryURL.appendingPathComponent(filename)
    }

    public static func defaultDirectoryURL(fileManager: FileManager = .default) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())

        return baseURL
            .appendingPathComponent("WallpaperGarden", isDirectory: true)
            .appendingPathComponent("PlantWallpaper", isDirectory: true)
    }

    private func ensureDirectoryExists() -> Bool {
        if fileManager.fileExists(atPath: directoryURL.path) {
            return true
        }

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }

    private static func safeFilenameComponent(_ value: String) -> String {
        value
            .map { character in
                character.isLetter || character.isNumber || character == "-" ? character : "-"
            }
            .reduce(into: "") { $0.append($1) }
    }
}
