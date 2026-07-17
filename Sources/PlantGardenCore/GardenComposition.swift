import Foundation

public enum GardenComposition {
    public static let currentVersion = 6

    private struct Slot {
        let point: GardenPoint
        let scale: Double
    }

    public struct ArrangementStrategy: Equatable, Sendable {
        public let title: String
        public let summary: String
    }

    public static func arrangedPlants(
        _ plants: [Plant],
        screenCount: Int,
        sceneKey: String? = nil
    ) -> [Plant] {
        let safeScreenCount = max(1, screenCount)
        var counters: [String: Int] = [:]

        return plants.enumerated().map { index, plant in
            let screenIndex = index % safeScreenCount
            let key = "\(screenIndex)-\(plant.species.kind.rawValue)"
            let ordinal = counters[key, default: 0]
            counters[key] = ordinal + 1

            var arrangedPlant = plant
            arrangedPlant.screenIndex = screenIndex
            arrangedPlant.position = position(
                for: plant.species,
                ordinal: ordinal,
                screenIndex: screenIndex,
                sceneKey: sceneKey
            )
            arrangedPlant.scale = scale(for: plant.species, ordinal: ordinal, sceneKey: sceneKey)
            return arrangedPlant
        }
    }

    public static func nextPosition(
        for species: PlantSpecies,
        existingPlants: [Plant],
        screenIndex: Int,
        sceneKey: String? = nil
    ) -> GardenPoint {
        let ordinal = existingPlants.filter {
            $0.screenIndex == screenIndex && $0.species.kind == species.kind
        }.count
        return position(for: species, ordinal: ordinal, screenIndex: screenIndex, sceneKey: sceneKey)
    }

    public static func resolvedPlantingPosition(
        for species: PlantSpecies,
        preferredPosition: GardenPoint,
        existingPlants: [Plant],
        screenIndex: Int
    ) -> GardenPoint {
        let preferredPosition = naturalized(preferredPosition)
        let plantsOnScreen = existingPlants.filter { $0.screenIndex == screenIndex }
        let minimumSpacing = plantingSpacing(for: species)

        guard !isCrowded(preferredPosition, by: plantsOnScreen, minimumSpacing: minimumSpacing) else {
            return candidateOffsets(for: species).lazy
                .map { offset in
                    naturalized(
                        GardenPoint(
                            x: preferredPosition.x + offset.x,
                            y: preferredPosition.y + offset.y
                        )
                    )
                }
                .filter { !isCrowded($0, by: plantsOnScreen, minimumSpacing: minimumSpacing) }
                .min { distance($0, preferredPosition) < distance($1, preferredPosition) }
                ?? leastCrowdedPosition(near: preferredPosition, existingPlants: plantsOnScreen, species: species)
        }

        return preferredPosition
    }

    public static func reachablePlantingPosition(_ point: GardenPoint) -> GardenPoint {
        naturalized(point)
    }

    public static func position(
        for species: PlantSpecies,
        ordinal: Int,
        screenIndex: Int
    ) -> GardenPoint {
        position(for: species, ordinal: ordinal, screenIndex: screenIndex, sceneKey: nil)
    }

    public static func position(
        for species: PlantSpecies,
        ordinal: Int,
        screenIndex: Int,
        sceneKey: String?
    ) -> GardenPoint {
        slot(for: species, ordinal: ordinal, screenIndex: screenIndex, sceneKey: sceneKey).point
    }

    public static func scale(for species: PlantSpecies, ordinal: Int) -> Double {
        scale(for: species, ordinal: ordinal, sceneKey: nil)
    }

    public static func scale(for species: PlantSpecies, ordinal: Int, sceneKey: String?) -> Double {
        slot(for: species, ordinal: ordinal, screenIndex: 0, sceneKey: sceneKey).scale
    }

    public static func arrangementStrategy(sceneKey: String?) -> ArrangementStrategy {
        let key = sceneKey?.lowercased() ?? ""
        if key.contains("rainforest") || key.contains("jungle") {
            return ArrangementStrategy(
                title: "Layered rainforest",
                summary: "Large foliage fills the edges, floor cover spreads across the foreground, and vines stack into a dense desktop jungle."
            )
        }
        if key.contains("chinese-mountain") || key.contains("monk") || key.contains("mountain-monk") {
            return ArrangementStrategy(
                title: "Mountain courtyard",
                summary: "Plants settle into quiet stone vessels and edge beds, leaving the raked center open."
            )
        }
        if key.contains("swedish") || key.contains("patio") {
            return ArrangementStrategy(
                title: "Patio planters",
                summary: "Containers and raised boxes fill from the deck edges inward while the patio stays breathable."
            )
        }
        if key.contains("brazilian-rooftop") || key.contains("brazilian") {
            return ArrangementStrategy(
                title: "Rooftop terrace planters",
                summary: "Warm-weather plants gather in terrace troughs and pots while the tile court stays open."
            )
        }
        if key.contains("egyptian") || key.contains("estate-garden") {
            return ArrangementStrategy(
                title: "Estate pool beds",
                summary: "Plantings follow the pool and geometric beds, keeping the limestone courtyard readable."
            )
        }
        if key.contains("texas") || key.contains("rustic-garden") {
            return ArrangementStrategy(
                title: "Rustic homestead rows",
                summary: "Dry-climate plants settle into troughs and raised beds with wide gravel paths between them."
            )
        }
        if key.contains("water") || key.contains("pond") || key.contains("pavilion") {
            return ArrangementStrategy(
                title: "Waterline planting",
                summary: "Moisture-loving plants collect near the lower waterline while trees and foliage frame the sides."
            )
        }
        if key.contains("cottage") || key.contains("backyard") || key.contains("raised-bed") {
            return ArrangementStrategy(
                title: "Raised-bed rows",
                summary: "Edibles, herbs, flowers, and groundcover settle into bed-like rows with trees held to the back corners."
            )
        }
        if key.contains("desert") || key.contains("desertarium") || key.contains("arid") || key.contains("dry") {
            return ArrangementStrategy(
                title: "Desert clusters",
                summary: "Dry-climate plants stay sparse, low, and stone-garden friendly so the scene keeps its open air."
            )
        }
        if key.contains("apartment") || key.contains("studio") || key.contains("living-room") || key.contains("loft") {
            return ArrangementStrategy(
                title: "Container shelf",
                summary: "Indoor plants gather into compact container groups instead of filling the whole room."
            )
        }
        if key.contains("rooftop") || key.contains("roof") || key.contains("seed-house") {
            return ArrangementStrategy(
                title: "Rooftop benches",
                summary: "Sun-loving containers line up like bench trays, with taller plants set back from the front edge."
            )
        }
        if key.contains("moonlit") || key.contains("night") || key.contains("misty") {
            return ArrangementStrategy(
                title: "Moonlit understory",
                summary: "Shade and humid plants gather in softer lower clusters, leaving room for night atmosphere."
            )
        }
        return ArrangementStrategy(
            title: "Layered conservatory",
            summary: "Trees sit back, foliage frames the sides, and flowers plus groundcover fill the foreground."
        )
    }

    private static func slot(
        for species: PlantSpecies,
        ordinal: Int,
        screenIndex: Int,
        sceneKey: String?
    ) -> Slot {
        let slots = slots(for: species.kind, sceneKey: sceneKey)
        let baseSlot = slots[ordinal % slots.count]
        let cycle = ordinal / slots.count
        let wave = deterministicWave(ordinal: ordinal, screenIndex: screenIndex)
        let drift = Double(cycle) * 0.025
        let sidePush = wave * 0.018

        return Slot(
            point: GardenPoint(
                x: baseSlot.point.x + sidePush + drift,
                y: baseSlot.point.y + abs(wave) * 0.018 + Double(cycle) * 0.012
            ).clamped,
            scale: max(0.62, min(1.56, baseSlot.scale + wave * 0.045))
        )
    }

    private static func slots(for kind: PlantKind, sceneKey: String?) -> [Slot] {
        let key = sceneKey?.lowercased() ?? ""
        if key.contains("rainforest") || key.contains("jungle") {
            return rainforestSlots(for: kind)
        }
        if key.contains("chinese-mountain") || key.contains("monk") || key.contains("mountain-monk") {
            return moonlitSlots(for: kind)
        }
        if key.contains("swedish") || key.contains("patio") {
            return raisedBedSlots(for: kind)
        }
        if key.contains("brazilian-rooftop") || key.contains("brazilian") {
            return rooftopBenchSlots(for: kind)
        }
        if key.contains("egyptian") || key.contains("estate-garden") {
            return waterlineSlots(for: kind)
        }
        if key.contains("texas") || key.contains("rustic-garden") {
            return desertSlots(for: kind)
        }
        if key.contains("water") || key.contains("pond") || key.contains("pavilion") {
            return waterlineSlots(for: kind)
        }
        if key.contains("cottage") || key.contains("backyard") || key.contains("raised-bed") {
            return raisedBedSlots(for: kind)
        }
        if key.contains("desert") || key.contains("desertarium") || key.contains("arid") || key.contains("dry") {
            return desertSlots(for: kind)
        }
        if key.contains("apartment") || key.contains("studio") || key.contains("living-room") || key.contains("loft") {
            return containerShelfSlots(for: kind)
        }
        if key.contains("rooftop") || key.contains("roof") || key.contains("seed-house") {
            return rooftopBenchSlots(for: kind)
        }
        if key.contains("moonlit") || key.contains("night") || key.contains("misty") {
            return moonlitSlots(for: kind)
        }
        return defaultSlots(for: kind)
    }

    private static func defaultSlots(for kind: PlantKind) -> [Slot] {
        switch kind {
        case .tree:
            [
                Slot(point: GardenPoint(x: 0.22, y: 0.62), scale: 1.10),
                Slot(point: GardenPoint(x: 0.74, y: 0.62), scale: 1.02),
                Slot(point: GardenPoint(x: 0.84, y: 0.70), scale: 0.82),
                Slot(point: GardenPoint(x: 0.34, y: 0.70), scale: 0.94)
            ]
        case .foliage:
            [
                Slot(point: GardenPoint(x: 0.13, y: 0.76), scale: 1.00),
                Slot(point: GardenPoint(x: 0.31, y: 0.78), scale: 0.88),
                Slot(point: GardenPoint(x: 0.67, y: 0.75), scale: 0.96),
                Slot(point: GardenPoint(x: 0.78, y: 0.75), scale: 0.82),
                Slot(point: GardenPoint(x: 0.45, y: 0.77), scale: 0.78)
            ]
        case .flower:
            [
                Slot(point: GardenPoint(x: 0.40, y: 0.76), scale: 0.90),
                Slot(point: GardenPoint(x: 0.52, y: 0.73), scale: 1.04),
                Slot(point: GardenPoint(x: 0.60, y: 0.76), scale: 0.86),
                Slot(point: GardenPoint(x: 0.66, y: 0.72), scale: 0.96),
                Slot(point: GardenPoint(x: 0.25, y: 0.76), scale: 0.80),
                Slot(point: GardenPoint(x: 0.77, y: 0.76), scale: 0.78)
            ]
        case .meadow:
            [
                Slot(point: GardenPoint(x: 0.50, y: 0.78), scale: 1.14),
                Slot(point: GardenPoint(x: 0.20, y: 0.78), scale: 0.94),
                Slot(point: GardenPoint(x: 0.76, y: 0.78), scale: 0.90)
            ]
        case .edible:
            [
                Slot(point: GardenPoint(x: 0.28, y: 0.73), scale: 0.90),
                Slot(point: GardenPoint(x: 0.44, y: 0.75), scale: 0.84),
                Slot(point: GardenPoint(x: 0.60, y: 0.74), scale: 0.88),
                Slot(point: GardenPoint(x: 0.74, y: 0.73), scale: 0.82),
                Slot(point: GardenPoint(x: 0.18, y: 0.79), scale: 0.78)
            ]
        }
    }

    private static func rainforestSlots(for kind: PlantKind) -> [Slot] {
        switch kind {
        case .tree:
            [
                Slot(point: GardenPoint(x: 0.08, y: 0.68), scale: 1.38),
                Slot(point: GardenPoint(x: 0.92, y: 0.68), scale: 1.34),
                Slot(point: GardenPoint(x: 0.18, y: 0.56), scale: 1.20),
                Slot(point: GardenPoint(x: 0.82, y: 0.56), scale: 1.18)
            ]
        case .foliage:
            [
                Slot(point: GardenPoint(x: 0.12, y: 0.70), scale: 1.32),
                Slot(point: GardenPoint(x: 0.88, y: 0.70), scale: 1.30),
                Slot(point: GardenPoint(x: 0.30, y: 0.82), scale: 1.16),
                Slot(point: GardenPoint(x: 0.68, y: 0.82), scale: 1.18),
                Slot(point: GardenPoint(x: 0.50, y: 0.76), scale: 1.08)
            ]
        case .flower:
            [
                Slot(point: GardenPoint(x: 0.30, y: 0.78), scale: 1.02),
                Slot(point: GardenPoint(x: 0.70, y: 0.78), scale: 1.00),
                Slot(point: GardenPoint(x: 0.44, y: 0.86), scale: 0.92),
                Slot(point: GardenPoint(x: 0.58, y: 0.86), scale: 0.94)
            ]
        case .meadow:
            [
                Slot(point: GardenPoint(x: 0.18, y: 0.91), scale: 1.40),
                Slot(point: GardenPoint(x: 0.50, y: 0.92), scale: 1.52),
                Slot(point: GardenPoint(x: 0.82, y: 0.91), scale: 1.38),
                Slot(point: GardenPoint(x: 0.36, y: 0.86), scale: 1.18),
                Slot(point: GardenPoint(x: 0.66, y: 0.86), scale: 1.16)
            ]
        case .edible:
            [
                Slot(point: GardenPoint(x: 0.26, y: 0.78), scale: 1.02),
                Slot(point: GardenPoint(x: 0.74, y: 0.78), scale: 1.02),
                Slot(point: GardenPoint(x: 0.50, y: 0.84), scale: 0.94)
            ]
        }
    }

    private static func raisedBedSlots(for kind: PlantKind) -> [Slot] {
        switch kind {
        case .tree:
            [
                Slot(point: GardenPoint(x: 0.18, y: 0.61), scale: 1.00),
                Slot(point: GardenPoint(x: 0.84, y: 0.62), scale: 0.96),
                Slot(point: GardenPoint(x: 0.32, y: 0.66), scale: 0.84)
            ]
        case .foliage:
            [
                Slot(point: GardenPoint(x: 0.13, y: 0.76), scale: 0.86),
                Slot(point: GardenPoint(x: 0.86, y: 0.76), scale: 0.84),
                Slot(point: GardenPoint(x: 0.23, y: 0.80), scale: 0.74),
                Slot(point: GardenPoint(x: 0.75, y: 0.80), scale: 0.74)
            ]
        case .flower:
            [
                Slot(point: GardenPoint(x: 0.26, y: 0.78), scale: 0.82),
                Slot(point: GardenPoint(x: 0.39, y: 0.77), scale: 0.88),
                Slot(point: GardenPoint(x: 0.52, y: 0.78), scale: 0.86),
                Slot(point: GardenPoint(x: 0.65, y: 0.77), scale: 0.84),
                Slot(point: GardenPoint(x: 0.78, y: 0.79), scale: 0.76)
            ]
        case .meadow:
            [
                Slot(point: GardenPoint(x: 0.28, y: 0.83), scale: 0.86),
                Slot(point: GardenPoint(x: 0.50, y: 0.84), scale: 0.94),
                Slot(point: GardenPoint(x: 0.72, y: 0.83), scale: 0.84)
            ]
        case .edible:
            [
                Slot(point: GardenPoint(x: 0.23, y: 0.72), scale: 0.82),
                Slot(point: GardenPoint(x: 0.37, y: 0.73), scale: 0.82),
                Slot(point: GardenPoint(x: 0.51, y: 0.72), scale: 0.84),
                Slot(point: GardenPoint(x: 0.65, y: 0.73), scale: 0.82),
                Slot(point: GardenPoint(x: 0.79, y: 0.72), scale: 0.80)
            ]
        }
    }

    private static func waterlineSlots(for kind: PlantKind) -> [Slot] {
        switch kind {
        case .tree:
            [
                Slot(point: GardenPoint(x: 0.18, y: 0.60), scale: 0.98),
                Slot(point: GardenPoint(x: 0.82, y: 0.62), scale: 0.92)
            ]
        case .foliage:
            [
                Slot(point: GardenPoint(x: 0.16, y: 0.75), scale: 0.96),
                Slot(point: GardenPoint(x: 0.30, y: 0.80), scale: 0.88),
                Slot(point: GardenPoint(x: 0.72, y: 0.78), scale: 0.90),
                Slot(point: GardenPoint(x: 0.84, y: 0.75), scale: 0.82)
            ]
        case .flower:
            [
                Slot(point: GardenPoint(x: 0.38, y: 0.78), scale: 0.84),
                Slot(point: GardenPoint(x: 0.55, y: 0.79), scale: 0.86),
                Slot(point: GardenPoint(x: 0.68, y: 0.80), scale: 0.76)
            ]
        case .meadow:
            [
                Slot(point: GardenPoint(x: 0.31, y: 0.84), scale: 0.96),
                Slot(point: GardenPoint(x: 0.50, y: 0.86), scale: 1.08),
                Slot(point: GardenPoint(x: 0.69, y: 0.84), scale: 0.94)
            ]
        case .edible:
            [
                Slot(point: GardenPoint(x: 0.40, y: 0.76), scale: 0.78),
                Slot(point: GardenPoint(x: 0.58, y: 0.76), scale: 0.78)
            ]
        }
    }

    private static func desertSlots(for kind: PlantKind) -> [Slot] {
        switch kind {
        case .tree:
            [
                Slot(point: GardenPoint(x: 0.21, y: 0.65), scale: 0.90),
                Slot(point: GardenPoint(x: 0.78, y: 0.66), scale: 0.86)
            ]
        case .foliage:
            [
                Slot(point: GardenPoint(x: 0.30, y: 0.78), scale: 0.82),
                Slot(point: GardenPoint(x: 0.55, y: 0.80), scale: 0.74),
                Slot(point: GardenPoint(x: 0.74, y: 0.78), scale: 0.78)
            ]
        case .flower:
            [
                Slot(point: GardenPoint(x: 0.38, y: 0.79), scale: 0.76),
                Slot(point: GardenPoint(x: 0.64, y: 0.79), scale: 0.72)
            ]
        case .meadow:
            [
                Slot(point: GardenPoint(x: 0.34, y: 0.85), scale: 0.78),
                Slot(point: GardenPoint(x: 0.68, y: 0.84), scale: 0.76)
            ]
        case .edible:
            [
                Slot(point: GardenPoint(x: 0.42, y: 0.77), scale: 0.76),
                Slot(point: GardenPoint(x: 0.60, y: 0.78), scale: 0.74)
            ]
        }
    }

    private static func containerShelfSlots(for kind: PlantKind) -> [Slot] {
        switch kind {
        case .tree:
            [
                Slot(point: GardenPoint(x: 0.31, y: 0.70), scale: 0.78),
                Slot(point: GardenPoint(x: 0.69, y: 0.70), scale: 0.76)
            ]
        case .foliage:
            [
                Slot(point: GardenPoint(x: 0.24, y: 0.79), scale: 0.76),
                Slot(point: GardenPoint(x: 0.40, y: 0.80), scale: 0.72),
                Slot(point: GardenPoint(x: 0.58, y: 0.80), scale: 0.72),
                Slot(point: GardenPoint(x: 0.75, y: 0.79), scale: 0.74)
            ]
        case .flower:
            [
                Slot(point: GardenPoint(x: 0.33, y: 0.82), scale: 0.70),
                Slot(point: GardenPoint(x: 0.49, y: 0.82), scale: 0.72),
                Slot(point: GardenPoint(x: 0.65, y: 0.82), scale: 0.70)
            ]
        case .meadow:
            [
                Slot(point: GardenPoint(x: 0.39, y: 0.86), scale: 0.72),
                Slot(point: GardenPoint(x: 0.61, y: 0.86), scale: 0.70)
            ]
        case .edible:
            [
                Slot(point: GardenPoint(x: 0.36, y: 0.81), scale: 0.70),
                Slot(point: GardenPoint(x: 0.54, y: 0.81), scale: 0.70),
                Slot(point: GardenPoint(x: 0.70, y: 0.81), scale: 0.68)
            ]
        }
    }

    private static func rooftopBenchSlots(for kind: PlantKind) -> [Slot] {
        switch kind {
        case .tree:
            [
                Slot(point: GardenPoint(x: 0.22, y: 0.64), scale: 0.88),
                Slot(point: GardenPoint(x: 0.78, y: 0.64), scale: 0.84)
            ]
        case .foliage:
            [
                Slot(point: GardenPoint(x: 0.20, y: 0.76), scale: 0.78),
                Slot(point: GardenPoint(x: 0.38, y: 0.77), scale: 0.76),
                Slot(point: GardenPoint(x: 0.62, y: 0.77), scale: 0.76),
                Slot(point: GardenPoint(x: 0.80, y: 0.76), scale: 0.76)
            ]
        case .flower:
            [
                Slot(point: GardenPoint(x: 0.28, y: 0.80), scale: 0.76),
                Slot(point: GardenPoint(x: 0.44, y: 0.80), scale: 0.80),
                Slot(point: GardenPoint(x: 0.60, y: 0.80), scale: 0.78),
                Slot(point: GardenPoint(x: 0.76, y: 0.80), scale: 0.72)
            ]
        case .meadow:
            [
                Slot(point: GardenPoint(x: 0.34, y: 0.84), scale: 0.84),
                Slot(point: GardenPoint(x: 0.66, y: 0.84), scale: 0.82)
            ]
        case .edible:
            [
                Slot(point: GardenPoint(x: 0.24, y: 0.76), scale: 0.76),
                Slot(point: GardenPoint(x: 0.40, y: 0.76), scale: 0.76),
                Slot(point: GardenPoint(x: 0.56, y: 0.76), scale: 0.76),
                Slot(point: GardenPoint(x: 0.72, y: 0.76), scale: 0.74)
            ]
        }
    }

    private static func moonlitSlots(for kind: PlantKind) -> [Slot] {
        switch kind {
        case .tree:
            [
                Slot(point: GardenPoint(x: 0.24, y: 0.64), scale: 0.94),
                Slot(point: GardenPoint(x: 0.76, y: 0.65), scale: 0.90)
            ]
        case .foliage:
            [
                Slot(point: GardenPoint(x: 0.18, y: 0.78), scale: 0.92),
                Slot(point: GardenPoint(x: 0.34, y: 0.82), scale: 0.84),
                Slot(point: GardenPoint(x: 0.66, y: 0.82), scale: 0.84),
                Slot(point: GardenPoint(x: 0.82, y: 0.78), scale: 0.88)
            ]
        case .flower:
            [
                Slot(point: GardenPoint(x: 0.42, y: 0.82), scale: 0.76),
                Slot(point: GardenPoint(x: 0.58, y: 0.82), scale: 0.76)
            ]
        case .meadow:
            [
                Slot(point: GardenPoint(x: 0.30, y: 0.86), scale: 0.86),
                Slot(point: GardenPoint(x: 0.50, y: 0.87), scale: 0.94),
                Slot(point: GardenPoint(x: 0.70, y: 0.86), scale: 0.86)
            ]
        case .edible:
            [
                Slot(point: GardenPoint(x: 0.46, y: 0.80), scale: 0.70),
                Slot(point: GardenPoint(x: 0.62, y: 0.80), scale: 0.68)
            ]
        }
    }

    private static func deterministicWave(ordinal: Int, screenIndex: Int) -> Double {
        sin(Double(ordinal + 1) * 1.618 + Double(screenIndex) * 0.733)
    }

    private static func naturalized(_ point: GardenPoint) -> GardenPoint {
        GardenPoint(
            x: min(0.92, max(0.08, point.x)),
            y: min(0.92, max(0.56, point.y))
        )
    }

    private static func plantingSpacing(for species: PlantSpecies) -> Double {
        switch species.kind {
        case .tree:
            return 0.14
        case .meadow:
            return 0.11
        case .foliage:
            return 0.09
        case .flower:
            return 0.075
        case .edible:
            return 0.085
        }
    }

    private static func isCrowded(
        _ point: GardenPoint,
        by plants: [Plant],
        minimumSpacing: Double
    ) -> Bool {
        plants.contains { plant in
            distance(point, plant.position) < max(minimumSpacing, plantingSpacing(for: plant.species) * 0.78)
        }
    }

    private static func leastCrowdedPosition(
        near preferredPosition: GardenPoint,
        existingPlants: [Plant],
        species: PlantSpecies
    ) -> GardenPoint {
        let candidates = candidateOffsets(for: species).map { offset in
            naturalized(
                GardenPoint(
                    x: preferredPosition.x + offset.x,
                    y: preferredPosition.y + offset.y
                )
            )
        }

        return candidates.max { lhs, rhs in
            nearestDistance(from: lhs, to: existingPlants) < nearestDistance(from: rhs, to: existingPlants)
        } ?? preferredPosition
    }

    private static func nearestDistance(from point: GardenPoint, to plants: [Plant]) -> Double {
        plants.map { distance(point, $0.position) }.min() ?? 1
    }

    private static func distance(_ lhs: GardenPoint, _ rhs: GardenPoint) -> Double {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private static func candidateOffsets(for species: PlantSpecies) -> [GardenPoint] {
        let baseRadius = plantingSpacing(for: species) * 1.08
        let radii = [baseRadius, baseRadius * 1.45, baseRadius * 1.92]
        let angles = [-25.0, 28.0, -62.0, 64.0, 0.0, 92.0, -104.0, 142.0, -150.0]

        return radii.flatMap { radius in
            angles.map { degrees in
                let radians = degrees * .pi / 180
                return GardenPoint(
                    x: cos(radians) * radius,
                    y: sin(radians) * radius * 0.72
                )
            }
        }
    }
}
