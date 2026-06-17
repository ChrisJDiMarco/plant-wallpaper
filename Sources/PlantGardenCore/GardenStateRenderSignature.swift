import Foundation

/// Captures everything about a garden state that observers can see - on the
/// canvas, in the menu, or via notifications - at viewer-visible precision.
///
/// The simulation advances every second and always mutates timestamps plus
/// sub-pixel growth increments, so raw state equality reports a change on
/// every tick. Comparing render signatures instead lets the store skip
/// observer notifications (and the full-screen repaints they trigger) for
/// ticks nothing perceptible changed in. Ambient animation is unaffected:
/// the display-cadence timer repaints from live state independently.
public struct GardenStateRenderSignature: Equatable, Sendable {
    private struct PlantRenderSignature: Equatable, Sendable {
        let id: UUID
        let species: PlantSpecies
        let screenIndex: Int
        let position: GardenPoint
        let scale: Double
        let isDead: Bool
        let assetStageIndex: Int
        let needsAttention: Bool
        let growthStep: Int
        let hydrationStep: Int
        let healthStep: Int
        let bloomProgressStep: Int

        init(_ plant: Plant) {
            id = plant.id
            species = plant.species
            screenIndex = plant.screenIndex
            position = plant.position
            scale = plant.scale
            isDead = plant.isDead
            assetStageIndex = PlantAssetStage(growth: plant.growth).index
            needsAttention = plant.careNeed.needsAttention
            growthStep = GardenStateRenderSignature.step(plant.growth)
            hydrationStep = GardenStateRenderSignature.step(plant.hydration)
            healthStep = GardenStateRenderSignature.step(plant.health)
            bloomProgressStep = GardenStateRenderSignature.step(plant.bloomProgress)
        }
    }

    /// Plant unit values are compared in steps of 0.01 - the granularity of
    /// the whole-percent readouts in the inspector and settings window.
    private static let unitValueStep = 0.01

    /// Wind and moisture drift continuously along wall-clock waves and only
    /// modulate ambient sway, which the display-cadence timer animates
    /// regardless - so they get a much coarser step.
    private static let environmentValueStep = 0.05

    private let plants: [PlantRenderSignature]
    private let isPaused: Bool
    private let isAmbientWildlifeEnabled: Bool
    private let musicButtons: [GardenMusicButton]
    private let gnomeTribeZones: [GnomeTribeZone]
    private let gnomeSettlementPlan: GnomeTribeSettlementPlan
    private let areGnomeTribesHidden: Bool
    private let gnomeTribePerspective: GnomeTribePerspective
    private let birdSkyZones: [BirdSkyZone]
    private let areBirdFlocksHidden: Bool
    private let soilPatches: [SoilPatch]
    private let settings: GardenSettings
    private let weather: GardenWeatherCondition?
    private let focusSession: GardenFocusSession?
    private let focusStats: GardenFocusStats?
    private let seedInventory: [String: Int]
    private let harvestTally: [String: Int]
    private let ambientMoistureStep: Int
    private let windStrengthStep: Int
    private let manualPlantDarkeningStep: Int

    public init(of state: GardenState) {
        plants = state.plants.map(PlantRenderSignature.init)
        isPaused = state.isPaused
        isAmbientWildlifeEnabled = state.isAmbientWildlifeEnabled
        musicButtons = state.musicButtons
        gnomeTribeZones = state.gnomeTribeZones
        gnomeSettlementPlan = state.gnomeSettlementPlan
        areGnomeTribesHidden = state.areGnomeTribesHidden
        gnomeTribePerspective = state.gnomeTribePerspective
        birdSkyZones = state.birdSkyZones
        areBirdFlocksHidden = state.areBirdFlocksHidden
        soilPatches = state.soilPatches
        settings = state.settings
        weather = state.weather
        focusSession = state.focusSession
        focusStats = state.focusStats
        seedInventory = state.seedInventory
        harvestTally = state.harvestTally
        ambientMoistureStep = Self.environmentStep(state.ambientMoisture)
        windStrengthStep = Self.environmentStep(state.windStrength)
        manualPlantDarkeningStep = Self.step(state.manualPlantDarkening)
    }

    private static func step(_ unitValue: Double) -> Int {
        Int((unitValue / unitValueStep).rounded())
    }

    private static func environmentStep(_ unitValue: Double) -> Int {
        Int((unitValue / environmentValueStep).rounded())
    }
}
