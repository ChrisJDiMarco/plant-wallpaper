import Foundation

public struct GardenSceneVisualProfile: Equatable, Sendable {
    public let sceneKey: String
    public let lightDirectionX: Double
    public let lightDirectionY: Double
    public let shadowLengthMultiplier: Double
    public let shadowOpacityMultiplier: Double
    public let contactSoftness: Double
    public let warmth: Double
    public let humidity: Double
    public let mistOpacity: Double
    public let dustMoteOpacity: Double
    public let wildlifeDensity: Double
    public let foregroundOcclusionBands: [GardenSceneOcclusionBand]

    public init(sceneKey: String?) {
        let key = sceneKey ?? "empty-conservatory-hall"
        let preset = Self.preset(for: key)
        self.sceneKey = key
        lightDirectionX = preset.lightDirectionX
        lightDirectionY = preset.lightDirectionY
        shadowLengthMultiplier = preset.shadowLengthMultiplier
        shadowOpacityMultiplier = preset.shadowOpacityMultiplier
        contactSoftness = preset.contactSoftness
        warmth = preset.warmth
        humidity = preset.humidity
        mistOpacity = preset.mistOpacity
        dustMoteOpacity = preset.dustMoteOpacity
        wildlifeDensity = preset.wildlifeDensity
        foregroundOcclusionBands = preset.foregroundOcclusionBands
    }

    public func lightProjection(from projection: GardenLightProjection) -> GardenLightProjection {
        projection.adjusted(
            additionalOffsetX: lightDirectionX,
            additionalOffsetY: lightDirectionY,
            lengthMultiplier: shadowLengthMultiplier,
            opacityMultiplier: shadowOpacityMultiplier,
            rimLightMultiplier: 0.84 + warmth * 0.34
        )
    }

    public func occlusionOpacity(for plant: Plant) -> Double {
        foregroundOcclusionBands
            .filter { $0.contains(plant.position) }
            .map { $0.opacity }
            .max()
            ?? 0
    }

    private static func preset(for key: String) -> GardenSceneVisualProfilePreset {
        if key.contains("rainforest")
            || key.contains("jungle") {
            return GardenSceneVisualProfilePreset(
                lightDirectionX: -0.04,
                lightDirectionY: 0.02,
                shadowLengthMultiplier: 0.92,
                shadowOpacityMultiplier: 0.68,
                contactSoftness: 0.88,
                warmth: 0.42,
                humidity: 0.96,
                mistOpacity: 0.20,
                dustMoteOpacity: 0.08,
                wildlifeDensity: 0.90,
                foregroundOcclusionBands: [
                    GardenSceneOcclusionBand(minX: 0.00, maxX: 1.00, minY: 0.84, maxY: 1.00, opacity: 0.20),
                    GardenSceneOcclusionBand(minX: 0.00, maxX: 0.18, minY: 0.00, maxY: 1.00, opacity: 0.10),
                    GardenSceneOcclusionBand(minX: 0.82, maxX: 1.00, minY: 0.00, maxY: 1.00, opacity: 0.10)
                ]
            )
        }

        if key.contains("moonlit") {
            return GardenSceneVisualProfilePreset(
                lightDirectionX: 0.02,
                lightDirectionY: 0.01,
                shadowLengthMultiplier: 1.18,
                shadowOpacityMultiplier: 0.56,
                contactSoftness: 0.82,
                warmth: 0.18,
                humidity: 0.62,
                mistOpacity: 0.18,
                dustMoteOpacity: 0.035,
                wildlifeDensity: 0.70,
                foregroundOcclusionBands: [
                    GardenSceneOcclusionBand(minX: 0.00, maxX: 0.26, minY: 0.87, maxY: 1.00, opacity: 0.18),
                    GardenSceneOcclusionBand(minX: 0.78, maxX: 1.00, minY: 0.84, maxY: 1.00, opacity: 0.14)
                ]
            )
        }

        if key.contains("water") || key.contains("coastal") {
            return GardenSceneVisualProfilePreset(
                lightDirectionX: -0.05,
                lightDirectionY: 0.02,
                shadowLengthMultiplier: 1.04,
                shadowOpacityMultiplier: 0.76,
                contactSoftness: 0.72,
                warmth: 0.52,
                humidity: 0.90,
                mistOpacity: 0.14,
                dustMoteOpacity: 0.025,
                wildlifeDensity: 0.58,
                foregroundOcclusionBands: [
                    GardenSceneOcclusionBand(minX: 0.00, maxX: 0.24, minY: 0.86, maxY: 1.00, opacity: 0.20),
                    GardenSceneOcclusionBand(minX: 0.66, maxX: 1.00, minY: 0.83, maxY: 1.00, opacity: 0.16)
                ]
            )
        }

        if key.contains("desertarium") {
            return GardenSceneVisualProfilePreset(
                lightDirectionX: -0.12,
                lightDirectionY: 0.04,
                shadowLengthMultiplier: 1.22,
                shadowOpacityMultiplier: 0.95,
                contactSoftness: 0.50,
                warmth: 0.88,
                humidity: 0.18,
                mistOpacity: 0.015,
                dustMoteOpacity: 0.11,
                wildlifeDensity: 0.20,
                foregroundOcclusionBands: [
                    GardenSceneOcclusionBand(minX: 0.04, maxX: 0.38, minY: 0.82, maxY: 1.00, opacity: 0.12),
                    GardenSceneOcclusionBand(minX: 0.70, maxX: 0.98, minY: 0.80, maxY: 1.00, opacity: 0.10)
                ]
            )
        }

        if key.contains("chinese-mountain")
            || key.contains("monk")
            || key.contains("mountain-monk") {
            return GardenSceneVisualProfilePreset(
                lightDirectionX: 0.03,
                lightDirectionY: 0.01,
                shadowLengthMultiplier: 1.12,
                shadowOpacityMultiplier: 0.66,
                contactSoftness: 0.84,
                warmth: 0.32,
                humidity: 0.74,
                mistOpacity: 0.20,
                dustMoteOpacity: 0.025,
                wildlifeDensity: 0.38,
                foregroundOcclusionBands: [
                    GardenSceneOcclusionBand(minX: 0.00, maxX: 0.30, minY: 0.76, maxY: 1.00, opacity: 0.16),
                    GardenSceneOcclusionBand(minX: 0.62, maxX: 1.00, minY: 0.76, maxY: 1.00, opacity: 0.14)
                ]
            )
        }

        if key.contains("swedish") || key.contains("patio") {
            return GardenSceneVisualProfilePreset(
                lightDirectionX: -0.04,
                lightDirectionY: 0.02,
                shadowLengthMultiplier: 0.96,
                shadowOpacityMultiplier: 0.76,
                contactSoftness: 0.70,
                warmth: 0.46,
                humidity: 0.48,
                mistOpacity: 0.035,
                dustMoteOpacity: 0.035,
                wildlifeDensity: 0.30,
                foregroundOcclusionBands: [
                    GardenSceneOcclusionBand(minX: 0.00, maxX: 0.24, minY: 0.78, maxY: 1.00, opacity: 0.12),
                    GardenSceneOcclusionBand(minX: 0.74, maxX: 1.00, minY: 0.74, maxY: 1.00, opacity: 0.12)
                ]
            )
        }

        if key.contains("brazilian-rooftop") || key.contains("brazilian") {
            return GardenSceneVisualProfilePreset(
                lightDirectionX: 0.08,
                lightDirectionY: 0.02,
                shadowLengthMultiplier: 0.98,
                shadowOpacityMultiplier: 0.84,
                contactSoftness: 0.68,
                warmth: 0.78,
                humidity: 0.76,
                mistOpacity: 0.070,
                dustMoteOpacity: 0.045,
                wildlifeDensity: 0.46,
                foregroundOcclusionBands: [
                    GardenSceneOcclusionBand(minX: 0.00, maxX: 0.22, minY: 0.80, maxY: 1.00, opacity: 0.14),
                    GardenSceneOcclusionBand(minX: 0.66, maxX: 1.00, minY: 0.76, maxY: 1.00, opacity: 0.12)
                ]
            )
        }

        if key.contains("egyptian") || key.contains("estate-garden") {
            return GardenSceneVisualProfilePreset(
                lightDirectionX: -0.10,
                lightDirectionY: 0.03,
                shadowLengthMultiplier: 1.16,
                shadowOpacityMultiplier: 0.90,
                contactSoftness: 0.58,
                warmth: 0.84,
                humidity: 0.42,
                mistOpacity: 0.030,
                dustMoteOpacity: 0.075,
                wildlifeDensity: 0.26,
                foregroundOcclusionBands: [
                    GardenSceneOcclusionBand(minX: 0.00, maxX: 0.24, minY: 0.78, maxY: 1.00, opacity: 0.12),
                    GardenSceneOcclusionBand(minX: 0.66, maxX: 1.00, minY: 0.72, maxY: 1.00, opacity: 0.14)
                ]
            )
        }

        if key.contains("texas") || key.contains("rustic-garden") {
            return GardenSceneVisualProfilePreset(
                lightDirectionX: -0.12,
                lightDirectionY: 0.04,
                shadowLengthMultiplier: 1.20,
                shadowOpacityMultiplier: 0.92,
                contactSoftness: 0.52,
                warmth: 0.80,
                humidity: 0.24,
                mistOpacity: 0.018,
                dustMoteOpacity: 0.105,
                wildlifeDensity: 0.28,
                foregroundOcclusionBands: [
                    GardenSceneOcclusionBand(minX: 0.00, maxX: 0.30, minY: 0.78, maxY: 1.00, opacity: 0.14),
                    GardenSceneOcclusionBand(minX: 0.58, maxX: 1.00, minY: 0.72, maxY: 1.00, opacity: 0.16)
                ]
            )
        }

        if key.contains("alien")
            || key.contains("ufo")
            || key.contains("exoplanet")
            || key.contains("martian") {
            return GardenSceneVisualProfilePreset(
                lightDirectionX: 0.03,
                lightDirectionY: 0.01,
                shadowLengthMultiplier: 0.92,
                shadowOpacityMultiplier: 0.74,
                contactSoftness: 0.82,
                warmth: 0.38,
                humidity: 0.62,
                mistOpacity: 0.075,
                dustMoteOpacity: 0.035,
                wildlifeDensity: 0.50,
                foregroundOcclusionBands: [
                    GardenSceneOcclusionBand(minX: 0.00, maxX: 0.22, minY: 0.82, maxY: 1.00, opacity: 0.12),
                    GardenSceneOcclusionBand(minX: 0.72, maxX: 1.00, minY: 0.80, maxY: 1.00, opacity: 0.12)
                ]
            )
        }

        if key.contains("rooftop") {
            return GardenSceneVisualProfilePreset(
                lightDirectionX: 0.08,
                lightDirectionY: 0.02,
                shadowLengthMultiplier: 0.98,
                shadowOpacityMultiplier: 0.88,
                contactSoftness: 0.64,
                warmth: 0.64,
                humidity: 0.42,
                mistOpacity: 0.045,
                dustMoteOpacity: 0.075,
                wildlifeDensity: 0.36,
                foregroundOcclusionBands: [
                    GardenSceneOcclusionBand(minX: 0.00, maxX: 0.20, minY: 0.86, maxY: 1.00, opacity: 0.16)
                ]
            )
        }

        if key.contains("gravel") || key.contains("courtyard") {
            return GardenSceneVisualProfilePreset(
                lightDirectionX: 0.12,
                lightDirectionY: 0.03,
                shadowLengthMultiplier: 1.12,
                shadowOpacityMultiplier: 0.86,
                contactSoftness: 0.58,
                warmth: 0.58,
                humidity: 0.38,
                mistOpacity: 0.035,
                dustMoteOpacity: 0.065,
                wildlifeDensity: 0.32,
                foregroundOcclusionBands: [
                    GardenSceneOcclusionBand(minX: 0.00, maxX: 1.00, minY: 0.90, maxY: 1.00, opacity: 0.10)
                ]
            )
        }

        if key.contains("apartment") || key.contains("studio") || key.contains("loft") {
            return GardenSceneVisualProfilePreset(
                lightDirectionX: -0.04,
                lightDirectionY: 0.02,
                shadowLengthMultiplier: 0.92,
                shadowOpacityMultiplier: 0.70,
                contactSoftness: 0.76,
                warmth: 0.72,
                humidity: 0.40,
                mistOpacity: 0.025,
                dustMoteOpacity: 0.045,
                wildlifeDensity: 0.18,
                foregroundOcclusionBands: [
                    GardenSceneOcclusionBand(minX: 0.00, maxX: 0.18, minY: 0.78, maxY: 1.00, opacity: 0.16),
                    GardenSceneOcclusionBand(minX: 0.74, maxX: 1.00, minY: 0.74, maxY: 1.00, opacity: 0.14)
                ]
            )
        }

        if key.contains("cottage") || key.contains("backyard") || key.contains("raised-bed") {
            return GardenSceneVisualProfilePreset(
                lightDirectionX: -0.04,
                lightDirectionY: 0.02,
                shadowLengthMultiplier: 1.02,
                shadowOpacityMultiplier: 0.82,
                contactSoftness: 0.64,
                warmth: 0.70,
                humidity: 0.48,
                mistOpacity: 0.035,
                dustMoteOpacity: 0.060,
                wildlifeDensity: 0.44,
                foregroundOcclusionBands: [
                    GardenSceneOcclusionBand(minX: 0.00, maxX: 0.32, minY: 0.76, maxY: 1.00, opacity: 0.18),
                    GardenSceneOcclusionBand(minX: 0.66, maxX: 1.00, minY: 0.74, maxY: 1.00, opacity: 0.16),
                    GardenSceneOcclusionBand(minX: 0.38, maxX: 0.66, minY: 0.72, maxY: 0.94, opacity: 0.10)
                ]
            )
        }

        return GardenSceneVisualProfilePreset(
            lightDirectionX: 0.06,
            lightDirectionY: 0.02,
            shadowLengthMultiplier: 1.04,
            shadowOpacityMultiplier: 0.80,
            contactSoftness: 0.68,
            warmth: 0.54,
            humidity: 0.66,
            mistOpacity: 0.10,
            dustMoteOpacity: 0.055,
            wildlifeDensity: 0.48,
            foregroundOcclusionBands: [
                GardenSceneOcclusionBand(minX: 0.00, maxX: 0.32, minY: 0.84, maxY: 1.00, opacity: 0.16),
                GardenSceneOcclusionBand(minX: 0.62, maxX: 1.00, minY: 0.83, maxY: 1.00, opacity: 0.14)
            ]
        )
    }
}

public struct GardenSceneOcclusionBand: Equatable, Sendable {
    public let minX: Double
    public let maxX: Double
    public let minY: Double
    public let maxY: Double
    public let opacity: Double

    public init(minX: Double, maxX: Double, minY: Double, maxY: Double, opacity: Double) {
        self.minX = min(max(0, minX), 1)
        self.maxX = min(max(0, maxX), 1)
        self.minY = min(max(0, minY), 1)
        self.maxY = min(max(0, maxY), 1)
        self.opacity = min(max(0, opacity), 1)
    }

    public func contains(_ point: GardenPoint) -> Bool {
        point.x >= minX
            && point.x <= maxX
            && point.y >= minY
            && point.y <= maxY
    }
}

private struct GardenSceneVisualProfilePreset {
    let lightDirectionX: Double
    let lightDirectionY: Double
    let shadowLengthMultiplier: Double
    let shadowOpacityMultiplier: Double
    let contactSoftness: Double
    let warmth: Double
    let humidity: Double
    let mistOpacity: Double
    let dustMoteOpacity: Double
    let wildlifeDensity: Double
    let foregroundOcclusionBands: [GardenSceneOcclusionBand]
}
