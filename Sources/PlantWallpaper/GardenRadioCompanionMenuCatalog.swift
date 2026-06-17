import PlantGardenCore

struct GardenRadioCompanionMenuEntry: Equatable {
    let companion: GardenRadioCompanion
    let title: String
    let toolTip: String
}

enum GardenRadioCompanionMenuCatalog {
    static var entries: [GardenRadioCompanionMenuEntry] {
        GardenRadioCompanion.allCases.map { companion in
            GardenRadioCompanionMenuEntry(
                companion: companion,
                title: companion.menuTitle,
                toolTip: companion.placementSummary
            )
        }
    }
}
