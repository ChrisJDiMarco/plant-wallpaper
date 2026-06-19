import AppKit
import PlantGardenCore
import UniformTypeIdentifiers

extension Notification.Name {
    static let gardenStatusMenuWillOpen = Notification.Name("gardenStatusMenuWillOpen")
    static let gardenStatusMenuDidClose = Notification.Name("gardenStatusMenuDidClose")
}

enum GardenStatusHeaderVisibility {
    static func hidesLiveCareHeader(isPaused: Bool, experienceMode: GardenExperienceMode = .garden) -> Bool {
        isPaused || experienceMode != .garden
    }
}

struct CustomPlantAssetPromptFragment: Equatable {
    var title: String
    var insertion: String
    var tooltip: String
}

enum CustomPlantAssetPromptStudio {
    static let primaryButtonTooltip = "Generate an OpenAI PNG asset and plant it at the current cursor location."
    static let cancelButtonTooltip = "Close this creator without generating a plant."
    static let useExampleTooltip = "Fill the description with a polished starter prompt you can edit."
    static let nameTooltip = "Optional. This becomes the plant name in menus, inspector, and saved garden data."
    static let descriptionTooltip = "Describe the exact plant cutout you want. Mention color, silhouette, texture, and maturity."

    static let assetRules = [
        "PNG",
        "No pot",
        "No scene",
        "Centered"
    ]

    static func starterDescription(for kind: PlantKind) -> String {
        switch kind {
        case .flower:
            "A luminous moon-white tulip with glassy petals, elegant curved stem, crisp botanical silhouette, mature bloom"
        case .foliage:
            "A compact variegated fern with pale mint leaf tips, layered fronds, lush texture, clean natural base"
        case .tree:
            "A miniature wind-shaped cedar tree with exposed roots, sculptural trunk, dense detailed canopy, mature bonsai scale"
        case .meadow:
            "A low cushion of tiny white star flowers and moss, soft organic edge, dense groundcover texture, garden-ready base"
        case .edible:
            "A compact golden tomato plant with ripe fruit, strong leafy stems, productive mature shape, clean soil-level base"
        }
    }

    static func fragments(for kind: PlantKind) -> [CustomPlantAssetPromptFragment] {
        [
            CustomPlantAssetPromptFragment(
                title: "Color",
                insertion: colorFragment(for: kind),
                tooltip: "Add a vivid but believable color direction."
            ),
            CustomPlantAssetPromptFragment(
                title: "Silhouette",
                insertion: silhouetteFragment(for: kind),
                tooltip: "Shape the outline so the asset reads clearly on the desktop."
            ),
            CustomPlantAssetPromptFragment(
                title: "Texture",
                insertion: "fine natural texture, crisp edge detail, soft internal shadows",
                tooltip: "Ask for detail that makes the PNG feel high fidelity."
            ),
            CustomPlantAssetPromptFragment(
                title: "Maturity",
                insertion: maturityFragment(for: kind),
                tooltip: "Choose a plant life stage that looks satisfying immediately."
            ),
            CustomPlantAssetPromptFragment(
                title: "Base",
                insertion: "clean natural base contact, no pot, no planter, no props",
                tooltip: "Keep the bottom edge easy to place into any scene."
            )
        ]
    }

    private static func colorFragment(for kind: PlantKind) -> String {
        switch kind {
        case .flower:
            "luminous petals with subtle color variation"
        case .foliage:
            "variegated green leaves with pale highlights"
        case .tree:
            "rich bark tones with layered green canopy color"
        case .meadow:
            "fresh moss greens with tiny white bloom accents"
        case .edible:
            "ripe fruit color against healthy green leaves"
        }
    }

    private static func silhouetteFragment(for kind: PlantKind) -> String {
        switch kind {
        case .flower:
            "single elegant bloom silhouette with visible stem"
        case .foliage:
            "layered fan-shaped foliage silhouette"
        case .tree:
            "complete trunk and canopy silhouette"
        case .meadow:
            "low spreading organic patch silhouette"
        case .edible:
            "compact productive garden plant silhouette"
        }
    }

    private static func maturityFragment(for kind: PlantKind) -> String {
        switch kind {
        case .flower:
            "mature open bloom, not a seedling"
        case .foliage:
            "full healthy foliage, dense but not oversized"
        case .tree:
            "mature miniature ornamental tree"
        case .meadow:
            "established dense groundcover patch"
        case .edible:
            "mature edible plant with visible harvest detail"
        }
    }
}

private final class CustomPlantAssetPlaceholderTextView: NSTextView {
    var placeholderString: String = "" {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !placeholderString.isEmpty else {
            return
        }

        let inset = textContainerInset
        let rect = NSRect(
            x: inset.width + 4,
            y: inset.height + 2,
            width: max(0, bounds.width - inset.width * 2 - 8),
            height: max(0, bounds.height - inset.height * 2)
        )
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        placeholderString.draw(
            in: rect,
            withAttributes: [
                .font: font ?? NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.placeholderTextColor,
                .paragraphStyle: paragraphStyle
            ]
        )
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }
}

private final class CustomPlantAssetPromptButton: NSButton {
    var promptInsertion = ""
}

@MainActor
private final class CustomPlantAssetPromptAssistant: NSObject {
    private weak var textView: NSTextView?
    private let kind: PlantKind

    init(textView: NSTextView, kind: PlantKind) {
        self.textView = textView
        self.kind = kind
    }

    @objc func insertPromptFragment(_ sender: NSButton) {
        guard let button = sender as? CustomPlantAssetPromptButton,
              !button.promptInsertion.isEmpty else {
            return
        }

        append(button.promptInsertion)
    }

    @objc func useStarterDescription(_ sender: NSButton) {
        guard let textView else {
            return
        }

        textView.string = CustomPlantAssetPromptStudio.starterDescription(for: kind)
        textView.needsDisplay = true
        textView.window?.makeFirstResponder(textView)
    }

    private func append(_ fragment: String) {
        guard let textView else {
            return
        }

        let current = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        textView.string = current.isEmpty ? fragment : "\(current), \(fragment)"
        textView.needsDisplay = true
        textView.window?.makeFirstResponder(textView)
    }
}

@MainActor
final class GardenStatusMenu: NSObject {
    private struct PlantKindMenuStyle {
        var accent: NSColor
        var symbolName: String
    }

    private struct PlantingTarget {
        let screenIndex: Int
        let position: GardenPoint
    }

    private let store: GardenStore
    private let wallpaperManager: WallpaperManager
    private let statusItem: NSStatusItem
    static let statusMenuTooltipsEnabledByDefaultForSelfTest = false
    private let careSummaryItem = NSMenuItem()
    private let vitalityItem = NSMenuItem()
    private let environmentItem = NSMenuItem()
    private let recommendationItem = NSMenuItem()
    private let todayInGardenItem = NSMenuItem()
    private let assistantItem = NSMenuItem()
    private let generationStatusItem = NSMenuItem()
    private let selectedGrowthItem = NSMenuItem()
    private let experienceModeItem = NSMenuItem()
    private let liveStatusHeaderSeparator = NSMenuItem.separator()
    private let waterThirstyItem = NSMenuItem()
    private let focusStatusItem = NSMenuItem()
    private let focusActionItem = NSMenuItem()
    private let lockInteractionItem = NSMenuItem()
    private let aiLockViewItem = NSMenuItem()
    private let pauseItem = NSMenuItem()
    private var currentStatusSymbolName = "leaf.fill"
    private let ambientSoundMenuItem = NSMenuItem()
    private let ambientSoundMasterItem = NSMenuItem()
    private var ambientSoundLayerItems: [GardenAmbientSoundLayer: NSMenuItem] = [:]
    private let ambientWildlifeItem = NSMenuItem()
    private let gnomeZoneDrawingItem = NSMenuItem()
    private let gnomePerspectiveAdjustmentItem = NSMenuItem()
    private let hideGnomeTribesItem = NSMenuItem()
    private let removeAllGnomeZonesItem = NSMenuItem()
    private let birdSkyZoneDrawingItem = NSMenuItem()
    private let hideBirdFlocksItem = NSMenuItem()
    private let removeAllBirdSkyZonesItem = NSMenuItem()
    private let soilBrushItem = NSMenuItem()
    private let removeAllSoilPatchesItem = NSMenuItem()
    private let catCompanionItem = NSMenuItem()
    private let musicButtonItem = NSMenuItem()
    private let radioCompanionToggleItem = NSMenuItem()
    private var radioCompanionChoiceItems: [NSMenuItem] = []
    private let errorItem = NSMenuItem()
    private let inputMonitoringItem = NSMenuItem()
    private let plantFlowerItem = NSMenuItem()
    private let plantTreeItem = NSMenuItem()
    private let plantFoliageItem = NSMenuItem()
    private let plantMeadowItem = NSMenuItem()
    private let plantEdibleItem = NSMenuItem()
    private let roomIndoorPlantItem = NSMenuItem()
    private var roomIndoorPlantSubmenu: NSMenu?
    private var plantCategorySubmenus: [PlantKind: NSMenu] = [:]
    private var alienPlantCategorySubmenus: [PlantKind: NSMenu] = [:]
    private let roomWallDecorItem = NSMenuItem()
    private let roomSoftGoodsItem = NSMenuItem()
    private let roomWardrobeItem = NSMenuItem()
    private let roomMediaTechItem = NSMenuItem()
    private let roomCollectiblesItem = NSMenuItem()
    private let roomLoungeGearItem = NSMenuItem()
    private var roomCategorySubmenus: [RoomObjectCategory: NSMenu] = [:]
    private var lastRenderedExperienceMode: GardenExperienceMode?
    private var lastRenderedAssistantMenuItemEnabled: Bool?
    private let updateWallpaperItem = NSMenuItem()
    private let wallpaperVersionsItem = NSMenuItem()
    private let progressionToggleItem = NSMenuItem()
    private let progressionStatusItem = NSMenuItem()
    private let progressionAdvanceItem = NSMenuItem()
    private let progressionRegenerateItem = NSMenuItem()
    private let progressionAutoAdvanceItem = NSMenuItem()
    private let progressionSetupItem = NSMenuItem()
    private let progressionResetItem = NSMenuItem()
    private var progressionAutoAdvanceChoiceItems: [NSMenuItem] = []
    private weak var progressionModeParentItem: NSMenuItem?
    /// Set by AppDelegate so a level-up can post a celebration notification +
    /// journal entry through the shared GardenMomentNotifier. Args: level,
    /// level title, isFinalLevel.
    var progressionLevelCelebrationHandler: ((Int, String, Bool) -> Void)?
    private var wallpaperVersionItems: [NSMenuItem] = []
    private weak var wallpaperVersionsSubmenu: NSMenu?
    private var wallpaperSceneItems: [NSMenuItem] = []
    private weak var primaryWallpaperScenesSubmenu: NSMenu?
    private weak var toolsWallpaperScenesSubmenu: NSMenu?
    private weak var sceneQuickSwitchLabel: NSTextField?
    private weak var seedPouchSubmenu: NSMenu?
    private let seedPouchItem = NSMenuItem()
    private let harvestCropsItem = NSMenuItem()
    private var settingsWindowController: GardenSettingsWindowController?
    private lazy var assistantWindowController = GardenAssistantWindowController { [weak self] in
        self?.assistantRuntimeContext()
    }
    private lazy var profileWindowController = GardenProfileWindowController(
        store: store,
        onManagePlan: { [weak self] in self?.presentPricing(lockedFeature: nil) },
        onOpenSettings: { [weak self] in self?.openSettings() }
    )
    private lazy var pricingWindowController = GardenPricingWindowController(
        onOpenAPIKeySettings: { [weak self] in self?.openAIAPIKeySettings() }
    )
    private var catSettingsWindowController: CatCompanionSettingsWindowController?
    private var welcomeController: GardenWelcomeController?
    private var mouseTrackingMonitor: Any?
    private var menuDelegate: MainActorMenuDelegate?
    private var notificationObservers: [NSObjectProtocol] = []
    private var lastDesktopPlantingTarget: PlantingTarget?
    private var lastMouseSampleTime = ContinuousClock.now
    private var isMenuVisible = false
    private var isGnomeZoneDrawingMode = false
    private var isBirdSkyZoneDrawingMode = false
    private var isSoilBrushMode = false
    private var isGnomePerspectiveAdjustmentMode = false
    private var gnomeSettlementSetupPanelController: GnomeSettlementSetupPanelController?
    private var isUpdatingWallpaper = false
    private var wallpaperUpdateTask: Task<Void, Never>?
    private static let appDefaultsSuiteName = "com.chrisdimarco.wallpapergarden"

    init(store: GardenStore, wallpaperManager: WallpaperManager) {
        self.store = store
        self.wallpaperManager = wallpaperManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusButton()
        buildMenu()
        installDesktopMouseTracking()
        observeNotification(name: .gardenStoreDidChange, object: store) { menu, _ in
            menu.storeDidChange()
        }
        observeNotification(name: .gardenEntitlementsDidChange) { menu, _ in
            menu.entitlementsDidChange()
        }
    }

    private func observeNotification(
        name: Notification.Name,
        object: Any? = nil,
        handler: @escaping @MainActor (GardenStatusMenu, Notification) -> Void
    ) {
        let observer = NotificationCenter.default.addObserver(
            forName: name,
            object: object,
            queue: nil
        ) { [weak self] notification in
            guard let self else {
                return
            }
            let delivery = MainActorNotificationDelivery(notification: notification)
            MainActor.assumeIsolated {
                handler(self, delivery.notification)
            }
        }
        notificationObservers.append(observer)
    }

    private func entitlementsDidChange() {
        // Rebuild so Pro/locked badges across the menu reflect the new tier.
        buildMenu()
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else {
            return
        }

        if let image = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "Plant Wallpaper") {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "Plant"
        }
    }

    func openPlantingMenu(at screenPoint: NSPoint) {
        // This request arrives from inside the desktop double-click CGEvent-tap
        // callback. Do ALL of the work on the next runloop tick: the menu
        // rebuild (refresh*/updateDynamicItems) is heavy enough that running it
        // inside the tap blocks it — adding lag and risking a tapDisabledByTimeout
        // that silently drops the next clicks ("not every time"). And popUp()
        // runs a modal loop, so opening synchronously lets the same click's
        // mouse-up dismiss it instantly (the earlier "flash"). Deferring the
        // whole thing keeps the tap responsive and the menu open.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateDesktopPlantingTarget(at: screenPoint)
            self.refreshPlantingMenus()
            self.refreshRoomStudioMenus()
            self.refreshSeedPouchMenu()
            self.updateDynamicItems()
            self.statusItem.menu?.popUp(positioning: nil, at: screenPoint, in: nil)
        }
    }

    private func buildMenu() {
        detachReusableMenuItems()
        lastRenderedExperienceMode = store.state.settings.experienceMode
        lastRenderedAssistantMenuItemEnabled = store.state.settings.isAssistantMenuItemEnabled
        plantCategorySubmenus.removeAll()
        roomCategorySubmenus.removeAll()
        let menu = NSMenu()
        let menuDelegate = MainActorMenuDelegate(
            willOpen: { [weak self] event in
                self?.menuWillOpen(event.menu)
            },
            didClose: { [weak self] event in
                self?.menuDidClose(event.menu)
            }
        )
        self.menuDelegate = menuDelegate
        menu.delegate = menuDelegate
        menu.autoenablesItems = false
        let titleItem = NSMenuItem(title: "Plant Wallpaper", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        generationStatusItem.target = self
        generationStatusItem.action = #selector(cancelWallpaperUpdate)
        generationStatusItem.keyEquivalent = ""
        generationStatusItem.isHidden = true
        menu.addItem(generationStatusItem)
        menu.addItem(sceneQuickSwitcherMenuItem())
        menu.addItem(wallpaperToolsMenu())
        menu.addItem(experienceModeMenuItem())

        careSummaryItem.isEnabled = false
        menu.addItem(careSummaryItem)
        vitalityItem.isEnabled = false
        menu.addItem(vitalityItem)
        environmentItem.isEnabled = false
        menu.addItem(environmentItem)
        recommendationItem.target = self
        recommendationItem.action = #selector(performRecommendedCare)
        recommendationItem.keyEquivalent = ""
        menu.addItem(recommendationItem)
        selectedGrowthItem.isEnabled = false
        menu.addItem(selectedGrowthItem)
        menu.addItem(liveStatusHeaderSeparator)

        menu.addItem(sectionHeaderItem("Do now"))
        if store.state.settings.experienceMode == .garden {
            menu.addItem(menuItem(title: "Water All", symbol: "drop.fill", action: #selector(waterAll)))
            waterThirstyItem.target = self
            waterThirstyItem.action = #selector(waterThirstyPlants)
            waterThirstyItem.keyEquivalent = ""
            if let image = NSImage(systemSymbolName: "drop.triangle.fill", accessibilityDescription: "Water Thirsty Plants") {
                image.isTemplate = true
                waterThirstyItem.image = image
            }
            menu.addItem(waterThirstyItem)
        }
        menu.addItem(plantingMenu())
        focusStatusItem.isEnabled = false
        menu.addItem(focusStatusItem)
        configureMenuItem(focusActionItem, title: "Start Focus Session", symbol: "timer", action: #selector(noOpFocusPlaceholder))
        focusActionItem.submenu = focusDurationSubmenu()
        focusActionItem.action = nil
        focusActionItem.target = nil
        focusActionItem.isEnabled = true
        menu.addItem(focusActionItem)
        pauseItem.target = self
        pauseItem.action = #selector(togglePaused)
        pauseItem.keyEquivalent = ""
        menu.addItem(pauseItem)
        lockInteractionItem.target = self
        lockInteractionItem.action = #selector(toggleGardenInteractionLock)
        lockInteractionItem.keyEquivalent = ""
        menu.addItem(lockInteractionItem)

        menu.addItem(sectionHeaderItem("Make it yours"))
        menu.addItem(progressionModeMenu())
        menu.addItem(catCompanionMenu())
        menu.addItem(ambienceAndRadioMenu())
        menu.addItem(gardenToolsMenu())
        aiLockViewItem.target = self
        aiLockViewItem.action = #selector(toggleAILockView)
        aiLockViewItem.keyEquivalent = ""
        menu.addItem(aiLockViewItem)

        menu.addItem(sectionHeaderItem("Keepsakes"))
        configureMenuItem(
            todayInGardenItem,
            title: todayMenuTitle(for: store.state.settings.experienceMode),
            symbol: "sparkles",
            action: #selector(showTodayInGarden)
        )
        menu.addItem(todayInGardenItem)
        menu.addItem(keepsakesMenu())

        menu.addItem(sectionHeaderItem("App & account"))
        configureMenuItem(
            assistantItem,
            title: "Jarvis Assistant...",
            symbol: "sparkles.rectangle.stack.fill",
            action: #selector(toggleJarvisAssistant)
        )
        if store.state.settings.isAssistantMenuItemEnabled {
            menu.addItem(assistantItem)
        }
        menu.addItem(menuItem(
            title: "Profile...",
            symbol: "person.crop.circle.fill",
            action: #selector(openProfile)
        ))
        menu.addItem(menuItem(
            title: "Settings & Dashboard...",
            symbol: "gearshape.fill",
            action: #selector(openSettings)
        ))
        menu.addItem(menuItem(
            title: GardenPricingCatalog.menuTitle,
            symbol: "crown.fill",
            action: #selector(showPricing)
        ))
        menu.addItem(helpAndDataMenu())
        menu.addItem(NSMenuItem.separator())

        errorItem.isEnabled = false
        menu.addItem(errorItem)
        configureMenuItem(
            inputMonitoringItem,
            title: "Desktop Clicks Limited - Open Privacy Settings...",
            symbol: "exclamationmark.shield",
            action: #selector(openInputMonitoringSettings)
        )
        menu.addItem(inputMonitoringItem)
        menu.addItem(menuItem(title: "Quit", symbol: "power", action: #selector(quit)))

        statusItem.menu = menu
        updateDynamicItems()
    }

    private func applyStatusMenuTooltipPolicy() {
        guard !Self.statusMenuTooltipsEnabledByDefaultForSelfTest else {
            return
        }

        statusItem.button?.toolTip = nil
        if let menu = statusItem.menu {
            Self.stripTooltips(in: menu)
        }
    }

    private static func stripTooltips(in menu: NSMenu) {
        for item in menu.items {
            item.toolTip = nil
            if let submenu = item.submenu {
                stripTooltips(in: submenu)
            }
        }
    }

    private static func tooltips(in menu: NSMenu) -> [String] {
        menu.items.flatMap { item -> [String] in
            let ownTooltip = item.toolTip.map { [$0] } ?? []
            guard let submenu = item.submenu else {
                return ownTooltip
            }

            return ownTooltip + tooltips(in: submenu)
        }
    }

    private func detachReusableMenuItems() {
        let items: [NSMenuItem] = [
            careSummaryItem,
            vitalityItem,
            environmentItem,
            recommendationItem,
            todayInGardenItem,
            assistantItem,
            generationStatusItem,
            selectedGrowthItem,
            experienceModeItem,
            liveStatusHeaderSeparator,
            waterThirstyItem,
            focusStatusItem,
            focusActionItem,
            lockInteractionItem,
            aiLockViewItem,
            pauseItem,
            ambientSoundMenuItem,
            ambientSoundMasterItem,
            ambientWildlifeItem,
            gnomeZoneDrawingItem,
            gnomePerspectiveAdjustmentItem,
            hideGnomeTribesItem,
            removeAllGnomeZonesItem,
            birdSkyZoneDrawingItem,
            hideBirdFlocksItem,
            removeAllBirdSkyZonesItem,
            soilBrushItem,
            removeAllSoilPatchesItem,
            catCompanionItem,
            musicButtonItem,
            radioCompanionToggleItem,
            errorItem,
            inputMonitoringItem,
            plantFlowerItem,
            plantTreeItem,
            plantFoliageItem,
            plantMeadowItem,
            plantEdibleItem,
            roomIndoorPlantItem,
            roomWallDecorItem,
            roomSoftGoodsItem,
            roomWardrobeItem,
            roomMediaTechItem,
            roomCollectiblesItem,
            roomLoungeGearItem,
            updateWallpaperItem,
            wallpaperVersionsItem,
            progressionToggleItem,
            progressionStatusItem,
            progressionAdvanceItem,
            progressionRegenerateItem,
            progressionAutoAdvanceItem,
            progressionSetupItem,
            progressionResetItem,
            seedPouchItem,
            harvestCropsItem
        ]
        for item in items + Array(ambientSoundLayerItems.values) + radioCompanionChoiceItems + wallpaperVersionItems + wallpaperSceneItems + progressionAutoAdvanceChoiceItems {
            item.menu?.removeItem(item)
            item.submenu = nil
        }
        statusItem.menu = nil
    }

    func menuTitlesForSelfTest() -> [String] {
        statusItem.menu?.items.map(\.title) ?? []
    }

    func visibleMenuTitlesForSelfTest() -> [String] {
        statusItem.menu?.items
            .filter { !$0.isHidden }
            .map(\.title) ?? []
    }

    func menuTooltipsForSelfTest() -> [String] {
        guard let menu = statusItem.menu else {
            return []
        }

        return Self.tooltips(in: menu)
    }

    func primaryWallpaperSceneTitlesForSelfTest() -> [String] {
        primaryWallpaperScenesSubmenu?.items
            .filter { !$0.isSeparatorItem }
            .map(\.title) ?? []
    }

    func primaryWallpaperSceneAvailabilityForSelfTest() -> [String: Bool] {
        Dictionary(
            uniqueKeysWithValues: primaryWallpaperScenesSubmenu?.items
                .filter { !$0.isSeparatorItem }
                .map { ($0.title, $0.isEnabled) } ?? []
        )
    }

    func wallpaperVersionActionsForSelfTest() -> [String: String] {
        refreshWallpaperScenesMenu()
        updateDynamicItems()
        return Dictionary(
            uniqueKeysWithValues: wallpaperVersionsSubmenu?.items
                .filter { !$0.isSeparatorItem }
                .map { ($0.title, $0.action.map(NSStringFromSelector) ?? "") } ?? []
        )
    }

    func applyWallpaperVersionForSelfTest(_ sceneKey: String) {
        applyWallpaperSceneKey(sceneKey, screensOverride: [])
    }

    func refreshWallpaperScenesMenuForSelfTest() {
        refreshWallpaperScenesMenu()
    }

    func refreshPlantingMenusForSelfTest() {
        refreshPlantingMenus()
        refreshRoomStudioMenus()
    }

    func wallpaperToolsTitlesForSelfTest() -> [String] {
        statusItem.menu?.items
            .first { $0.title == "Wallpaper & Scenes" }?
            .submenu?
            .items
            .filter { !$0.isSeparatorItem }
            .map(\.title) ?? []
    }

    func submenuTitlesForSelfTest(named title: String) -> [String] {
        updateDynamicItems()
        guard let menu = statusItem.menu,
              let item = Self.menuItem(in: menu, titled: title),
              let submenu = item.submenu else {
            return []
        }

        return submenu.items
            .filter { !$0.isSeparatorItem }
            .map(\.title)
    }

    func submenuAvailabilityForSelfTest(named title: String) -> [String: Bool] {
        updateDynamicItems()
        guard let menu = statusItem.menu,
              let item = Self.menuItem(in: menu, titled: title),
              let submenu = item.submenu else {
            return [:]
        }

        return Dictionary(
            uniqueKeysWithValues: submenu.items
                .filter { !$0.isSeparatorItem }
                .map { ($0.title, $0.isEnabled) }
        )
    }

    func menuItemStateForSelfTest(named title: String) -> NSControl.StateValue? {
        updateDynamicItems()
        guard let menu = statusItem.menu,
              let item = Self.menuItem(in: menu, titled: title) else {
            return nil
        }

        return item.state
    }

    private static func menuItem(in menu: NSMenu, titled title: String) -> NSMenuItem? {
        for item in menu.items {
            if item.title == title {
                return item
            }

            if let submenu = item.submenu,
               let nestedItem = menuItem(in: submenu, titled: title) {
                return nestedItem
            }
        }

        return nil
    }

    func selectExperienceModeForSelfTest(_ mode: GardenExperienceMode) {
        switchExperienceMode(to: mode, bypassingPaywall: true)
    }

    private func menuItem(title: String, symbol: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        configureMenuItem(item, title: title, symbol: symbol, action: action)
        return item
    }

    private func isProFeatureUnlocked(_ feature: GardenProFeature) -> Bool {
        GardenEntitlements.shared.isUnlocked(feature)
    }

    @discardableResult
    private func requireProFeature(_ feature: GardenProFeature) -> Bool {
        guard isProFeatureUnlocked(feature) else {
            presentPricing(lockedFeature: feature)
            return false
        }

        return true
    }

    private func configureMenuItem(_ item: NSMenuItem, title: String, symbol: String, action: Selector) {
        item.title = title
        item.target = self
        item.action = action
        item.keyEquivalent = ""
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: title) {
            image.isTemplate = true
            item.image = image
        }
    }

    private func submenuItem(title: String, symbol: String, submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: title) {
            image.isTemplate = true
            item.image = image
        }
        item.submenu = submenu
        return item
    }

    private func experienceModeMenuItem() -> NSMenuItem {
        let currentMode = store.state.settings.experienceMode
        experienceModeItem.title = "Mode: \(currentMode.displayName)"
        experienceModeItem.image = NSImage(systemSymbolName: Self.modeSymbolName(for: currentMode), accessibilityDescription: experienceModeItem.title)
        experienceModeItem.image?.isTemplate = true
        let submenu = NSMenu(title: "Mode")
        for mode in GardenExperienceMode.allCases {
            let feature = Self.proFeature(for: mode)
            let isLocked = feature.map { !isProFeatureUnlocked($0) } ?? false
            let title = isLocked ? "\(mode.displayName) (Pro)" : mode.displayName
            let item = NSMenuItem(title: title, action: #selector(selectExperienceMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = store.state.settings.experienceMode == mode ? .on : .off
            item.toolTip = isLocked
                ? feature?.paywallMessage
                : Self.modeTooltip(for: mode)
            if let image = NSImage(systemSymbolName: Self.modeSymbolName(for: mode), accessibilityDescription: mode.displayName) {
                image.isTemplate = true
                item.image = image
            }
            submenu.addItem(item)
        }
        experienceModeItem.submenu = submenu
        return experienceModeItem
    }

    private static func modeSymbolName(for mode: GardenExperienceMode) -> String {
        switch mode {
        case .garden:
            "leaf.fill"
        case .roomStudio:
            "bed.double.fill"
        case .alienUFO:
            "sparkles"
        }
    }

    private static func modeTooltip(for mode: GardenExperienceMode) -> String {
        switch mode {
        case .garden:
            "Create living desktop gardens with plants, care, harvests, and seeds."
        case .roomStudio:
            "Create bedroom, hangout room, studio, and man cave scenes with generated room props."
        case .alienUFO:
            "Create strange alien garden scenes with UFO environments and generated exobiology plants."
        }
    }

    private static func proFeature(for mode: GardenExperienceMode) -> GardenProFeature? {
        switch mode {
        case .garden:
            nil
        case .roomStudio:
            .roomStudio
        case .alienUFO:
            .alienUFOGarden
        }
    }

    private func todayMenuTitle(for mode: GardenExperienceMode) -> String {
        switch mode {
        case .garden:
            "Today in Garden..."
        case .roomStudio:
            "Today in Room Studio..."
        case .alienUFO:
            "Today in Alien Garden..."
        }
    }

    private func roomIndoorPlantMenuItem() -> NSMenuItem {
        roomIndoorPlantItem.title = RoomStudioPlantMenuCatalog.title
        roomIndoorPlantItem.attributedTitle = Self.plantMenuTitle(
            RoomStudioPlantMenuCatalog.title,
            color: NSColor.systemGreen
        )
        roomIndoorPlantItem.target = nil
        roomIndoorPlantItem.action = nil
        roomIndoorPlantItem.keyEquivalent = ""
        roomIndoorPlantItem.image = Self.tintedSymbol(
            "leaf.fill",
            color: NSColor.systemGreen,
            accessibilityDescription: RoomStudioPlantMenuCatalog.title
        )

        let submenu = NSMenu(title: RoomStudioPlantMenuCatalog.title)
        submenu.autoenablesItems = false
        roomIndoorPlantSubmenu = submenu
        populateRoomIndoorPlantSubmenu(submenu)
        roomIndoorPlantItem.submenu = submenu
        return roomIndoorPlantItem
    }

    private func populateRoomIndoorPlantSubmenu(_ submenu: NSMenu) {
        submenu.removeAllItems()

        let enabledSpecies = GardenPlantSpecificMenuCatalog.enabledRoomStudioIndoorSpecies(
            sceneKey: store.activeSceneKey
        )

        let addNewItem = NSMenuItem(
            title: RoomStudioPlantMenuCatalog.addNewTitle,
            action: #selector(createCustomPlantAsset(_:)),
            keyEquivalent: ""
        )
        addNewItem.target = self
        addNewItem.representedObject = PlantKind.foliage.rawValue
        addNewItem.toolTip = "Create a new transparent PNG indoor plant asset with AI, then place it in this room."
        if let image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: addNewItem.title) {
            image.isTemplate = true
            addNewItem.image = image
        }
        submenu.addItem(addNewItem)
        submenu.addItem(NSMenuItem.separator())

        let savedIndoorPlants = store.customPlantAssets.savedPlantAssets(mode: .roomStudio)
        for record in savedIndoorPlants {
            submenu.addItem(savedCustomAssetMenuItem(
                for: record,
                symbolName: "leaf.fill",
                color: NSColor.systemGreen
            ))
        }
        if !savedIndoorPlants.isEmpty {
            submenu.addItem(NSMenuItem.separator())
        }

        let randomItem = NSMenuItem(
            title: RoomStudioPlantMenuCatalog.randomTitle,
            action: enabledSpecies.isEmpty ? nil : #selector(plantRandomIndoorPlant),
            keyEquivalent: ""
        )
        randomItem.target = enabledSpecies.isEmpty ? nil : self
        randomItem.isEnabled = !enabledSpecies.isEmpty
        randomItem.toolTip = enabledSpecies.isEmpty
            ? "No asset-ready indoor plants fit this room."
            : "Place a room-friendly plant at the current cursor location."
        submenu.addItem(randomItem)
        submenu.addItem(NSMenuItem.separator())

        let entries = GardenPlantSpecificMenuCatalog.roomStudioIndoorEntries(sceneKey: store.activeSceneKey)
        let assetReadyEntries = entries.filter(\.isAssetAvailable)
        let placeholderEntries = entries.filter { !$0.isAssetAvailable }

        for entry in assetReadyEntries {
            submenu.addItem(plantSpeciesMenuItem(for: entry))
        }

        if !placeholderEntries.isEmpty {
            submenu.addItem(NSMenuItem.separator())
            let comingSoonItem = NSMenuItem(title: "Coming Soon - needs PNG assets", action: nil, keyEquivalent: "")
            comingSoonItem.isEnabled = false
            submenu.addItem(comingSoonItem)

            for entry in placeholderEntries {
                submenu.addItem(plantSpeciesMenuItem(for: entry))
            }
        }
    }

    private func roomCategoryMenuItem(_ item: NSMenuItem, category: RoomObjectCategory) -> NSMenuItem {
        item.title = category.menuTitle
        item.target = nil
        item.action = nil
        item.keyEquivalent = ""
        item.image = NSImage(systemSymbolName: category.symbolName, accessibilityDescription: category.menuTitle)
        item.image?.isTemplate = true

        let submenu = NSMenu(title: category.menuTitle)
        submenu.autoenablesItems = false
        roomCategorySubmenus[category] = submenu
        populateRoomCategorySubmenu(submenu, category: category)
        item.submenu = submenu
        return item
    }

    private func populateRoomCategorySubmenu(_ submenu: NSMenu, category: RoomObjectCategory) {
        submenu.removeAllItems()
        let addNewItem = NSMenuItem(
            title: category.addNewTitle,
            action: #selector(createCustomRoomObjectAsset(_:)),
            keyEquivalent: ""
        )
        addNewItem.target = self
        addNewItem.representedObject = category.rawValue
        addNewItem.toolTip = "Generate a transparent PNG room object, perspective-matched to the clicked area."
        if let image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: addNewItem.title) {
            image.isTemplate = true
            addNewItem.image = image
        }
        submenu.addItem(addNewItem)
        submenu.addItem(NSMenuItem.separator())

        let savedObjects = store.customPlantAssets.savedRoomObjectAssets(in: category)
        for record in savedObjects {
            submenu.addItem(savedCustomAssetMenuItem(
                for: record,
                symbolName: category.symbolName,
                color: NSColor.systemTeal
            ))
        }
        if !savedObjects.isEmpty {
            submenu.addItem(NSMenuItem.separator())
        }

        let templates = RoomStudioMenuCatalog.templates(in: category)
        for template in templates {
            let item = NSMenuItem(
                title: template.title,
                action: #selector(createTemplateRoomObjectAsset(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = template.title
            item.toolTip = template.promptSeed
            if let image = NSImage(systemSymbolName: category.symbolName, accessibilityDescription: template.title) {
                image.isTemplate = true
                item.image = image
            }
            submenu.addItem(item)
        }
    }

    private func sceneQuickSwitcherMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 4, left: 12, bottom: 5, right: 12)
        row.frame = NSRect(x: 0, y: 0, width: 300, height: 38)

        let previousButton = sceneQuickSwitchButton(
            symbol: "chevron.left",
            tooltip: "Previous wallpaper scene",
            action: #selector(applyPreviousWallpaperScene)
        )
        let nextButton = sceneQuickSwitchButton(
            symbol: "chevron.right",
            tooltip: "Next wallpaper scene",
            action: #selector(applyNextWallpaperScene)
        )
        let label = NSTextField(labelWithString: activeSceneName)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        sceneQuickSwitchLabel = label

        row.addArrangedSubview(previousButton)
        row.addArrangedSubview(label)
        row.addArrangedSubview(nextButton)
        item.view = row
        return item
    }

    private func sceneQuickSwitchButton(symbol: String, tooltip: String, action: Selector) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .texturedRounded
        button.isBordered = true
        button.imagePosition = .imageOnly
        button.target = self
        button.action = action
        button.toolTip = tooltip
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip) {
            image.isTemplate = true
            button.image = image
        }
        button.widthAnchor.constraint(equalToConstant: 30).isActive = true
        button.heightAnchor.constraint(equalToConstant: 26).isActive = true
        return button
    }

    private static func radioCompanionPlacement(
        near position: GardenPoint,
        existingCount: Int
    ) -> GardenPoint {
        let step = min(existingCount, 11)
        let column = step % 4
        let row = step / 4
        let xOffset = Double(column) * 0.045
        let yOffset = Double(row) * 0.055
        return GardenPoint(
            x: min(0.96, max(0.04, position.x + xOffset)),
            y: min(0.96, max(0.04, position.y + yOffset))
        )
    }

    private static func symbolName(for companion: GardenRadioCompanion) -> String {
        switch companion {
        case .gardenCat:
            "pawprint.fill"
        case .moonMoth:
            "moon.stars.fill"
        case .mushroomSpeaker:
            "speaker.wave.2.fill"
        case .brassFrog:
            "music.note"
        case .tinyRocket:
            "paperplane.fill"
        case .toyDelorean:
            "car.fill"
        case .bigfootFieldRadio:
            "tree.fill"
        case .miniUfoTerrarium:
            "sparkles"
        case .chillGardenGnome:
            "leaf.fill"
        case .greyAlienGardener:
            "antenna.radiowaves.left.and.right"
        case .cassetteSamurai:
            "recordingtape"
        case .sphinxPhonograph:
            "building.columns.fill"
        case .dubNinjaBonsai:
            "tree.fill"
        case .berlinBearSynth:
            "waveform"
        case .cinemaProjectorFirefly:
            "movieclapper.fill"
        }
    }

    private func gardenToolsMenu() -> NSMenuItem {
        let mode = store.state.settings.experienceMode
        let title = Self.toolsMenuTitle(for: mode)
        let submenu = NSMenu(title: title)
        submenu.autoenablesItems = false

        switch mode {
        case .garden:
            ambientWildlifeItem.target = self
            ambientWildlifeItem.action = #selector(toggleAmbientWildlife)
            ambientWildlifeItem.keyEquivalent = ""
            submenu.addItem(ambientWildlifeItem)

            submenu.addItem(NSMenuItem.separator())
            gnomeZoneDrawingItem.target = self
            gnomeZoneDrawingItem.action = #selector(toggleGnomeZoneDrawingMode)
            gnomeZoneDrawingItem.keyEquivalent = ""
            submenu.addItem(gnomeZoneDrawingItem)
            gnomePerspectiveAdjustmentItem.target = self
            gnomePerspectiveAdjustmentItem.action = #selector(toggleGnomePerspectiveAdjustmentMode)
            gnomePerspectiveAdjustmentItem.keyEquivalent = ""
            submenu.addItem(gnomePerspectiveAdjustmentItem)
            hideGnomeTribesItem.target = self
            hideGnomeTribesItem.action = #selector(toggleGnomeTribesHidden)
            hideGnomeTribesItem.keyEquivalent = ""
            submenu.addItem(hideGnomeTribesItem)
            removeAllGnomeZonesItem.target = self
            removeAllGnomeZonesItem.action = #selector(removeAllGnomesFromScene)
            removeAllGnomeZonesItem.keyEquivalent = ""
            submenu.addItem(removeAllGnomeZonesItem)
            birdSkyZoneDrawingItem.target = self
            birdSkyZoneDrawingItem.action = #selector(toggleBirdSkyZoneDrawingMode)
            birdSkyZoneDrawingItem.keyEquivalent = ""
            submenu.addItem(birdSkyZoneDrawingItem)
            hideBirdFlocksItem.target = self
            hideBirdFlocksItem.action = #selector(toggleBirdFlocksHidden)
            hideBirdFlocksItem.keyEquivalent = ""
            submenu.addItem(hideBirdFlocksItem)
            removeAllBirdSkyZonesItem.target = self
            removeAllBirdSkyZonesItem.action = #selector(removeAllBirdSkyZonesFromScene)
            removeAllBirdSkyZonesItem.keyEquivalent = ""
            submenu.addItem(removeAllBirdSkyZonesItem)
            soilBrushItem.target = self
            soilBrushItem.action = #selector(toggleSoilBrushMode)
            soilBrushItem.keyEquivalent = ""
            submenu.addItem(soilBrushItem)
            removeAllSoilPatchesItem.target = self
            removeAllSoilPatchesItem.action = #selector(removeAllSoilPatchesFromScene)
            removeAllSoilPatchesItem.keyEquivalent = ""
            submenu.addItem(removeAllSoilPatchesItem)

            submenu.addItem(NSMenuItem.separator())
            submenu.addItem(menuItem(title: "Prune Selected", symbol: "scissors", action: #selector(pruneSelected)))
            submenu.addItem(menuItem(title: "Nourish Selected", symbol: "sparkles", action: #selector(nourishSelected)))
            submenu.addItem(menuItem(title: "Remove Selected", symbol: "trash", action: #selector(removeSelected)))
        case .roomStudio:
            submenu.addItem(menuItem(title: "Remove Selected Object", symbol: "trash", action: #selector(removeSelected)))
        case .alienUFO:
            ambientWildlifeItem.target = self
            ambientWildlifeItem.action = #selector(toggleAmbientWildlife)
            ambientWildlifeItem.keyEquivalent = ""
            submenu.addItem(ambientWildlifeItem)
            submenu.addItem(NSMenuItem.separator())
            submenu.addItem(menuItem(title: "Prune Selected Alien Plant", symbol: "scissors", action: #selector(pruneSelected)))
            submenu.addItem(menuItem(title: "Nourish Selected Alien Plant", symbol: "sparkles", action: #selector(nourishSelected)))
            submenu.addItem(menuItem(title: "Remove Selected Alien Plant", symbol: "trash", action: #selector(removeSelected)))
        }

        return submenuItem(title: title, symbol: "slider.horizontal.3", submenu: submenu)
    }

    private static func toolsMenuTitle(for mode: GardenExperienceMode) -> String {
        switch mode {
        case .garden:
            "Garden Tools"
        case .roomStudio:
            "Room Studio Tools"
        case .alienUFO:
            "Alien Garden Tools"
        }
    }

    private static func lockInteractionTitle(for mode: GardenExperienceMode) -> String {
        switch mode {
        case .garden:
            "Lock Garden Interactions"
        case .roomStudio:
            "Lock Room Studio Interactions"
        case .alienUFO:
            "Lock Alien Garden Interactions"
        }
    }

    private static func modeNoun(for mode: GardenExperienceMode) -> String {
        switch mode {
        case .garden:
            "Garden"
        case .roomStudio:
            "Room Studio"
        case .alienUFO:
            "Alien garden"
        }
    }

    private func ambientSoundMenu() -> NSMenuItem {
        let submenu = NSMenu(title: "Environmental Sounds")
        submenu.autoenablesItems = false

        ambientSoundMasterItem.target = self
        ambientSoundMasterItem.action = #selector(toggleAmbientSoundFromMenu)
        ambientSoundMasterItem.keyEquivalent = ""
        submenu.addItem(ambientSoundMasterItem)
        submenu.addItem(NSMenuItem.separator())

        ambientSoundLayerItems.removeAll()
        for entry in GardenAmbientSoundMenuCatalog.entries.dropFirst() {
            let item = NSMenuItem(title: entry.title, action: #selector(toggleAmbientSoundLayerFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = entry.id.rawValue
            if let image = NSImage(systemSymbolName: entry.symbolName, accessibilityDescription: entry.title) {
                image.isTemplate = true
                item.image = image
            }
            ambientSoundLayerItems[entry.id] = item
            submenu.addItem(item)
        }

        ambientSoundMenuItem.title = "Environmental Sounds"
        if let image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: ambientSoundMenuItem.title) {
            image.isTemplate = true
            ambientSoundMenuItem.image = image
        }
        ambientSoundMenuItem.submenu = submenu
        return ambientSoundMenuItem
    }

    private func radioCompanionMenuItem() -> NSMenuItem {
        let submenu = NSMenu(title: "Radio Companion")
        submenu.autoenablesItems = false

        radioCompanionToggleItem.target = self
        radioCompanionToggleItem.action = #selector(toggleMusicButton)
        radioCompanionToggleItem.keyEquivalent = ""
        submenu.addItem(radioCompanionToggleItem)
        submenu.addItem(NSMenuItem.separator())

        radioCompanionChoiceItems = GardenRadioCompanionMenuCatalog.entries.map { entry in
            let companion = entry.companion
            let item = NSMenuItem(title: entry.title, action: #selector(selectRadioCompanion(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = companion.rawValue
            item.toolTip = entry.toolTip
            if let image = NSImage(systemSymbolName: Self.symbolName(for: companion), accessibilityDescription: companion.displayName) {
                image.isTemplate = true
                item.image = image
            }
            submenu.addItem(item)
            return item
        }

        musicButtonItem.title = "Radio Companion"
        if let image = NSImage(systemSymbolName: "radio.fill", accessibilityDescription: "Radio Companion") {
            image.isTemplate = true
            musicButtonItem.image = image
        }
        musicButtonItem.submenu = submenu
        return musicButtonItem
    }

    /// A non-clickable grouping label. Uses native macOS 14+ section headers
    /// when available, falling back to a disabled label row on macOS 13.
    private func sectionHeaderItem(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) {
            return NSMenuItem.sectionHeader(title: title)
        }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    /// Consolidates the mode-specific planting/placement actions into a single
    /// submenu so the main menu shows one row instead of five-to-seven.
    private func plantingMenu() -> NSMenuItem {
        let submenu = NSMenu(title: "Plant Here")
        submenu.autoenablesItems = false
        let title: String
        let symbol: String

        switch store.state.settings.experienceMode {
        case .garden:
            title = "Plant Here"
            symbol = "leaf.fill"
            submenu.addItem(plantCategoryMenuItem(
                plantFlowerItem,
                title: "Plant Flower Here",
                kind: .flower,
                randomAction: #selector(plantFlower)
            ))
            submenu.addItem(plantCategoryMenuItem(
                plantTreeItem,
                title: "Plant Tree Here",
                kind: .tree,
                randomAction: #selector(plantTree)
            ))
            submenu.addItem(plantCategoryMenuItem(
                plantFoliageItem,
                title: "Plant Foliage Here",
                kind: .foliage,
                randomAction: #selector(plantFoliage)
            ))
            submenu.addItem(plantCategoryMenuItem(
                plantMeadowItem,
                title: "Plant Groundcover Here",
                kind: .meadow,
                randomAction: #selector(plantMeadow)
            ))
            submenu.addItem(plantCategoryMenuItem(
                plantEdibleItem,
                title: "Plant Edible Here",
                kind: .edible,
                randomAction: #selector(plantEdible)
            ))
            submenu.addItem(NSMenuItem.separator())
            submenu.addItem(seedPouchMenu())
            harvestCropsItem.target = self
            harvestCropsItem.action = #selector(harvestReadyCrops)
            harvestCropsItem.keyEquivalent = ""
            if let image = NSImage(systemSymbolName: "basket.fill", accessibilityDescription: "Harvest Ready Crops") {
                image.isTemplate = true
                harvestCropsItem.image = image
            }
            submenu.addItem(harvestCropsItem)
        case .roomStudio:
            title = "Place Items Here"
            symbol = "shippingbox.fill"
            submenu.addItem(roomIndoorPlantMenuItem())
            submenu.addItem(roomCategoryMenuItem(roomWallDecorItem, category: .wallDecor))
            submenu.addItem(roomCategoryMenuItem(roomSoftGoodsItem, category: .softGoods))
            submenu.addItem(roomCategoryMenuItem(roomWardrobeItem, category: .wardrobe))
            submenu.addItem(roomCategoryMenuItem(roomMediaTechItem, category: .mediaTech))
            submenu.addItem(roomCategoryMenuItem(roomCollectiblesItem, category: .collectibles))
            submenu.addItem(roomCategoryMenuItem(roomLoungeGearItem, category: .loungeGear))
        case .alienUFO:
            title = "Plant Here"
            symbol = "leaf.fill"
            submenu.addItem(alienPlantCategoryMenuItem(plantFlowerItem, kind: .flower))
            submenu.addItem(alienPlantCategoryMenuItem(plantTreeItem, kind: .tree))
            submenu.addItem(alienPlantCategoryMenuItem(plantFoliageItem, kind: .foliage))
            submenu.addItem(alienPlantCategoryMenuItem(plantMeadowItem, kind: .meadow))
            submenu.addItem(alienPlantCategoryMenuItem(plantEdibleItem, kind: .edible))
        }

        return submenuItem(title: title, symbol: symbol, submenu: submenu)
    }

    /// Merges the cat companion visibility toggle and its settings into one row.
    private func catCompanionMenu() -> NSMenuItem {
        let submenu = NSMenu(title: "Cat Companion")
        submenu.autoenablesItems = false
        catCompanionItem.target = self
        catCompanionItem.action = #selector(toggleCatCompanion)
        catCompanionItem.keyEquivalent = ""
        submenu.addItem(catCompanionItem)
        submenu.addItem(menuItem(
            title: "Cat Companion Settings...",
            symbol: "pawprint.fill",
            action: #selector(openCatCompanionSettings)
        ))
        return submenuItem(title: "Cat Companion", symbol: "pawprint.fill", submenu: submenu)
    }

    /// Merges environmental sounds and the radio companion under one row.
    private func ambienceAndRadioMenu() -> NSMenuItem {
        let submenu = NSMenu(title: "Ambience & Radio")
        submenu.autoenablesItems = false
        submenu.addItem(ambientSoundMenu())
        submenu.addItem(radioCompanionMenuItem())
        return submenuItem(title: "Ambience & Radio", symbol: "speaker.wave.2.fill", submenu: submenu)
    }

    private func keepsakesMenu() -> NSMenuItem {
        let submenu = NSMenu(title: "Keepsakes & Exports")
        submenu.autoenablesItems = false
        submenu.addItem(menuItem(title: "Save Garden Snapshot...", symbol: "camera.on.rectangle", action: #selector(saveGardenSnapshot)))
        submenu.addItem(menuItem(title: "Save Share Card...", symbol: "square.and.arrow.up", action: #selector(saveShareCard)))
        submenu.addItem(menuItem(title: "Export Time-Lapse...", symbol: "film.stack", action: #selector(exportTimeLapse)))
        submenu.addItem(menuItem(title: "Save Garden Health Check...", symbol: "stethoscope", action: #selector(saveHealthCheck)))
        return submenuItem(title: "Keepsakes & Exports", symbol: "tray.and.arrow.down.fill", submenu: submenu)
    }

    private func wallpaperToolsMenu() -> NSMenuItem {
        let submenu = NSMenu(title: "Wallpaper & Scenes")
        submenu.autoenablesItems = false
        configureMenuItem(
            updateWallpaperItem,
            title: "Update Current Wallpaper...",
            symbol: "wand.and.stars",
            action: #selector(updateCurrentWallpaper)
        )
        submenu.addItem(updateWallpaperItem)
        submenu.addItem(wallpaperVersionsMenu())
        submenu.addItem(NSMenuItem.separator())
        submenu.addItem(wallpaperScenesMenu(placement: .primary))
        submenu.addItem(menuItem(title: "Reapply Current Scene", symbol: "paintbrush.pointed.fill", action: #selector(applyLivingScene)))
        submenu.addItem(menuItem(title: "Choose Wallpaper...", symbol: "photo.badge.plus", action: #selector(chooseWallpaper)))
        submenu.addItem(menuItem(title: "Create AI Wallpaper...", symbol: "sparkles.rectangle.stack", action: #selector(createAIWallpaper)))
        submenu.addItem(menuItem(title: "OpenAI API Key Settings...", symbol: "key.fill", action: #selector(openAIAPIKeySettings)))
        submenu.addItem(menuItem(title: "Restore Previous Wallpaper", symbol: "photo.on.rectangle", action: #selector(restorePreviousWallpaper)))
        submenu.addItem(NSMenuItem.separator())
        if store.state.settings.experienceMode == .garden {
            submenu.addItem(menuItem(
                title: "Start Plants from Seedlings",
                symbol: "arrow.triangle.2.circlepath",
                action: #selector(startPlantsFromSeedlings)
            ))
        }
        submenu.addItem(menuItem(title: "Reset Garden", symbol: "arrow.counterclockwise", action: #selector(resetGarden)))
        submenu.addItem(menuItem(title: "Delete All Plants in Scene", symbol: "trash.slash", action: #selector(deleteAllPlantsInScene)))
        return submenuItem(title: "Wallpaper & Scenes", symbol: "photo.stack.fill", submenu: submenu)
    }

    private func progressionModeMenu() -> NSMenuItem {
        let submenu = NSMenu(title: "Progression Mode")
        submenu.autoenablesItems = false

        configureMenuItem(
            progressionToggleItem,
            title: "Progression Mode: Off",
            symbol: "power",
            action: #selector(toggleProgressionMode)
        )
        progressionToggleItem.toolTip = "Pause or resume this scene's level-up ladder. Pausing keeps your level and fantasy profile."
        submenu.addItem(progressionToggleItem)
        submenu.addItem(NSMenuItem.separator())

        progressionStatusItem.isEnabled = false
        submenu.addItem(progressionStatusItem)
        submenu.addItem(NSMenuItem.separator())

        configureMenuItem(
            progressionSetupItem,
            title: "Setup Fantasy Profile...",
            symbol: "person.text.rectangle",
            action: #selector(setupProgressionMode)
        )
        submenu.addItem(progressionSetupItem)

        configureMenuItem(
            progressionAdvanceItem,
            title: "Generate Next Level...",
            symbol: "arrow.up.forward.circle.fill",
            action: #selector(generateNextProgressionLevel)
        )
        submenu.addItem(progressionAdvanceItem)

        configureMenuItem(
            progressionRegenerateItem,
            title: "Regenerate This Level...",
            symbol: "arrow.triangle.2.circlepath",
            action: #selector(regenerateCurrentProgressionLevel)
        )
        progressionRegenerateItem.toolTip = "Re-roll the current level's wallpaper without advancing — for when you want a different take on the same step."
        submenu.addItem(progressionRegenerateItem)

        submenu.addItem(progressionAutoAdvanceMenu())
        submenu.addItem(NSMenuItem.separator())

        configureMenuItem(
            progressionResetItem,
            title: "Reset Progression",
            symbol: "arrow.counterclockwise.circle",
            action: #selector(resetProgressionMode)
        )
        submenu.addItem(progressionResetItem)

        let parentItem = submenuItem(title: "Progression Mode", symbol: "trophy.fill", submenu: submenu)
        progressionModeParentItem = parentItem
        return parentItem
    }

    private func progressionAutoAdvanceMenu() -> NSMenuItem {
        let submenu = NSMenu(title: "Auto-Advance")
        submenu.autoenablesItems = false
        progressionAutoAdvanceChoiceItems.removeAll()

        for cadence in GardenSceneProgression.AutoAdvanceCadence.allCases {
            let item = NSMenuItem(
                title: cadence.displayName,
                action: #selector(selectProgressionAutoAdvanceCadence(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = cadence.rawValue
            submenu.addItem(item)
            progressionAutoAdvanceChoiceItems.append(item)
        }

        progressionAutoAdvanceItem.title = "Auto-Advance"
        progressionAutoAdvanceItem.action = nil
        progressionAutoAdvanceItem.target = nil
        if let image = NSImage(systemSymbolName: "clock.arrow.2.circlepath", accessibilityDescription: "Auto-Advance") {
            image.isTemplate = true
            progressionAutoAdvanceItem.image = image
        }
        progressionAutoAdvanceItem.toolTip = "Let the ladder climb on its own. When due, the next level generates automatically (uses your OpenAI key)."
        progressionAutoAdvanceItem.submenu = submenu
        return progressionAutoAdvanceItem
    }

    private func helpAndDataMenu() -> NSMenuItem {
        let submenu = NSMenu(title: "Help & Data")
        submenu.autoenablesItems = false
        submenu.addItem(menuItem(title: "Show Welcome Tour...", symbol: "questionmark.circle", action: #selector(showWelcomeTour)))
        submenu.addItem(menuItem(title: "Privacy & Storage Settings...", symbol: "lock.shield.fill", action: #selector(openPrivacyStorageSettings)))
        submenu.addItem(menuItem(title: "Open Garden Data", symbol: "folder", action: #selector(openGardenData)))
        submenu.addItem(menuItem(title: "Uninstall & Cleanup Guide...", symbol: "trash", action: #selector(showUninstallCleanupGuide)))
        return submenuItem(title: "Help & Data", symbol: "questionmark.circle", submenu: submenu)
    }

    private enum WallpaperScenesMenuPlacement {
        case primary
        case tools
    }

    private func wallpaperScenesMenu(placement: WallpaperScenesMenuPlacement) -> NSMenuItem {
        let item = NSMenuItem(title: "Wallpaper Scene", action: nil, keyEquivalent: "")
        if let image = NSImage(systemSymbolName: "photo.stack.fill", accessibilityDescription: item.title) {
            image.isTemplate = true
            item.image = image
        }

        let submenu = NSMenu(title: item.title)
        switch placement {
        case .primary:
            primaryWallpaperScenesSubmenu = submenu
        case .tools:
            toolsWallpaperScenesSubmenu = submenu
        }
        populateWallpaperScenesSubmenu(submenu)
        item.submenu = submenu
        return item
    }

    private func wallpaperVersionsMenu() -> NSMenuItem {
        wallpaperVersionsItem.title = "Wallpaper Versions"
        if let image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: wallpaperVersionsItem.title) {
            image.isTemplate = true
            wallpaperVersionsItem.image = image
        }

        let submenu = NSMenu(title: wallpaperVersionsItem.title)
        submenu.autoenablesItems = false
        wallpaperVersionsSubmenu = submenu
        populateWallpaperVersionsSubmenu(submenu)
        wallpaperVersionsItem.submenu = submenu
        return wallpaperVersionsItem
    }

    private func populateWallpaperVersionsSubmenu(_ submenu: NSMenu) {
        submenu.removeAllItems()
        wallpaperVersionItems.removeAll()

        let entries = wallpaperManager.wallpaperVersions()
        guard entries.count > 1 else {
            let emptyItem = NSMenuItem(title: "No wallpaper edits yet", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
            return
        }

        for entry in entries {
            let item = NSMenuItem(
                title: GardenMenuTitleFormatter.compactStatusTitle(
                    entry.title,
                    maxLength: GardenMenuTitleFormatter.sceneTitleMaxLength
                ),
                action: #selector(applyWallpaperVersion(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = entry.key
            item.toolTip = entry.tooltip
            if let image = NSImage(
                systemSymbolName: entry.isOriginal ? "arrow.uturn.backward.circle.fill" : "sparkles.rectangle.stack",
                accessibilityDescription: entry.title
            ) {
                image.isTemplate = true
                item.image = image
            }
            wallpaperVersionItems.append(item)
            submenu.addItem(item)
        }
    }

    private func populateWallpaperScenesSubmenu(_ submenu: NSMenu) {
        submenu.removeAllItems()
        wallpaperSceneItems.removeAll()

        for scene in GardenWallpaperScene.scenes(for: store.state.settings.experienceMode) {
            let isSelectable = scene.isSelectableScene
            let sceneItem = NSMenuItem(
                title: GardenMenuTitleFormatter.compactStatusTitle(
                    scene.displayName,
                    maxLength: GardenMenuTitleFormatter.sceneTitleMaxLength
                ),
                action: isSelectable ? #selector(applyWallpaperScene(_:)) : nil,
                keyEquivalent: ""
            )
            sceneItem.target = isSelectable ? self : nil
            sceneItem.representedObject = scene.rawValue
            sceneItem.toolTip = scene.unavailableSceneReason ?? scene.displayName
            sceneItem.isEnabled = isSelectable
            if let image = NSImage(systemSymbolName: scene.symbolName, accessibilityDescription: scene.displayName) {
                image.isTemplate = true
                sceneItem.image = image
            }
            wallpaperSceneItems.append(sceneItem)
            submenu.addItem(sceneItem)
        }

        let customWallpapers = wallpaperManager.customWallpaperSceneRoots(for: store.state.settings.experienceMode)
        guard !customWallpapers.isEmpty else {
            return
        }

        submenu.addItem(NSMenuItem.separator())
        for record in customWallpapers {
            let customItem = NSMenuItem(
                title: GardenMenuTitleFormatter.compactStatusTitle(
                    record.displayName,
                    maxLength: GardenMenuTitleFormatter.sceneTitleMaxLength
                ),
                action: #selector(applyWallpaperSceneRoot(_:)),
                keyEquivalent: ""
            )
            customItem.target = self
            customItem.representedObject = record.key
            customItem.toolTip = record.displayName
            if let image = NSImage(systemSymbolName: "sparkles.rectangle.stack", accessibilityDescription: record.displayName) {
                image.isTemplate = true
                customItem.image = image
            }
            wallpaperSceneItems.append(customItem)
            submenu.addItem(customItem)
        }
    }

    private func refreshWallpaperScenesMenu() {
        if let primaryWallpaperScenesSubmenu {
            populateWallpaperScenesSubmenu(primaryWallpaperScenesSubmenu)
        }
        if let toolsWallpaperScenesSubmenu {
            populateWallpaperScenesSubmenu(toolsWallpaperScenesSubmenu)
        }
        if let wallpaperVersionsSubmenu {
            populateWallpaperVersionsSubmenu(wallpaperVersionsSubmenu)
        }
        updateDynamicItems()
    }

    private func plantCategoryMenuItem(
        _ item: NSMenuItem,
        title: String,
        kind: PlantKind,
        randomAction: Selector
    ) -> NSMenuItem {
        let style = Self.plantMenuStyle(for: kind)
        item.title = title
        item.attributedTitle = Self.plantMenuTitle(title, style: style)
        item.target = nil
        item.action = nil
        item.keyEquivalent = ""
        item.image = Self.tintedSymbol(
            style.symbolName,
            color: style.accent,
            accessibilityDescription: title
        )

        let submenu = NSMenu(title: title)
        submenu.autoenablesItems = false
        plantCategorySubmenus[kind] = submenu
        populatePlantCategorySubmenu(submenu, kind: kind, randomAction: randomAction)
        item.submenu = submenu
        return item
    }

    private func alienPlantCategoryMenuItem(_ item: NSMenuItem, kind: PlantKind) -> NSMenuItem {
        let title = AlienPlantMenuCatalog.title(for: kind)
        let style = Self.plantMenuStyle(for: kind)
        item.title = title
        item.attributedTitle = Self.plantMenuTitle(title, color: NSColor.systemPurple)
        item.target = nil
        item.action = nil
        item.keyEquivalent = ""
        item.image = Self.tintedSymbol(
            style.symbolName,
            color: NSColor.systemPurple,
            accessibilityDescription: title
        )

        let submenu = NSMenu(title: title)
        submenu.autoenablesItems = false
        alienPlantCategorySubmenus[kind] = submenu
        populateAlienPlantCategorySubmenu(submenu, kind: kind)
        item.submenu = submenu
        return item
    }

    private func populateAlienPlantCategorySubmenu(_ submenu: NSMenu, kind: PlantKind) {
        submenu.removeAllItems()
        let style = Self.plantMenuStyle(for: kind)

        let addNewItem = NSMenuItem(
            title: AlienPlantMenuCatalog.addNewTitle(for: kind),
            action: #selector(createCustomPlantAsset(_:)),
            keyEquivalent: ""
        )
        addNewItem.target = self
        addNewItem.representedObject = kind.rawValue
        addNewItem.toolTip = "Generate a transparent PNG alien \(kind.displayName.lowercased()) asset with AI, then plant it here."
        if let image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: addNewItem.title) {
            image.isTemplate = true
            addNewItem.image = image
        }
        submenu.addItem(addNewItem)
        submenu.addItem(NSMenuItem.separator())

        let savedPlants = store.customPlantAssets.savedPlantAssets(kind: kind, mode: .alienUFO)
        for record in savedPlants {
            submenu.addItem(savedCustomAssetMenuItem(
                for: record,
                symbolName: style.symbolName,
                color: NSColor.systemPurple
            ))
        }
        if !savedPlants.isEmpty {
            submenu.addItem(NSMenuItem.separator())
        }

        let enabledSpecimens = AlienPlantAssetLibrary.shared.enabledSpecimens(in: kind)
        let randomItem = NSMenuItem(
            title: AlienPlantMenuCatalog.randomTitle(for: kind),
            action: #selector(plantRandomAlienSpecimen(_:)),
            keyEquivalent: ""
        )
        randomItem.target = self
        randomItem.representedObject = kind.rawValue
        randomItem.isEnabled = !enabledSpecimens.isEmpty
        randomItem.toolTip = randomItem.isEnabled
            ? "Plant a random bundled alien \(kind.displayName.lowercased()) specimen here."
            : "Generate alien PNG assets first; then random alien planting can use them."
        submenu.addItem(randomItem)
        submenu.addItem(NSMenuItem.separator())

        let specimens = AlienPlantMenuCatalog.specimens(in: kind)
        let missingSpecimens = specimens.filter { !AlienPlantAssetLibrary.shared.hasDisplayableAsset(for: $0) }
        if !missingSpecimens.isEmpty {
            let comingSoonItem = NSMenuItem(title: "Coming Soon - needs PNG assets", action: nil, keyEquivalent: "")
            comingSoonItem.isEnabled = false
            submenu.addItem(comingSoonItem)
        }

        for specimen in specimens {
            let hasAsset = AlienPlantAssetLibrary.shared.hasDisplayableAsset(for: specimen)
            let specimenItem = NSMenuItem(
                title: specimen.title,
                action: hasAsset ? #selector(plantAlienSpecimen(_:)) : nil,
                keyEquivalent: ""
            )
            specimenItem.target = hasAsset ? self : nil
            specimenItem.representedObject = specimen.customAssetID
            specimenItem.isEnabled = hasAsset
            specimenItem.toolTip = specimen.promptSeed
            if let image = NSImage(systemSymbolName: style.symbolName, accessibilityDescription: specimen.title) {
                image.isTemplate = true
                specimenItem.image = image
            }
            submenu.addItem(specimenItem)
        }
    }

    private func populatePlantCategorySubmenu(
        _ submenu: NSMenu,
        kind: PlantKind,
        randomAction: Selector
    ) {
        submenu.removeAllItems()
        let style = Self.plantMenuStyle(for: kind)

        let hasEnabledSpecies = GardenPlantSpecificMenuCatalog.hasEnabledSpecies(
            sceneKey: store.activeSceneKey,
            in: kind
        )
        let addNewItem = NSMenuItem(
            title: GardenPlantCategoryMenuTitle.addNewTitle(for: kind),
            action: #selector(createCustomPlantAsset(_:)),
            keyEquivalent: ""
        )
        addNewItem.target = self
        addNewItem.representedObject = kind.rawValue
        addNewItem.toolTip = "Create a new transparent PNG \(kind.displayName.lowercased()) asset with AI, then plant it here."
        if let image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: addNewItem.title) {
            image.isTemplate = true
            addNewItem.image = image
        }
        submenu.addItem(addNewItem)
        submenu.addItem(NSMenuItem.separator())

        let savedPlants = store.customPlantAssets.savedPlantAssets(kind: kind, mode: .garden)
        for record in savedPlants {
            submenu.addItem(savedCustomAssetMenuItem(
                for: record,
                symbolName: style.symbolName,
                color: style.accent
            ))
        }
        if !savedPlants.isEmpty {
            submenu.addItem(NSMenuItem.separator())
        }

        let randomItem = NSMenuItem(
            title: GardenPlantCategoryMenuTitle.randomTitle(for: kind),
            action: hasEnabledSpecies ? randomAction : nil,
            keyEquivalent: ""
        )
        randomItem.target = hasEnabledSpecies ? self : nil
        randomItem.isEnabled = hasEnabledSpecies
        randomItem.toolTip = hasEnabledSpecies
            ? "Plant a suitable \(kind.displayName.lowercased()) at the current cursor location."
            : "No asset-ready \(kind.displayName.lowercased()) plants fit this scene."
        submenu.addItem(randomItem)
        submenu.addItem(NSMenuItem.separator())

        let entries = GardenPlantSpecificMenuCatalog.entries(sceneKey: store.activeSceneKey, in: kind)
        let assetReadyEntries = entries.filter(\.isAssetAvailable)
        let placeholderEntries = entries.filter { !$0.isAssetAvailable }

        for entry in assetReadyEntries {
            submenu.addItem(plantSpeciesMenuItem(for: entry))
        }

        if !placeholderEntries.isEmpty {
            submenu.addItem(NSMenuItem.separator())
            let comingSoonItem = NSMenuItem(title: "Coming Soon - needs PNG assets", action: nil, keyEquivalent: "")
            comingSoonItem.isEnabled = false
            submenu.addItem(comingSoonItem)

            for entry in placeholderEntries {
                submenu.addItem(plantSpeciesMenuItem(for: entry))
            }
        }
    }

    private func savedCustomAssetMenuItem(
        for record: CustomPlantAssetRecord,
        symbolName: String,
        color: NSColor
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: record.displayName,
            action: #selector(plantSavedCustomAsset(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = record.id
        item.isEnabled = store.customPlantAssets.hasDisplayableAsset(forCustomAssetID: record.id)
        item.image = Self.tintedSymbol(
            symbolName,
            color: color,
            accessibilityDescription: record.displayName
        )
        return item
    }

    private func plantSpeciesMenuItem(for entry: GardenPlantSpecificMenuEntry) -> NSMenuItem {
        let species = entry.species
        let speciesItem = NSMenuItem(
            title: species.displayName,
            action: entry.isEnabled ? #selector(plantSpecificSpecies(_:)) : nil,
            keyEquivalent: ""
        )
        speciesItem.target = entry.isEnabled ? self : nil
        speciesItem.representedObject = species.rawValue
        speciesItem.isEnabled = entry.isEnabled
        speciesItem.toolTip = entry.disabledReason ?? species.displayName
        if let image = NSImage(systemSymbolName: symbolName(for: species), accessibilityDescription: species.displayName) {
            image.isTemplate = true
            speciesItem.image = image
        }
        return speciesItem
    }

    private func refreshPlantingMenus() {
        for (kind, submenu) in plantCategorySubmenus {
            let randomAction: Selector = switch kind {
            case .flower:
                #selector(plantFlower)
            case .tree:
                #selector(plantTree)
            case .foliage:
                #selector(plantFoliage)
            case .meadow:
                #selector(plantMeadow)
            case .edible:
                #selector(plantEdible)
            }
            populatePlantCategorySubmenu(submenu, kind: kind, randomAction: randomAction)
        }
        for (kind, submenu) in alienPlantCategorySubmenus {
            populateAlienPlantCategorySubmenu(submenu, kind: kind)
        }
        if let roomIndoorPlantSubmenu {
            populateRoomIndoorPlantSubmenu(roomIndoorPlantSubmenu)
        }
    }

    private func refreshRoomStudioMenus() {
        for (category, submenu) in roomCategorySubmenus {
            populateRoomCategorySubmenu(submenu, category: category)
        }
    }

    private func symbolName(for species: PlantSpecies) -> String {
        switch species.kind {
        case .tree:
            "tree.fill"
        case .foliage:
            "leaf.fill"
        case .flower:
            species == .sunflower ? "sun.max.fill" : "camera.macro"
        case .meadow:
            "camera.macro.circle.fill"
        case .edible:
            "carrot.fill"
        }
    }

    private func updateDynamicItems() {
        let now = Date()
        let hidesLiveCareHeader = GardenStatusHeaderVisibility.hidesLiveCareHeader(
            isPaused: store.state.isPaused,
            experienceMode: store.state.settings.experienceMode
        )
        let insights = GardenGameLoopInsights(state: store.state, sceneKey: store.activeSceneKey, date: now)
        let vitality = store.state.vitality(at: now)
        let season = store.state.seasonCondition(at: now)
        let sunlight = store.state.sunlightCondition(at: now)
        let dew = store.state.dewCondition(at: now)
        let recommendation = store.state.careRecommendation
        let thirstyCount = store.state.thirstyPlants.count
        let needsCare = !store.state.plantsNeedingCare.isEmpty
        let careSummaryTitle = store.state.careSummary
        careSummaryItem.title = GardenMenuTitleFormatter.compactStatusTitle(careSummaryTitle)
        careSummaryItem.toolTip = careSummaryTitle
        careSummaryItem.image = NSImage(
            systemSymbolName: needsCare ? "exclamationmark.circle.fill" : "checkmark.circle.fill",
            accessibilityDescription: careSummaryTitle
        )
        let vitalityTitle = "Vitality \(vitality.percentScore)% - \(vitality.summary)"
        vitalityItem.title = GardenMenuTitleFormatter.compactStatusTitle(vitalityTitle)
        vitalityItem.toolTip = vitalityTitle
        vitalityItem.image = NSImage(
            systemSymbolName: symbolName(for: vitality.mood),
            accessibilityDescription: vitalityTitle
        )
        let environmentTitle = "Environment: \(season.summary), \(sunlight.summary), \(dew.summary)"
        environmentItem.title = GardenMenuTitleFormatter.compactStatusTitle(environmentTitle)
        environmentItem.toolTip = environmentTitle
        environmentItem.image = NSImage(
            systemSymbolName: symbolName(for: season.mood),
            accessibilityDescription: environmentTitle
        )
        let recommendationTitle = "Do Recommended Care: \(recommendation.summary)"
        recommendationItem.title = GardenMenuTitleFormatter.compactStatusTitle(recommendationTitle)
        recommendationItem.toolTip = recommendationTitle
        recommendationItem.isEnabled = recommendation.isActionable
        recommendationItem.image = NSImage(
            systemSymbolName: symbolName(for: recommendation.kind),
            accessibilityDescription: recommendationTitle
        )
        if let selectedPlant = store.selectedPlant {
            let microclimate = PlantMicroclimate(plant: selectedPlant, state: store.state, at: now)
            let circadianState = selectedPlant.circadianState(for: sunlight)
            let forecast = PlantGrowthForecast(
                plant: selectedPlant,
                microclimateGrowthFactor: microclimate.growthFactor,
                circadianGrowthFactor: circadianState.growthMultiplier
            )
            let waterForecast = PlantWaterForecast(
                plant: selectedPlant,
                ambientMoisture: store.state.ambientMoisture,
                microclimateWaterUseFactor: microclimate.waterUseFactor
            )
            let lifeStage = PlantLifeStage(species: selectedPlant.species, assetStage: forecast.stage)
            let phenology = selectedPlant.phenology(for: season)
            let companionEffect = selectedPlant.companionEffect(in: store.state)
            let bedAffinity = selectedPlant.bedAffinity
            let moisturePreference = selectedPlant.moisturePreference
            let nutrientProfile = selectedPlant.nutrientProfile(at: now)
            let groundIntegration = selectedPlant.groundIntegration
            let milestonePrefix = selectedPlant.growthMilestoneIntensity(at: now) > 0 ? "New phase: " : ""
            let fullSelectedDetails = "Selected: \(selectedPlant.nickname) - \(milestonePrefix)\(lifeStage.label) - \(circadianState.shortSummary) - \(phenology.summary) - \(moisturePreference.shortSummary) - \(nutrientProfile.shortSummary) - \(bedAffinity.shortSummary) - \(groundIntegration.shortSummary) - \(companionEffect.shortSummary) - \(forecast.shortSummary) - \(waterForecast.shortSummary) - \(microclimate.shortSummary) - \(microclimate.fitSummary) - \(selectedPlant.rootZone.summary)"
            selectedGrowthItem.title = GardenMenuTitleFormatter.compactStatusTitle(
                "Selected: \(selectedPlant.nickname) - \(lifeStage.label)",
                maxLength: GardenMenuTitleFormatter.selectedPlantTitleMaxLength
            )
            selectedGrowthItem.toolTip = fullSelectedDetails
            selectedGrowthItem.image = NSImage(
                systemSymbolName: "clock.badge.checkmark",
                accessibilityDescription: fullSelectedDetails
            )
            selectedGrowthItem.isHidden = false
        } else {
            selectedGrowthItem.title = ""
            selectedGrowthItem.toolTip = nil
            selectedGrowthItem.isHidden = true
        }
        careSummaryItem.isHidden = hidesLiveCareHeader
        vitalityItem.isHidden = hidesLiveCareHeader
        environmentItem.isHidden = hidesLiveCareHeader
        recommendationItem.isHidden = hidesLiveCareHeader
        if hidesLiveCareHeader {
            selectedGrowthItem.isHidden = true
        }
        liveStatusHeaderSeparator.isHidden = hidesLiveCareHeader
        assistantItem.state = assistantWindowController.window?.isVisible == true ? .on : .off
        assistantItem.toolTip = "Open the Jarvis-style AI command center over your current garden."
        waterThirstyItem.title = switch thirstyCount {
        case 0:
            "Water Thirsty Plants"
        case 1:
            "Water 1 Thirsty Plant"
        default:
            "Water \(thirstyCount) Thirsty Plants"
        }
        waterThirstyItem.isEnabled = thirstyCount > 0
        if let focusSession = store.state.focusSession, focusSession.isActive(at: now) {
            focusStatusItem.isHidden = false
            let focusTitle = insights.focus.statusSummary
            focusStatusItem.title = GardenMenuTitleFormatter.compactStatusTitle(focusTitle)
            focusStatusItem.image = NSImage(
                systemSymbolName: "timer",
                accessibilityDescription: focusTitle
            )
            focusActionItem.title = "End Focus Session Early"
            focusActionItem.submenu = nil
            focusActionItem.target = self
            focusActionItem.action = #selector(cancelFocusSession)
            focusActionItem.isEnabled = true
        } else {
            if let focusStats = store.state.focusStats, focusStats.completedSessions > 0 {
                focusStatusItem.isHidden = false
                let statsTitle = "Focus: \(focusStats.completedSessions) sessions, \(focusStats.totalFocusMinutes) min total - \(insights.focus.milestoneSummary)"
                focusStatusItem.title = GardenMenuTitleFormatter.compactStatusTitle(statsTitle)
                focusStatusItem.toolTip = statsTitle
                focusStatusItem.image = NSImage(
                    systemSymbolName: "checkmark.seal",
                    accessibilityDescription: statsTitle
                )
            } else {
                focusStatusItem.isHidden = true
                focusStatusItem.toolTip = nil
            }
            focusActionItem.title = "Start Focus Session"
            focusActionItem.target = nil
            focusActionItem.action = nil
            focusActionItem.isEnabled = true
            if focusActionItem.submenu == nil {
                focusActionItem.submenu = focusDurationSubmenu()
            }
        }
        let isLocked = store.state.settings.isGardenInteractionLocked
        lockInteractionItem.title = Self.lockInteractionTitle(for: store.state.settings.experienceMode)
        lockInteractionItem.state = isLocked ? .on : .off
        lockInteractionItem.toolTip = isLocked
            ? "\(Self.modeNoun(for: store.state.settings.experienceMode)) clicks are locked. Your desktop behaves like normal macOS; uncheck to edit."
            : "Ignore \(Self.modeNoun(for: store.state.settings.experienceMode).lowercased()) clicks while keeping the wallpaper visible."
        lockInteractionItem.image = NSImage(
            systemSymbolName: isLocked ? "lock.fill" : "lock.open.fill",
            accessibilityDescription: lockInteractionItem.title
        )
        let isAILockViewEnabled = store.state.settings.useAIGeneratedLockSnapshot
        aiLockViewItem.title = "AI Lock View"
        aiLockViewItem.state = isAILockViewEnabled ? .on : .off
        aiLockViewItem.toolTip = isAILockViewEnabled
            ? "When interactions are locked, generate and apply a hyper-realistic time-of-day wallpaper from a clean Garden Snapshot."
            : "Regular lock stays instant. Turn this on to generate an AI lock wallpaper when interactions are locked."
        aiLockViewItem.image = NSImage(
            systemSymbolName: isAILockViewEnabled ? "sparkles.rectangle.stack.fill" : "sparkles",
            accessibilityDescription: aiLockViewItem.title
        )
        pauseItem.title = store.state.isPaused ? "Growth Paused" : "Pause Growth"
        pauseItem.state = store.state.isPaused ? .on : .off
        pauseItem.toolTip = store.state.isPaused
            ? "Growth is paused across every scene. Click to resume it everywhere."
            : "Pause growth, thirst, health changes, and catch-up updates across every scene."
        pauseItem.image = NSImage(
            systemSymbolName: "pause.fill",
            accessibilityDescription: pauseItem.title
        )
        updateAmbientSoundItems()
        ambientWildlifeItem.title = store.state.settings.experienceMode == .alienUFO
            ? "Show Alien Bugs & Fireflies"
            : "Show Animated Bugs"
        ambientWildlifeItem.state = store.state.isEffectiveAmbientWildlifeEnabled ? .on : .off
        ambientWildlifeItem.image = NSImage(
            systemSymbolName: "ladybug.fill",
            accessibilityDescription: ambientWildlifeItem.title
        )
        gnomeZoneDrawingItem.title = isGnomeZoneDrawingMode
            ? "Done Drawing Gnome Areas"
            : "Draw Gnome Settlement Areas"
        gnomeZoneDrawingItem.state = isGnomeZoneDrawingMode ? .on : .off
        gnomeZoneDrawingItem.toolTip = isGnomeZoneDrawingMode
            ? "Click when every settlement area is outlined; the setup panel lets you pick the starter area."
            : "Outline one or more areas where gnomes can build daily-life settlements over time."
        gnomeZoneDrawingItem.image = NSImage(
            systemSymbolName: isGnomeZoneDrawingMode ? "paintbrush.pointed.fill" : "paintbrush.pointed",
            accessibilityDescription: gnomeZoneDrawingItem.title
        )
        let gnomePerspective = store.state.gnomeTribePerspective
        let perspectiveSummary = "\(Int(gnomePerspective.yawDegrees.rounded()))deg, \(Int(gnomePerspective.elevationDegrees.rounded()))deg"
        gnomePerspectiveAdjustmentItem.title = isGnomePerspectiveAdjustmentMode
            ? "Finish Gnome Perspective"
            : "Adjust Gnome Perspective (\(perspectiveSummary))"
        gnomePerspectiveAdjustmentItem.state = isGnomePerspectiveAdjustmentMode ? .on : .off
        gnomePerspectiveAdjustmentItem.isEnabled = !store.state.gnomeTribeZones.isEmpty
        gnomePerspectiveAdjustmentItem.toolTip = store.state.gnomeTribeZones.isEmpty
            ? "Draw a gnome tribe zone before adjusting its 3D viewing angle."
            : "Click, then drag horizontally to rotate the gnome view and vertically to change elevation."
        gnomePerspectiveAdjustmentItem.image = NSImage(
            systemSymbolName: isGnomePerspectiveAdjustmentMode ? "camera.viewfinder" : "view.3d",
            accessibilityDescription: gnomePerspectiveAdjustmentItem.title
        )
        hideGnomeTribesItem.title = store.state.areGnomeTribesHidden ? "Show Gnomes" : "Hide Gnomes"
        hideGnomeTribesItem.state = store.state.areGnomeTribesHidden ? .on : .off
        hideGnomeTribesItem.isEnabled = !store.state.gnomeTribeZones.isEmpty
        hideGnomeTribesItem.toolTip = store.state.gnomeTribeZones.isEmpty
            ? "Draw a gnome tribe zone before hiding or showing gnomes."
            : "Temporarily hide or show the gnome society in this scene."
        hideGnomeTribesItem.image = NSImage(
            systemSymbolName: store.state.areGnomeTribesHidden ? "eye.slash.fill" : "eye",
            accessibilityDescription: hideGnomeTribesItem.title
        )
        removeAllGnomeZonesItem.title = "Remove All Gnomes from Scene"
        removeAllGnomeZonesItem.isEnabled = !store.state.gnomeTribeZones.isEmpty
        removeAllGnomeZonesItem.toolTip = store.state.gnomeTribeZones.isEmpty
            ? "No gnome tribes exist in this scene yet."
            : "Remove every gnome tribe habitat zone from this scene."
        removeAllGnomeZonesItem.image = NSImage(
            systemSymbolName: "figure.2.and.child.holdinghands",
            accessibilityDescription: removeAllGnomeZonesItem.title
        )
        birdSkyZoneDrawingItem.title = isBirdSkyZoneDrawingMode
            ? "Done Drawing Bird Sky Areas"
            : "Draw Bird Sky Areas"
        birdSkyZoneDrawingItem.state = isBirdSkyZoneDrawingMode ? .on : .off
        birdSkyZoneDrawingItem.toolTip = isBirdSkyZoneDrawingMode
            ? "Click when every flight area is outlined; the highlighter will disappear and birds will keep flying there."
            : "Outline one or more sky areas where procedural bird flocks should fly."
        birdSkyZoneDrawingItem.image = NSImage(
            systemSymbolName: isBirdSkyZoneDrawingMode ? "bird.fill" : "bird",
            accessibilityDescription: birdSkyZoneDrawingItem.title
        )
        hideBirdFlocksItem.title = store.state.areBirdFlocksHidden ? "Show Birds" : "Hide Birds"
        hideBirdFlocksItem.state = store.state.areBirdFlocksHidden ? .on : .off
        hideBirdFlocksItem.isEnabled = !store.state.birdSkyZones.isEmpty
        hideBirdFlocksItem.toolTip = store.state.birdSkyZones.isEmpty
            ? "Draw a bird sky area before hiding or showing birds."
            : "Temporarily hide or show the birds flying in this scene."
        hideBirdFlocksItem.image = NSImage(
            systemSymbolName: store.state.areBirdFlocksHidden ? "eye.slash.fill" : "eye",
            accessibilityDescription: hideBirdFlocksItem.title
        )
        removeAllBirdSkyZonesItem.title = "Remove All Bird Sky Areas"
        removeAllBirdSkyZonesItem.isEnabled = !store.state.birdSkyZones.isEmpty
        removeAllBirdSkyZonesItem.toolTip = store.state.birdSkyZones.isEmpty
            ? "No bird sky areas exist in this scene yet."
            : "Remove every bird flight area from this scene."
        removeAllBirdSkyZonesItem.image = NSImage(
            systemSymbolName: "bird",
            accessibilityDescription: removeAllBirdSkyZonesItem.title
        )
        soilBrushItem.title = isSoilBrushMode
            ? "Done Placing Soil"
            : "Place Soil"
        soilBrushItem.state = isSoilBrushMode ? .on : .off
        soilBrushItem.toolTip = isSoilBrushMode
            ? "Click when you are done painting soil. Plants placed on a patch sink their base into the dirt."
            : "Click and drag on the desktop to paint a patch of fresh soil for planting."
        soilBrushItem.image = NSImage(
            systemSymbolName: isSoilBrushMode ? "drop.fill" : "drop",
            accessibilityDescription: soilBrushItem.title
        )
        removeAllSoilPatchesItem.title = "Remove All Soil Patches"
        removeAllSoilPatchesItem.isEnabled = !store.state.soilPatches.isEmpty
        removeAllSoilPatchesItem.toolTip = store.state.soilPatches.isEmpty
            ? "No soil patches exist in this scene yet."
            : "Remove every hand-painted soil patch from this scene."
        removeAllSoilPatchesItem.image = NSImage(
            systemSymbolName: "drop",
            accessibilityDescription: removeAllSoilPatchesItem.title
        )
        catCompanionItem.title = "Show Cat Companion"
        let isCatEnabled = UserDefaults.standard.object(
            forKey: CatCompanionController.enabledDefaultsKey
        ) as? Bool ?? true
        catCompanionItem.state = isCatEnabled ? .on : .off
        catCompanionItem.image = NSImage(
            systemSymbolName: "cat.fill",
            accessibilityDescription: catCompanionItem.title
        ) ?? NSImage(
            systemSymbolName: "pawprint.fill",
            accessibilityDescription: catCompanionItem.title
        )
        musicButtonItem.title = "Radio Companion"
        musicButtonItem.toolTip = "Add radio companions to the scene, then click one to play its station."
        radioCompanionToggleItem.title = store.state.musicButtons.isEmpty
            ? "Add Garden Cat"
            : "Hide All Radio Companions"
        radioCompanionToggleItem.state = store.state.musicButtons.isEmpty ? .off : .on
        radioCompanionToggleItem.image = NSImage(
            systemSymbolName: store.state.musicButtons.isEmpty ? "antenna.radiowaves.left.and.right" : "eye.slash.fill",
            accessibilityDescription: radioCompanionToggleItem.title
        )
        for item in radioCompanionChoiceItems {
            let rawValue = item.representedObject as? String
            item.state = store.state.musicButtons.contains { $0.companion.rawValue == rawValue } ? .on : .off
        }
        updatePlantingShortcut(plantFlowerItem, kind: .flower)
        updatePlantingShortcut(plantTreeItem, kind: .tree)
        updatePlantingShortcut(plantFoliageItem, kind: .foliage)
        updatePlantingShortcut(plantMeadowItem, kind: .meadow)
        updatePlantingShortcut(plantEdibleItem, kind: .edible)
        for sceneItem in wallpaperSceneItems {
            let rawValue = sceneItem.representedObject as? String
            sceneItem.state = rawValue == wallpaperManager.wallpaperSceneRootKey() ? .on : .off
        }
        sceneQuickSwitchLabel?.stringValue = GardenMenuTitleFormatter.compactStatusTitle(
            activeSceneName,
            maxLength: 32
        )
        sceneQuickSwitchLabel?.toolTip = "Current scene: \(activeSceneName)"
        let versionEntries = wallpaperManager.wallpaperVersions()
        let editedVersionCount = versionEntries.filter { !$0.isOriginal }.count
        generationStatusItem.isHidden = !isUpdatingWallpaper
        generationStatusItem.title = "Generating wallpaper... Cancel"
        generationStatusItem.toolTip = "The current wallpaper edit is running. Click to cancel the request."
        if let image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: generationStatusItem.title) {
            image.isTemplate = true
            generationStatusItem.image = image
        }
        updateWallpaperItem.title = isUpdatingWallpaper ? "Cancel Wallpaper Update" : "Update Current Wallpaper..."
        updateWallpaperItem.isEnabled = true
        updateWallpaperItem.action = isUpdatingWallpaper ? #selector(cancelWallpaperUpdate) : #selector(updateCurrentWallpaper)
        updateWallpaperItem.toolTip = isUpdatingWallpaper
            ? "Cancel the wallpaper generation request."
            : "Describe a change; the current wallpaper image will be sent as the reference."
        if let image = NSImage(
            systemSymbolName: isUpdatingWallpaper ? "xmark.circle.fill" : "wand.and.stars",
            accessibilityDescription: updateWallpaperItem.title
        ) {
            image.isTemplate = true
            updateWallpaperItem.image = image
        }
        updateProgressionMenuItems()
        wallpaperVersionsItem.title = editedVersionCount > 0
            ? "Wallpaper Versions (\(editedVersionCount))"
            : "Wallpaper Versions"
        wallpaperVersionsItem.toolTip = editedVersionCount > 0
            ? "Return to an earlier AI-edited wallpaper or the original scene."
            : "Edited wallpaper versions will appear here."
        for versionItem in wallpaperVersionItems {
            let rawValue = versionItem.representedObject as? String
            versionItem.state = rawValue == wallpaperManager.selectedWallpaperSceneKey ? .on : .off
        }
        statusItem.button?.toolTip = "Plant Wallpaper - \(vitality.summary) - \(season.summary) - \(sunlight.summary) - \(dew.summary) - \(recommendation.summary)"
        if let lastError = store.lastError {
            let errorTitle = "Save Error: \(lastError)"
            errorItem.title = GardenMenuTitleFormatter.compactStatusTitle(errorTitle)
            errorItem.toolTip = errorTitle
            errorItem.isHidden = false
        } else {
            errorItem.title = ""
            errorItem.toolTip = nil
            errorItem.isHidden = true
        }
        inputMonitoringItem.isHidden = !GardenDesktopEventTapStatus.isUnavailable
        inputMonitoringItem.toolTip = "macOS blocked the desktop mouse tap, so clicking plants may not work everywhere. Grant Plant Wallpaper access under Privacy & Security > Input Monitoring."
        applyStatusMenuTooltipPolicy()
    }

    private func updateAmbientSoundItems() {
        let settings = store.state.settings
        ambientSoundMenuItem.title = "Environmental Sounds"
        ambientSoundMenuItem.state = settings.isAmbientSoundEnabled ? .on : .off
        ambientSoundMenuItem.image = NSImage(
            systemSymbolName: settings.isAmbientSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
            accessibilityDescription: ambientSoundMenuItem.title
        )

        ambientSoundMasterItem.title = settings.isAmbientSoundEnabled
            ? "Pause Environmental Sounds"
            : "Play Environmental Sounds"
        ambientSoundMasterItem.state = settings.isAmbientSoundEnabled ? .on : .off
        ambientSoundMasterItem.image = NSImage(
            systemSymbolName: settings.isAmbientSoundEnabled ? "pause.fill" : "play.fill",
            accessibilityDescription: ambientSoundMasterItem.title
        )

        for (layer, item) in ambientSoundLayerItems {
            switch layer {
            case .master:
                item.state = settings.isAmbientSoundEnabled ? .on : .off
            case .birdsong:
                item.state = settings.isBirdsongEnabled ? .on : .off
            case .crickets:
                item.state = settings.isCricketSoundEnabled ? .on : .off
            case .wind:
                item.state = settings.isWindSoundEnabled ? .on : .off
            case .rain:
                item.state = settings.isRainSoundEnabled ? .on : .off
            case .water:
                item.state = settings.isWaterSoundEnabled ? .on : .off
            case .urbanMurmur:
                item.state = settings.isUrbanMurmurSoundEnabled ? .on : .off
            case .roomTone:
                item.state = settings.isRoomToneSoundEnabled ? .on : .off
            case .cicadas:
                item.state = settings.isCicadaSoundEnabled ? .on : .off
            case .chimes:
                item.state = settings.isChimeSoundEnabled ? .on : .off
            case .smallWildlife:
                item.state = settings.isSmallWildlifeSoundEnabled ? .on : .off
            case .roomLife:
                item.state = settings.isRoomLifeSoundEnabled ? .on : .off
            case .electronics:
                item.state = settings.isElectronicsSoundEnabled ? .on : .off
            case .alienFauna:
                item.state = settings.isAlienFaunaSoundEnabled ? .on : .off
            case .habitatHum:
                item.state = settings.isHabitatHumSoundEnabled ? .on : .off
            case .crystallineShimmer:
                item.state = settings.isCrystallineShimmerSoundEnabled ? .on : .off
            case .lowRumble:
                item.state = settings.isLowRumbleSoundEnabled ? .on : .off
            }
        }
    }

    private func updateProgressionMenuItems() {
        let mode = store.state.settings.experienceMode
        let maxLevel = GardenSceneProgression.maximumLevel
        if let progression = store.state.progression {
            let isActive = progression.isEnabled
            let levelTitle = GardenSceneProgression.title(for: progression.level, experienceMode: mode)
            let atMaxLevel = progression.level >= maxLevel

            progressionToggleItem.title = isActive ? "Progression Mode: On" : "Progression Mode: Off"
            progressionToggleItem.state = isActive ? .on : .off

            let statusPrefix = isActive ? "" : "Paused — "
            progressionStatusItem.title = "\(statusPrefix)Level \(progression.level)/\(maxLevel): \(levelTitle)"
            progressionStatusItem.toolTip = [
                progression.profile.lifestyleFantasy,
                progression.profile.placeInWorld,
                progression.profile.vibe
            ]
            .filter { !$0.isEmpty }
            .joined(separator: " | ")
            progressionSetupItem.title = "Edit Fantasy Profile..."
            let nextLevel = progression.nextLevel
            progressionAdvanceItem.title = atMaxLevel
                ? "Max Level Reached"
                : "Generate Level \(nextLevel)..."
            // canAdvance already encodes the paused state, so a paused ladder
            // greys out generation while the toggle above offers resume.
            progressionAdvanceItem.isEnabled = progression.canAdvance && !isUpdatingWallpaper
            progressionRegenerateItem.title = progression.level > 0
                ? "Regenerate Level \(progression.level)..."
                : "Regenerate This Level..."
            progressionRegenerateItem.isEnabled = progression.level > 0 && !isUpdatingWallpaper
            progressionResetItem.isEnabled = true

            updateProgressionAutoAdvanceItems(cadence: progression.autoAdvanceCadence)

            progressionModeParentItem?.title = isActive
                ? "Progression Mode — Level \(progression.level)/\(maxLevel)"
                : "Progression Mode — Paused (Lv \(progression.level))"
        } else {
            progressionToggleItem.title = "Progression Mode: Off"
            progressionToggleItem.state = .off
            progressionStatusItem.title = "No progression profile"
            progressionStatusItem.toolTip = "Set a fantasy direction before generating level upgrades."
            progressionSetupItem.title = "Setup Fantasy Profile..."
            progressionAdvanceItem.title = "Setup to Generate Level 1..."
            progressionAdvanceItem.isEnabled = !isUpdatingWallpaper
            progressionRegenerateItem.title = "Regenerate This Level..."
            progressionRegenerateItem.isEnabled = false
            progressionResetItem.isEnabled = false
            updateProgressionAutoAdvanceItems(cadence: .off)
            progressionModeParentItem?.title = "Progression Mode"
        }
    }

    private func updateProgressionAutoAdvanceItems(cadence: GardenSceneProgression.AutoAdvanceCadence) {
        for item in progressionAutoAdvanceChoiceItems {
            guard let rawValue = item.representedObject as? String else {
                continue
            }
            item.state = rawValue == cadence.rawValue ? .on : .off
            item.isEnabled = store.state.progression != nil
        }
        progressionAutoAdvanceItem.isEnabled = store.state.progression != nil
        progressionAutoAdvanceItem.title = cadence == .off
            ? "Auto-Advance: Off"
            : "Auto-Advance: \(cadence.displayName)"
    }

    @objc private func openInputMonitoringSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func updatePlantingShortcut(_ item: NSMenuItem, kind: PlantKind) {
        let enabledSpecies = GardenPlantSpecificMenuCatalog.enabledSpecies(
            sceneKey: store.activeSceneKey,
            in: kind
        )
        let environment = GardenScenePlantEnvironment(sceneKey: store.activeSceneKey)
        item.isEnabled = !enabledSpecies.isEmpty
        let style = Self.plantMenuStyle(for: kind)
        let color = item.isEnabled ? style.accent : NSColor.disabledControlTextColor
        item.attributedTitle = Self.plantMenuTitle(item.title, color: color)
        item.image = Self.tintedSymbol(
            style.symbolName,
            color: color,
            accessibilityDescription: item.title
        )
        item.toolTip = enabledSpecies.isEmpty
            ? "No asset-ready \(kind.displayName.lowercased()) plants fit the \(environment.displayName)"
            : "Plant a \(kind.displayName.lowercased()) suited to the \(environment.displayName)"
    }

    private static func plantMenuStyle(for kind: PlantKind) -> PlantKindMenuStyle {
        switch kind {
        case .flower:
            PlantKindMenuStyle(
                accent: NSColor(calibratedRed: 0.92, green: 0.22, blue: 0.46, alpha: 1),
                symbolName: "camera.macro"
            )
        case .tree:
            PlantKindMenuStyle(
                accent: NSColor(calibratedRed: 0.24, green: 0.50, blue: 0.24, alpha: 1),
                symbolName: "tree.fill"
            )
        case .foliage:
            PlantKindMenuStyle(
                accent: NSColor(calibratedRed: 0.16, green: 0.55, blue: 0.42, alpha: 1),
                symbolName: "leaf.fill"
            )
        case .meadow:
            PlantKindMenuStyle(
                accent: NSColor(calibratedRed: 0.55, green: 0.46, blue: 0.19, alpha: 1),
                symbolName: "leaf.circle.fill"
            )
        case .edible:
            PlantKindMenuStyle(
                accent: NSColor(calibratedRed: 0.86, green: 0.38, blue: 0.12, alpha: 1),
                symbolName: "carrot.fill"
            )
        }
    }

    private static func plantMenuTitle(_ title: String, style: PlantKindMenuStyle) -> NSAttributedString {
        plantMenuTitle(title, color: style.accent)
    }

    private static func plantMenuTitle(_ title: String, color: NSColor) -> NSAttributedString {
        NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: color,
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
            ]
        )
    }

    private static func tintedSymbol(
        _ symbolName: String,
        color: NSColor,
        accessibilityDescription: String
    ) -> NSImage? {
        guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)?
            .withSymbolConfiguration(.init(pointSize: 15, weight: .semibold)) else {
            return nil
        }

        image.isTemplate = false
        let size = image.size
        guard size.width > 0, size.height > 0 else {
            return image
        }

        let tinted = NSImage(size: size)
        tinted.lockFocus()
        color.set()
        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: size),
            operation: .sourceIn,
            fraction: 1
        )
        tinted.unlockFocus()
        tinted.isTemplate = false
        return tinted
    }

    private func symbolName(for mood: GardenVitalityMood) -> String {
        switch mood {
        case .flourishing:
            "leaf.circle.fill"
        case .steady:
            "checkmark.circle.fill"
        case .thirsty:
            "drop.triangle.fill"
        case .recovering:
            "bandage.fill"
        case .dead:
            "xmark.circle.fill"
        case .dormant:
            "plus.circle"
        }
    }

    private func symbolName(for recommendation: GardenCareRecommendationKind) -> String {
        switch recommendation {
        case .plantFirst:
            "plus.circle.fill"
        case .removeDead:
            "trash"
        case .waterThirsty:
            "drop.triangle.fill"
        case .prune:
            "scissors"
        case .nourish:
            "sparkles"
        case .enjoy:
            "checkmark.circle.fill"
        }
    }

    private func symbolName(for dew: GardenDewMood) -> String {
        switch dew {
        case .none:
            "sun.max"
        case .morningDew:
            "sparkles"
        case .freshlyWatered:
            "drop.fill"
        }
    }

    private func symbolName(for sunlight: GardenSunlightMood) -> String {
        switch sunlight {
        case .morning:
            "sunrise.fill"
        case .bright:
            "sun.max.fill"
        case .golden:
            "sun.horizon.fill"
        case .night:
            "moon.stars.fill"
        }
    }

    private func symbolName(for season: GardenSeasonMood) -> String {
        switch season {
        case .spring:
            "camera.macro"
        case .summer:
            "tree.fill"
        case .autumn:
            "leaf.fill"
        case .winter:
            "snowflake"
        }
    }

    private func storeDidChange() {
        // The status icon is always visible, so it tracks state cheaply on
        // every change (focus running, plants thirsty, all steady).
        refreshStatusIcon()
        if lastRenderedExperienceMode != store.state.settings.experienceMode
            || lastRenderedAssistantMenuItemEnabled != store.state.settings.isAssistantMenuItemEnabled {
            buildMenu()
            return
        }

        // Rebuilding ~15 menu item titles, tooltips, and SF Symbol images on
        // every store change is wasted main-thread work while the menu is
        // closed (and during drags it fires per mouse event). menuWillOpen
        // refreshes everything just before the menu becomes visible.
        guard isMenuVisible else {
            return
        }

        updateDynamicItems()
    }

    /// Swaps the menu bar icon to reflect the garden at a glance:
    /// timer while focusing, a water drop when plants are thirsty.
    private func refreshStatusIcon() {
        let symbolName: String
        if store.state.focusSession?.isActive() == true {
            symbolName = "timer"
        } else if !store.state.thirstyPlants.isEmpty {
            symbolName = "drop.triangle.fill"
        } else {
            symbolName = "leaf.fill"
        }

        guard symbolName != currentStatusSymbolName else {
            return
        }

        currentStatusSymbolName = symbolName
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Plant Wallpaper") {
            image.isTemplate = true
            statusItem.button?.image = image
        }
    }

    private func focusDurationSubmenu() -> NSMenu {
        let submenu = NSMenu(title: "Start Focus Session")
        submenu.autoenablesItems = false
        for minutes in [25, 50] {
            let item = NSMenuItem(
                title: "\(minutes) Minutes",
                action: #selector(startFocusSession(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.isEnabled = true
            item.representedObject = minutes
            if let image = NSImage(systemSymbolName: "timer", accessibilityDescription: item.title) {
                image.isTemplate = true
                item.image = image
            }
            submenu.addItem(item)
        }
        return submenu
    }

    @objc private func noOpFocusPlaceholder() {
    }

    @objc private func toggleJarvisAssistant() {
        guard requireProFeature(.jarvisAssistant) else {
            return
        }
        assistantWindowController.toggle()
        updateDynamicItems()
    }

    @objc private func startFocusSession(_ sender: NSMenuItem) {
        guard requireProFeature(.focusSessions) else {
            return
        }
        guard let minutes = sender.representedObject as? Int else {
            return
        }

        store.startFocusSession(duration: TimeInterval(minutes * 60))
    }

    @objc private func cancelFocusSession() {
        store.cancelFocusSession()
    }

    @objc private func saveGardenSnapshot() {
        let panel = NSSavePanel()
        panel.title = "Save Garden Snapshot"
        panel.nameFieldStringValue = "Plant Wallpaper Garden.png"
        panel.allowedContentTypes = [.png]
        NSApplication.shared.activate(ignoringOtherApps: true)

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let writtenURLs = try GardenDesktopSnapshotRenderer.writeSnapshotPNGs(store: store, to: url)
            NSWorkspace.shared.activateFileViewerSelecting(writtenURLs)
        } catch {
            showError(title: "Could not save snapshot", message: error.localizedDescription)
        }
    }

    @objc private func saveShareCard() {
        let panel = NSSavePanel()
        panel.title = "Save Share Card"
        panel.nameFieldStringValue = "My Plant Wallpaper Garden.png"
        panel.allowedContentTypes = [.png]
        NSApplication.shared.activate(ignoringOtherApps: true)

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try GardenShareCardRenderer.writeCardPNG(
                state: store.state,
                sceneKey: store.activeSceneKey,
                to: url
            )
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            showError(title: "Could not save share card", message: error.localizedDescription)
        }
    }

    @objc private func exportTimeLapse() {
        guard requireProFeature(.timeLapseExport) else {
            return
        }
        GardenTimeLapseExporter.shared.exportInteractively(store: store)
    }

    @objc private func waterAll() {
        store.waterAll()
    }

    @objc private func waterThirstyPlants() {
        store.waterThirstyPlants()
    }

    @objc private func performRecommendedCare() {
        let targetScreenIndex = lastDesktopPlantingTarget?.screenIndex ?? 0
        store.performRecommendedCare(screenIndex: targetScreenIndex)
    }

    @objc private func plantFlower() {
        plantRandomSpecies(in: .flower)
    }

    @objc private func plantTree() {
        plantRandomSpecies(in: .tree)
    }

    @objc private func plantFoliage() {
        plantRandomSpecies(in: .foliage)
    }

    @objc private func plantMeadow() {
        plantRandomSpecies(in: .meadow)
    }

    @objc private func plantEdible() {
        plantRandomSpecies(in: .edible)
    }

    @objc private func plantRandomIndoorPlant() {
        guard let species = GardenPlantSpecificMenuCatalog.enabledRoomStudioIndoorSpecies(
            sceneKey: store.activeSceneKey
        ).randomElement() else {
            return
        }

        plant(species)
    }

    private func seedPouchMenu() -> NSMenuItem {
        seedPouchItem.title = "Plant from Seeds..."
        if let image = NSImage(systemSymbolName: "circle.hexagongrid.fill", accessibilityDescription: seedPouchItem.title) {
            image.isTemplate = true
            seedPouchItem.image = image
        }

        let submenu = NSMenu(title: seedPouchItem.title)
        submenu.autoenablesItems = false
        seedPouchSubmenu = submenu
        seedPouchItem.submenu = submenu
        refreshSeedPouchMenu()
        return seedPouchItem
    }

    private func refreshSeedPouchMenu() {
        guard let submenu = seedPouchSubmenu else {
            return
        }

        submenu.removeAllItems()
        let insights = GardenGameLoopInsights(state: store.state, sceneKey: store.activeSceneKey)
        let inventory = GardenGameLoopInsights.seedInventoryEntries(in: store.state)

        seedPouchItem.isHidden = inventory.isEmpty
        seedPouchItem.title = inventory.isEmpty
            ? "Plant from Seeds..."
            : "Plant from Seeds... (\(insights.seeds.totalSeeds))"
        seedPouchItem.toolTip = insights.seeds.summary
        guard !inventory.isEmpty else {
            return
        }

        if let suggestion = insights.seeds.suggestion {
            let recommended = NSMenuItem(
                title: "Recommended: \(suggestion.species.displayName) - \(suggestion.reason)",
                action: #selector(plantFromSeed(_:)),
                keyEquivalent: ""
            )
            recommended.target = self
            recommended.representedObject = suggestion.species.rawValue
            recommended.toolTip = insights.seeds.summary
            if let image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: recommended.title) {
                image.isTemplate = true
                recommended.image = image
            }
            submenu.addItem(recommended)
            submenu.addItem(NSMenuItem.separator())
        }

        let environment = GardenScenePlantEnvironment(sceneKey: store.activeSceneKey)
        for entry in inventory {
            let species = entry.species
            let count = entry.count
            let item = NSMenuItem(
                title: "\(species.displayName)  (\(count) seed\(count == 1 ? "" : "s"))",
                action: #selector(plantFromSeed(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = species.rawValue
            item.isEnabled = environment.isSuitable(species)
            item.toolTip = item.isEnabled
                ? "\(species.displayName) fits the \(environment.displayName)."
                : "\(species.displayName) does not fit the \(environment.displayName)."
            if let image = NSImage(systemSymbolName: symbolName(for: species), accessibilityDescription: species.displayName) {
                image.isTemplate = true
                item.image = image
            }
            submenu.addItem(item)
        }
    }

    @objc private func plantFromSeed(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let species = PlantSpecies(rawValue: rawValue) else {
            return
        }

        let target = lastDesktopPlantingTarget ?? Self.plantingTarget(at: NSEvent.mouseLocation)
        store.plantSeed(
            species: species,
            screenIndex: target?.screenIndex ?? 0,
            position: target?.position
        )
    }

    @objc private func harvestReadyCrops() {
        store.harvestAllReadyCrops()
    }

    @objc private func plantSpecificSpecies(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let species = PlantSpecies(rawValue: rawValue) else {
            return
        }

        plant(species)
    }

    @objc private func plantSavedCustomAsset(_ sender: NSMenuItem) {
        guard let customAssetID = sender.representedObject as? String,
              let record = store.customPlantAssets.record(id: customAssetID),
              store.customPlantAssets.hasDisplayableAsset(forCustomAssetID: customAssetID) else {
            return
        }

        plantCustomAsset(record)
    }

    private func plantCustomAsset(_ record: CustomPlantAssetRecord) {
        if let target = lastDesktopPlantingTarget ?? Self.plantingTarget(at: NSEvent.mouseLocation) {
            store.addCustomPlant(record, screenIndex: target.screenIndex, position: target.position)
        } else {
            store.addCustomPlant(record, screenIndex: 0)
        }
    }

    private func plantRandomSpecies(in kind: PlantKind) {
        guard let species = GardenPlantSpecificMenuCatalog.enabledSpecies(
            sceneKey: store.activeSceneKey,
            in: kind
        ).randomElement() else {
            return
        }

        plant(species)
    }

    @objc private func plantAlienSpecimen(_ sender: NSMenuItem) {
        guard let customAssetID = sender.representedObject as? String,
              let specimen = AlienPlantMenuCatalog.specimen(forCustomAssetID: customAssetID) else {
            return
        }

        plantBundledAlienSpecimen(specimen)
    }

    @objc private func plantRandomAlienSpecimen(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let kind = PlantKind(rawValue: rawValue),
              let specimen = AlienPlantAssetLibrary.shared.enabledSpecimens(in: kind).randomElement() else {
            return
        }

        plantBundledAlienSpecimen(specimen)
    }

    private func plantBundledAlienSpecimen(_ specimen: AlienPlantMenuSpecimen) {
        guard let record = AlienPlantAssetLibrary.shared.record(for: specimen) else {
            return
        }

        plantCustomAsset(record)
    }

    @objc private func createCustomPlantAsset(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let kind = PlantKind(rawValue: rawValue),
              let request = customPlantAssetRequest(kind: kind) else {
            return
        }

        guard let apiKey = OpenAIAPIKeyStore.load() else {
            showError(
                title: "OpenAI API key needed",
                message: "Add your OpenAI API key in settings, then create the new plant asset again."
            )
            openAIAPIKeySettings()
            return
        }

        let target = lastDesktopPlantingTarget ?? Self.plantingTarget(at: NSEvent.mouseLocation)
        let pendingID = store.beginPendingCustomPlantAsset(
            displayName: request.displayName,
            kind: request.kind,
            screenIndex: target?.screenIndex ?? 0,
            position: target?.position ?? GardenPoint(x: 0.5, y: 0.72)
        )
        Task { @MainActor in
            do {
                let record = try await store.customPlantAssets.createAsset(request: request, apiKey: apiKey)
                promptHistoryStore.record(feature: .customPlant, title: record.displayName, prompt: request.userDescription)
                let finalPending = store.pendingCustomPlantAsset(id: pendingID)
                store.finishPendingCustomPlantAsset(id: pendingID)
                store.addCustomPlant(
                    record,
                    screenIndex: finalPending?.screenIndex ?? target?.screenIndex ?? 0,
                    position: finalPending?.position ?? target?.position
                )
                refreshPlantingMenus()
            } catch {
                store.finishPendingCustomPlantAsset(id: pendingID)
                showError(title: "Custom plant failed", message: error.localizedDescription)
            }
        }
    }

    @objc private func selectExperienceMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = GardenExperienceMode(rawValue: rawValue) else {
            return
        }
        switchExperienceMode(to: mode)
    }

    private func switchExperienceMode(to mode: GardenExperienceMode, bypassingPaywall: Bool = false) {
        guard store.state.settings.experienceMode != mode else {
            return
        }
        if !bypassingPaywall,
           let feature = Self.proFeature(for: mode),
           !requireProFeature(feature) {
            return
        }

        if mode != .garden {
            if isGnomeZoneDrawingMode {
                cancelGnomeZoneDrawingMode()
            }
            if isBirdSkyZoneDrawingMode {
                cancelBirdSkyZoneDrawingMode()
            }
            if isSoilBrushMode {
                cancelSoilBrushMode()
            }
            if isGnomePerspectiveAdjustmentMode {
                setGnomePerspectiveAdjustmentMode(false)
            }
        }

        let currentSceneKey = store.activeSceneKey ?? wallpaperManager.wallpaperSceneRootKey()
        let nextSettings = store.state.settings.updating(experienceMode: mode)
        if let handoffKey = GardenExperienceModeScenePolicy.sceneHandoffKey(
            currentSceneKey: currentSceneKey,
            targetMode: mode
        ) {
            applyWallpaperSceneKey(handoffKey, settingsOverride: nextSettings)
        } else {
            store.updateSettings(nextSettings)
        }
        buildMenu()
    }

    @objc private func createCustomRoomObjectAsset(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let category = RoomObjectCategory(rawValue: rawValue),
              let request = customRoomObjectAssetRequest(category: category) else {
            return
        }

        createRoomObjectAsset(request)
    }

    @objc private func createTemplateRoomObjectAsset(_ sender: NSMenuItem) {
        guard let title = sender.representedObject as? String,
              let template = RoomStudioMenuCatalog.templates.first(where: { $0.title == title }) else {
            return
        }

        let target = lastDesktopPlantingTarget ?? Self.plantingTarget(at: NSEvent.mouseLocation)
        let context = RoomObjectPerspectiveContext.inferred(from: target?.position)
        let request = CustomPlantAssetRequest(
            kind: template.category.fallbackPlantKind,
            displayName: template.title,
            userDescription: template.promptSeed,
            roomObjectCategory: template.category,
            roomPerspectiveContext: context
        )
        createRoomObjectAsset(request)
    }

    private func createRoomObjectAsset(_ request: CustomPlantAssetRequest) {
        let target = lastDesktopPlantingTarget ?? Self.plantingTarget(at: NSEvent.mouseLocation)
        if let reusableRecord = store.customPlantAssets.reusableRoomObjectAsset(for: request) {
            store.addCustomPlant(
                reusableRecord,
                screenIndex: target?.screenIndex ?? 0,
                position: target?.position
            )
            refreshRoomStudioMenus()
            return
        }

        guard let apiKey = OpenAIAPIKeyStore.load() else {
            showError(
                title: "OpenAI API key needed",
                message: "Add your OpenAI API key in settings, then create the new room object again."
            )
            openAIAPIKeySettings()
            return
        }

        let pendingID = store.beginPendingCustomPlantAsset(
            displayName: request.displayName,
            kind: request.kind,
            screenIndex: target?.screenIndex ?? 0,
            position: target?.position ?? GardenPoint(x: 0.5, y: 0.72)
        )
        Task { @MainActor in
            do {
                let record = try await store.customPlantAssets.createAsset(request: request, apiKey: apiKey)
                promptHistoryStore.record(feature: .customPlant, title: record.displayName, prompt: request.userDescription)
                let finalPending = store.pendingCustomPlantAsset(id: pendingID)
                store.finishPendingCustomPlantAsset(id: pendingID)
                store.addCustomPlant(
                    record,
                    screenIndex: finalPending?.screenIndex ?? target?.screenIndex ?? 0,
                    position: finalPending?.position ?? target?.position
                )
                refreshRoomStudioMenus()
            } catch {
                store.finishPendingCustomPlantAsset(id: pendingID)
                showError(title: "Room object failed", message: error.localizedDescription)
            }
        }
    }

    private func plant(_ species: PlantSpecies) {
        guard PlantAssetLibrary.shared.hasDisplayableAsset(for: species) else {
            return
        }
        guard GardenScenePlantEnvironment(sceneKey: store.activeSceneKey).isSuitable(species) else {
            return
        }

        if let target = lastDesktopPlantingTarget ?? Self.plantingTarget(at: NSEvent.mouseLocation) {
            store.addPlant(species: species, screenIndex: target.screenIndex, position: target.position)
        } else {
            store.addPlant(species: species, screenIndex: 0)
        }
    }

    private func installDesktopMouseTracking() {
        updateDesktopPlantingTarget(at: NSEvent.mouseLocation)
        // Global mouse-moved monitors fire for every pixel of motion. Throttle
        // sampling: the planting target only needs coarse recency, not
        // per-event precision. AppKit delivers the handler through its event
        // machinery, which is not necessarily a Swift main-actor executor.
        mouseTrackingMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        ) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                let now = ContinuousClock.now
                guard now - self.lastMouseSampleTime > .milliseconds(80) else {
                    return
                }

                self.lastMouseSampleTime = now
                self.updateDesktopPlantingTarget(at: NSEvent.mouseLocation)
            }
        }
    }

    private func updateDesktopPlantingTarget(at screenPoint: NSPoint) {
        guard let target = Self.plantingTarget(at: screenPoint) else {
            return
        }

        lastDesktopPlantingTarget = target
    }

    private static func plantingTarget(at screenPoint: NSPoint) -> PlantingTarget? {
        for (screenIndex, screen) in NSScreen.screens.enumerated() where screen.frame.contains(screenPoint) {
            guard screenPoint.y < screen.frame.maxY - 44 else {
                return nil
            }

            let normalizedX = Double((screenPoint.x - screen.frame.minX) / max(1, screen.frame.width))
            let normalizedY = Double((screen.frame.maxY - screenPoint.y) / max(1, screen.frame.height))
            return PlantingTarget(
                screenIndex: screenIndex,
                position: GardenPoint(x: normalizedX, y: normalizedY).clamped
            )
        }

        return nil
    }

    @objc private func togglePaused() {
        store.togglePaused()
    }

    @objc private func toggleAmbientWildlife() {
        store.toggleAmbientWildlifeForCurrentMode()
    }

    @objc private func toggleGnomeZoneDrawingMode() {
        guard requireProFeature(.gnomeSocieties) else {
            return
        }
        if isGnomeZoneDrawingMode {
            finishGnomeZoneDrawingMode(startingZoneID: gnomeSettlementSetupPanelController?.selectedStartingZoneID)
            return
        }

        if isGnomePerspectiveAdjustmentMode {
            setGnomePerspectiveAdjustmentMode(false)
        }
        if isBirdSkyZoneDrawingMode {
            cancelBirdSkyZoneDrawingMode()
        }
        if isSoilBrushMode {
            cancelSoilBrushMode()
        }

        isGnomeZoneDrawingMode = true
        NotificationCenter.default.post(
            name: .gardenGnomeZoneDrawingModeDidChange,
            object: self,
            userInfo: ["isEnabled": true]
        )
        showGnomeSettlementSetupPanel()
        updateDynamicItems()
    }

    @objc private func toggleGnomePerspectiveAdjustmentMode() {
        guard requireProFeature(.gnomeSocieties) else {
            return
        }
        guard !store.state.gnomeTribeZones.isEmpty || isGnomePerspectiveAdjustmentMode else {
            return
        }

        let nextValue = !isGnomePerspectiveAdjustmentMode
        if nextValue, isGnomeZoneDrawingMode {
            cancelGnomeZoneDrawingMode()
        }
        if nextValue, isBirdSkyZoneDrawingMode {
            cancelBirdSkyZoneDrawingMode()
        }
        if nextValue, isSoilBrushMode {
            cancelSoilBrushMode()
        }
        setGnomePerspectiveAdjustmentMode(nextValue)
        updateDynamicItems()
    }

    @objc private func toggleGnomeTribesHidden() {
        store.toggleGnomeTribesHidden()
        updateDynamicItems()
    }

    @objc private func removeAllGnomesFromScene() {
        if isGnomeZoneDrawingMode {
            cancelGnomeZoneDrawingMode()
        }
        if isGnomePerspectiveAdjustmentMode {
            setGnomePerspectiveAdjustmentMode(false)
        }
        store.clearGnomeTribeZones()
        updateDynamicItems()
    }

    @objc private func toggleBirdSkyZoneDrawingMode() {
        guard requireProFeature(.birdSkyZones) else {
            return
        }
        if isBirdSkyZoneDrawingMode {
            finishBirdSkyZoneDrawingMode()
            return
        }

        if isGnomeZoneDrawingMode {
            cancelGnomeZoneDrawingMode()
        }
        if isGnomePerspectiveAdjustmentMode {
            setGnomePerspectiveAdjustmentMode(false)
        }
        if isSoilBrushMode {
            cancelSoilBrushMode()
        }

        isBirdSkyZoneDrawingMode = true
        NotificationCenter.default.post(
            name: .gardenBirdSkyZoneDrawingModeDidChange,
            object: self,
            userInfo: ["isEnabled": true]
        )
        updateDynamicItems()
    }

    @objc private func toggleBirdFlocksHidden() {
        store.toggleBirdFlocksHidden()
        updateDynamicItems()
    }

    @objc private func removeAllBirdSkyZonesFromScene() {
        if isBirdSkyZoneDrawingMode {
            cancelBirdSkyZoneDrawingMode()
        }
        store.clearBirdSkyZones()
        updateDynamicItems()
    }

    @objc private func toggleSoilBrushMode() {
        if isSoilBrushMode {
            cancelSoilBrushMode()
            return
        }

        if isGnomeZoneDrawingMode {
            cancelGnomeZoneDrawingMode()
        }
        if isBirdSkyZoneDrawingMode {
            cancelBirdSkyZoneDrawingMode()
        }
        if isGnomePerspectiveAdjustmentMode {
            setGnomePerspectiveAdjustmentMode(false)
        }

        isSoilBrushMode = true
        NotificationCenter.default.post(
            name: .gardenSoilBrushModeDidChange,
            object: self,
            userInfo: ["isEnabled": true]
        )
        updateDynamicItems()
    }

    @objc private func removeAllSoilPatchesFromScene() {
        if isSoilBrushMode {
            cancelSoilBrushMode()
        }
        store.clearAllSoilPatches()
        updateDynamicItems()
    }

    private func cancelSoilBrushMode() {
        guard isSoilBrushMode else {
            return
        }

        isSoilBrushMode = false
        NotificationCenter.default.post(
            name: .gardenSoilBrushModeDidChange,
            object: self,
            userInfo: ["isEnabled": false]
        )
        updateDynamicItems()
    }

    private func showGnomeSettlementSetupPanel() {
        if let existing = gnomeSettlementSetupPanelController {
            existing.showNearStatusItem()
            return
        }

        let controller = GnomeSettlementSetupPanelController(
            store: store,
            onDone: { [weak self] startingZoneID in
                self?.finishGnomeZoneDrawingMode(startingZoneID: startingZoneID)
            },
            onCancel: { [weak self] in
                self?.cancelGnomeZoneDrawingMode()
            }
        )
        gnomeSettlementSetupPanelController = controller
        controller.showNearStatusItem()
    }

    private func finishGnomeZoneDrawingMode(startingZoneID: UUID?) {
        if isGnomeZoneDrawingMode {
            isGnomeZoneDrawingMode = false
            NotificationCenter.default.post(
                name: .gardenGnomeZoneDrawingModeDidChange,
                object: self,
                userInfo: ["isEnabled": false]
            )
        }

        gnomeSettlementSetupPanelController?.close()
        gnomeSettlementSetupPanelController = nil

        if !store.state.gnomeTribeZones.isEmpty {
            store.commitGnomeTribeSettlement(startingZoneID: startingZoneID)
        }
        updateDynamicItems()
    }

    private func cancelGnomeZoneDrawingMode() {
        guard isGnomeZoneDrawingMode || gnomeSettlementSetupPanelController != nil else {
            return
        }

        isGnomeZoneDrawingMode = false
        NotificationCenter.default.post(
            name: .gardenGnomeZoneDrawingModeDidChange,
            object: self,
            userInfo: ["isEnabled": false]
        )
        gnomeSettlementSetupPanelController?.close()
        gnomeSettlementSetupPanelController = nil
        updateDynamicItems()
    }

    private func finishBirdSkyZoneDrawingMode() {
        guard isBirdSkyZoneDrawingMode else {
            return
        }

        isBirdSkyZoneDrawingMode = false
        NotificationCenter.default.post(
            name: .gardenBirdSkyZoneDrawingModeDidChange,
            object: self,
            userInfo: ["isEnabled": false]
        )
        updateDynamicItems()
    }

    private func cancelBirdSkyZoneDrawingMode() {
        guard isBirdSkyZoneDrawingMode else {
            return
        }

        isBirdSkyZoneDrawingMode = false
        NotificationCenter.default.post(
            name: .gardenBirdSkyZoneDrawingModeDidChange,
            object: self,
            userInfo: ["isEnabled": false]
        )
        updateDynamicItems()
    }

    private func setGnomePerspectiveAdjustmentMode(_ isEnabled: Bool) {
        guard isGnomePerspectiveAdjustmentMode != isEnabled else {
            return
        }

        isGnomePerspectiveAdjustmentMode = isEnabled
        NotificationCenter.default.post(
            name: .gardenGnomePerspectiveAdjustmentModeDidChange,
            object: self,
            userInfo: ["isEnabled": isEnabled]
        )
    }

    /// Leaves perspective-adjustment mode in response to the in-scene "Done"
    /// button, keeping the menu item's checkmark in sync.
    func endGnomePerspectiveAdjustmentMode() {
        setGnomePerspectiveAdjustmentMode(false)
        updateDynamicItems()
    }

    @objc private func toggleGardenInteractionLock() {
        let settings = store.state.settings
        store.updateSettings(
            settings.updating(isGardenInteractionLocked: !settings.isGardenInteractionLocked)
        )
    }

    @objc private func toggleAILockView() {
        guard requireProFeature(.aiLockView) else {
            return
        }
        let settings = store.state.settings
        store.updateSettings(
            settings.updating(useAIGeneratedLockSnapshot: !settings.useAIGeneratedLockSnapshot)
        )
    }

    @objc private func showTodayInGarden() {
        if store.state.settings.experienceMode == .alienUFO {
            showTodayInAlienGarden()
            return
        }

        guard store.state.settings.experienceMode == .garden else {
            showTodayInRoomStudio()
            return
        }

        let insights = GardenGameLoopInsights(
            state: store.state,
            sceneKey: store.activeSceneKey,
            date: Date()
        )
        let recommendation = store.state.careRecommendation
        let alert = NSAlert()
        alert.messageText = "Today in Garden"
        alert.informativeText = [
            "Next up: \(recommendation.summary)",
            insights.focus.statusSummary,
            insights.harvest.summary,
            insights.seeds.summary,
            insights.arrangement.summary
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "\n\n")
        alert.alertStyle = .informational
        alert.addButton(withTitle: recommendation.isActionable ? "Do Recommended Care" : "OK")
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Close")
        NSApplication.shared.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn where recommendation.isActionable:
            performRecommendedCare()
        case .alertSecondButtonReturn:
            openSettings()
        default:
            return
        }
    }

    private func showTodayInRoomStudio() {
        let alert = NSAlert()
        alert.messageText = "Today in Room Studio"
        alert.informativeText = [
            "Next up: pick a personal-space category, then use Add New to generate a transparent room prop at the clicked spot.",
            "Good first objects: a wall poster, a clothes pile, a retro console stack, a clothing rack, a collectibles shelf, or a chill corner prop.",
            "Room Studio prompts include the clicked screen position so generated props can match the local perspective, angle, scale, and contact shadows."
        ].joined(separator: "\n\n")
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Settings")
        NSApplication.shared.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn {
            openSettings()
        }
    }

    private func showTodayInAlienGarden() {
        let alert = NSAlert()
        alert.messageText = "Today in Alien Garden"
        alert.informativeText = [
            "Next up: choose an alien plant category, then use Add New to generate a transparent exobiology PNG at the clicked spot.",
            "Good first specimens: Nebula Orchid, Saturn Ring Willow, Plasma Fern, Starlight Moss, or Moon Melon Vine.",
            "Alien/UFO prompts keep the scene empty and create isolated chroma-key plant assets so the garden stays draggable and editable."
        ].joined(separator: "\n\n")
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Settings")
        NSApplication.shared.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn {
            openSettings()
        }
    }

    @objc private func cancelWallpaperUpdate() {
        wallpaperUpdateTask?.cancel()
        wallpaperUpdateTask = nil
        isUpdatingWallpaper = false
        updateDynamicItems()
    }

    @objc private func openCatCompanionSettings() {
        if catSettingsWindowController == nil {
            catSettingsWindowController = CatCompanionSettingsWindowController()
        }
        catSettingsWindowController?.show()
    }

    @objc private func toggleCatCompanion() {
        let defaults = UserDefaults.standard
        let isEnabled = defaults.object(
            forKey: CatCompanionController.enabledDefaultsKey
        ) as? Bool ?? true
        setCatCompanionVisible(!isEnabled)
    }

    private func setCatCompanionVisible(_ isVisible: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(isVisible, forKey: CatCompanionController.enabledDefaultsKey)
        let sharedDefaults = UserDefaults(suiteName: Self.appDefaultsSuiteName)
        sharedDefaults?.set(isVisible, forKey: CatCompanionController.enabledDefaultsKey)
        sharedDefaults?.synchronize()
        catCompanionItem.state = isVisible ? .on : .off
        NotificationCenter.default.post(name: .gardenCatCompanionToggled, object: nil)
    }

    @objc private func toggleAmbientSoundFromMenu() {
        let isEnabled = store.state.settings.isAmbientSoundEnabled
        store.updateSettings(store.state.settings.updating(isAmbientSoundEnabled: !isEnabled))
    }

    @objc private func toggleAmbientSoundLayerFromMenu(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let layer = GardenAmbientSoundLayer(rawValue: rawValue) else {
            return
        }

        let settings = store.state.settings
        switch layer {
        case .master:
            store.updateSettings(settings.updating(isAmbientSoundEnabled: !settings.isAmbientSoundEnabled))
        case .birdsong:
            store.updateSettings(settings.updating(isBirdsongEnabled: !settings.isBirdsongEnabled))
        case .crickets:
            store.updateSettings(settings.updating(isCricketSoundEnabled: !settings.isCricketSoundEnabled))
        case .wind:
            store.updateSettings(settings.updating(isWindSoundEnabled: !settings.isWindSoundEnabled))
        case .rain:
            store.updateSettings(settings.updating(isRainSoundEnabled: !settings.isRainSoundEnabled))
        case .water:
            store.updateSettings(settings.updating(isWaterSoundEnabled: !settings.isWaterSoundEnabled))
        case .urbanMurmur:
            store.updateSettings(settings.updating(isUrbanMurmurSoundEnabled: !settings.isUrbanMurmurSoundEnabled))
        case .roomTone:
            store.updateSettings(settings.updating(isRoomToneSoundEnabled: !settings.isRoomToneSoundEnabled))
        case .cicadas:
            store.updateSettings(settings.updating(isCicadaSoundEnabled: !settings.isCicadaSoundEnabled))
        case .chimes:
            store.updateSettings(settings.updating(isChimeSoundEnabled: !settings.isChimeSoundEnabled))
        case .smallWildlife:
            store.updateSettings(settings.updating(isSmallWildlifeSoundEnabled: !settings.isSmallWildlifeSoundEnabled))
        case .roomLife:
            store.updateSettings(settings.updating(isRoomLifeSoundEnabled: !settings.isRoomLifeSoundEnabled))
        case .electronics:
            store.updateSettings(settings.updating(isElectronicsSoundEnabled: !settings.isElectronicsSoundEnabled))
        case .alienFauna:
            store.updateSettings(settings.updating(isAlienFaunaSoundEnabled: !settings.isAlienFaunaSoundEnabled))
        case .habitatHum:
            store.updateSettings(settings.updating(isHabitatHumSoundEnabled: !settings.isHabitatHumSoundEnabled))
        case .crystallineShimmer:
            store.updateSettings(settings.updating(isCrystallineShimmerSoundEnabled: !settings.isCrystallineShimmerSoundEnabled))
        case .lowRumble:
            store.updateSettings(settings.updating(isLowRumbleSoundEnabled: !settings.isLowRumbleSoundEnabled))
        }
    }

    @objc private func toggleMusicButton() {
        let wasVisible = !store.state.musicButtons.isEmpty
        let target = lastDesktopPlantingTarget
            ?? Self.plantingTarget(at: NSEvent.mouseLocation)
            ?? PlantingTarget(screenIndex: 0, position: GardenPoint(x: 0.82, y: 0.72))
        let companion = store.state.musicButton?.companion ?? .gardenCat
        store.toggleMusicButton(screenIndex: target.screenIndex, position: target.position, companion: companion)

        if wasVisible {
            GardenRadioPlayer.shared.stop()
        }
    }

    @objc private func selectRadioCompanion(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let companion = GardenRadioCompanion(rawValue: rawValue) else {
            return
        }

        let wasPlaying = GardenRadioPlayer.shared.isPlaying
        let target = lastDesktopPlantingTarget
            ?? Self.plantingTarget(at: NSEvent.mouseLocation)
            ?? PlantingTarget(screenIndex: 0, position: GardenPoint(x: 0.82, y: 0.72))
        store.addMusicButton(
            screenIndex: target.screenIndex,
            position: Self.radioCompanionPlacement(
                near: target.position,
                existingCount: store.state.musicButtons.count
            ),
            companion: companion
        )
        if wasPlaying {
            GardenRadioPlayer.shared.playRadioStream(companion.stationStream(in: store.state.settings))
        }
    }

    @objc private func pruneSelected() {
        store.pruneSelectedPlant()
    }

    @objc private func nourishSelected() {
        store.nourishSelectedPlant()
    }

    @objc private func removeSelected() {
        store.removeSelectedPlant()
    }

    @objc private func openGardenData() {
        NSWorkspace.shared.activateFileViewerSelecting([store.activeGardenFileURL])
    }

    /// Opens the settings window programmatically (used by the
    /// `--open-settings` launch argument and menu action).
    func openSettingsWindow() {
        openSettings()
    }

    func performCatCompanionCommand(_ action: CatCompanionAppAction) -> CatCompanionCommandExecution {
        switch action {
        case .waterAll:
            store.waterAll()
            return .success("Done. I watered every plant in the scene.")
        case .waterThirstyPlants:
            let count = store.state.thirstyPlants.count
            store.waterThirstyPlants()
            return .success(count == 0 ? "No thirsty plants right now. Suspiciously hydrated." : "Done. I watered \(count) thirsty plant\(count == 1 ? "" : "s").")
        case .waterSelectedPlant:
            guard store.selectedPlant != nil else {
                return .unavailable("Select a plant first, then ask me to water it. I require one target, like a very tiny manager.")
            }
            store.waterSelectedPlant()
            return .success("Done. I watered the selected plant.")
        case .performRecommendedCare:
            let recommendation = store.state.careRecommendation
            guard recommendation.isActionable else {
                return .success("Recommended care says to enjoy the scene. I am excellent at that.")
            }
            performRecommendedCare()
            return .success("Done. I handled the recommended care: \(recommendation.summary).")
        case .harvestReadyCrops:
            let count = store.state.plants.filter(\.isHarvestReady).count
            store.harvestAllReadyCrops()
            return .success(count == 0 ? "No ready crops yet." : "Done. I harvested \(count) ready crop\(count == 1 ? "" : "s").")
        case .startFocus(let minutes):
            guard requireProFeature(.focusSessions) else {
                return .unavailable(GardenProFeature.focusSessions.paywallMessage)
            }
            store.startFocusSession(duration: TimeInterval(max(1, minutes) * 60))
            return .success("Focus session started for \(minutes) minutes.")
        case .cancelFocus:
            store.cancelFocusSession()
            return .success("Focus session cancelled.")
        case .setGrowthPaused(let isPaused):
            store.setPaused(isPaused)
            return .success(isPaused ? "Growth is paused." : "Growth is running again.")
        case .setInteractionLocked(let isLocked):
            store.updateSettings(store.state.settings.updating(isGardenInteractionLocked: isLocked))
            return .success(isLocked ? "Interactions are locked. Desktop clicks can behave normally." : "Interactions are unlocked.")
        case .setAILockView(let isEnabled):
            guard !isEnabled || requireProFeature(.aiLockView) else {
                return .unavailable(GardenProFeature.aiLockView.paywallMessage)
            }
            store.updateSettings(store.state.settings.updating(useAIGeneratedLockSnapshot: isEnabled))
            return .success(isEnabled ? "AI Lock View is on." : "AI Lock View is off.")
        case .setAmbientSounds(let isEnabled):
            store.updateSettings(store.state.settings.updating(isAmbientSoundEnabled: isEnabled))
            return .success(isEnabled ? "Environmental sounds are on." : "Environmental sounds are off.")
        case .setAnimatedBugs(let isEnabled):
            store.setAmbientWildlifeEnabledForCurrentMode(isEnabled)
            return .success(isEnabled ? "Animated bugs are on." : "Animated bugs are hidden.")
        case .setGnomesHidden(let isHidden):
            store.setGnomeTribesHidden(isHidden)
            return .success(isHidden ? "Gnomes are hidden for now." : "Gnomes are visible again.")
        case .setCozyMode(let isEnabled):
            store.updateSettings(store.state.settings.updating(cozyModeEnabled: isEnabled))
            return .success(isEnabled ? "Cozy Mode is on." : "Cozy Mode is off.")
        case .setNewPlantsAtMaturity(let isEnabled):
            store.updateSettings(store.state.settings.updating(plantNewPlantsAtMaturity: isEnabled))
            return .success(isEnabled ? "New plants will appear mature." : "New plants will start from their beginning stage.")
        case .setCatCompanionVisible(let isVisible):
            setCatCompanionVisible(isVisible)
            return .success(isVisible ? "Miso is visible again." : "Miso is hidden for now.")
        case .setCatChatOnClick(let isEnabled):
            store.updateSettings(store.state.settings.updating(isCatChatOnClickEnabled: isEnabled))
            return .success(isEnabled ? "Clicking Miso opens the chat window." : "Clicking Miso will not open the chat window.")
        case .setTimeLapseCadence(let cadence):
            store.updateSettings(store.state.settings.updating(timeLapseCadence: cadence))
            return .success("Time-lapse capture is set to \(cadence.displayName).")
        case .setPerformanceMode(let mode):
            store.updateSettings(store.state.settings.updating(performanceMode: mode))
            return .success("Performance mode is set to \(mode.displayName).")
        case .switchExperienceMode(let mode):
            switchExperienceMode(to: mode)
            guard store.state.settings.experienceMode == mode else {
                return .unavailable(Self.proFeature(for: mode)?.paywallMessage ?? "That mode is unavailable.")
            }
            return .success("Switched to \(mode.displayName).")
        case .applyNextScene:
            applyAdjacentWallpaperScene(.next)
            return .success("Switched to the next scene: \(activeSceneName).")
        case .applyPreviousScene:
            applyAdjacentWallpaperScene(.previous)
            return .success("Switched to the previous scene: \(activeSceneName).")
        case .reapplyCurrentScene:
            applyLivingScene()
            return .success("Reapplied the current scene.")
        case .restorePreviousWallpaper:
            restorePreviousWallpaper()
            return .success("Restored the previous wallpaper.")
        case .openSettings:
            openSettings()
            return .success("Opened Settings & Dashboard.")
        case .openCatSettings:
            openCatCompanionSettings()
            return .success("Opened Cat Companion Settings.")
        case .openPrivacyStorage:
            openPrivacyStorageSettings()
            return .success("Opened Privacy & Storage.")
        case .showToday:
            showTodayInGarden()
            return .success("Opened the Today panel.")
        case .showPricing:
            showPricing()
            return .success("Opened Pricing & Pro.")
        case .showWelcomeTour:
            showWelcomeTour()
            return .success("Opened the welcome tour.")
        case .showUninstallGuide:
            showUninstallCleanupGuide()
            return .success("Opened the uninstall cleanup guide.")
        case .openGardenData:
            openGardenData()
            return .success("Opened Garden Data in Finder.")
        case .toggleJarvisAssistant:
            guard requireProFeature(.jarvisAssistant) else {
                return .unavailable(GardenProFeature.jarvisAssistant.paywallMessage)
            }
            toggleJarvisAssistant()
            return .success("Toggled Jarvis Assistant.")
        case .openAPIKeySettings:
            openAIAPIKeySettings()
            return .success("Opened OpenAI API Key Settings.")
        case .updateCurrentWallpaper:
            updateCurrentWallpaper()
            return .success("Opened the wallpaper update prompt.")
        case .createAIWallpaper:
            createAIWallpaper()
            return .success("Opened AI wallpaper creation.")
        case .saveGardenSnapshot:
            saveGardenSnapshot()
            return .success("Opened the save snapshot panel.")
        case .saveShareCard:
            saveShareCard()
            return .success("Opened the share card save panel.")
        case .exportTimeLapse:
            guard requireProFeature(.timeLapseExport) else {
                return .unavailable(GardenProFeature.timeLapseExport.paywallMessage)
            }
            exportTimeLapse()
            return .success("Opened time-lapse export.")
        case .drawGnomeSettlementAreas:
            guard requireProFeature(.gnomeSocieties) else {
                return .unavailable(GardenProFeature.gnomeSocieties.paywallMessage)
            }
            if !isGnomeZoneDrawingMode {
                toggleGnomeZoneDrawingMode()
            }
            return .success("Gnome settlement drawing is ready. Draw the habitat areas, then click Done in the setup panel.")
        case .adjustGnomePerspective:
            guard requireProFeature(.gnomeSocieties) else {
                return .unavailable(GardenProFeature.gnomeSocieties.paywallMessage)
            }
            guard !store.state.gnomeTribeZones.isEmpty else {
                return .unavailable("Draw a gnome settlement area first, then I can help adjust the gnome perspective.")
            }
            if !isGnomePerspectiveAdjustmentMode {
                toggleGnomePerspectiveAdjustmentMode()
            }
            return .success("Gnome perspective adjustment is ready. Drag on the desktop to tune the angle.")
        case .removeAllGnomeZones:
            removeAllGnomesFromScene()
            return .success("Done. The gnome tribes packed up their little camps.")
        case .resetPlantsToSeedlings:
            store.resetPlantsToNascentGrowthInCurrentScene()
            return .success("Done. Current plants are back at their beginning forms.")
        case .removeAllPlantsInScene:
            store.removeAllPlantsInCurrentScene()
            return .success("Done. I cleared all plants and objects from this scene.")
        case .resetGarden:
            store.resetGarden(screenCount: targetScreens().count)
            store.removePlantsWithoutDisplayableAssets()
            return .success("Done. The active scene is reset.")
        }
    }

    @objc private func openPrivacyStorageSettings() {
        let controller = settingsController()
        controller.showPrivacyStorageSection()
    }

    @objc private func openSettings() {
        settingsController().showCentered()
    }

    @objc private func openProfile() {
        profileWindowController.show()
    }

    @objc private func showPricing() {
        presentPricing(lockedFeature: nil)
    }

    private func presentPricing(lockedFeature: GardenProFeature?) {
        pricingWindowController.show(lockedFeature: lockedFeature)
    }

    private func settingsController() -> GardenSettingsWindowController {
        let controller: GardenSettingsWindowController
        if let settingsWindowController {
            controller = settingsWindowController
        } else {
            controller = GardenSettingsWindowController(
                store: store,
                wallpaperManager: wallpaperManager,
                actions: GardenSettingsWindowController.Actions(
                    applyScene: { [weak self] sceneKey in
                        self?.applyWallpaperSceneKey(sceneKey)
                    },
                    applySceneWithSettings: { [weak self] sceneKey, settings in
                        self?.applyWallpaperSceneKey(sceneKey, settingsOverride: settings)
                    },
                    chooseWallpaper: { [weak self] in
                        self?.chooseWallpaper()
                    },
                    createAIWallpaper: { [weak self] in
                        self?.createAIWallpaper()
                    },
                    generateSceneEdit: { [weak self] prompt, completion in
                        guard let self else {
                            completion(.failure(CancellationError()))
                            return
                        }
                        self.generateWallpaperEdit(prompt: prompt, completion: completion)
                    },
                    openAPIKeySettings: { [weak self] in
                        self?.openAIAPIKeySettings()
                    },
                    reapplyScene: { [weak self] in
                        self?.applyLivingScene()
                    },
                    restorePreviousWallpaper: { [weak self] in
                        self?.restorePreviousWallpaper()
                    },
                    resetGarden: { [weak self] in
                        self?.resetGarden()
                    },
                    deleteAllPlantsInScene: { [weak self] in
                        self?.deleteAllPlantsInScene()
                    },
                    arrangeGarden: { [weak self] in
                        self?.arrangeGarden()
                    },
                    showWelcomeTour: { [weak self] in
                        self?.showWelcomeTour()
                    },
                    saveHealthCheck: { [weak self] in
                        self?.saveHealthCheck()
                    }
                )
            )
            settingsWindowController = controller
        }

        return controller
    }

    @objc private func showWelcomeTour() {
        let controller = welcomeController ?? GardenWelcomeController(store: store)
        welcomeController = controller
        controller.show()
    }

    @objc private func showUninstallCleanupGuide() {
        let alert = NSAlert()
        alert.messageText = "Uninstall & Cleanup"
        alert.informativeText = """
        To fully clean up Plant Wallpaper data, quit the app, remove the app from Applications, then delete the local app data folder if you no longer want gardens, journals, generated wallpapers, custom plant assets, or time-lapse frames.

        Leaving? Tap “Restore Original Wallpaper” to put your previous desktop wallpaper back. Use Privacy & Storage Settings first if you only want to delete time-lapse frames or inspect disk usage.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Reveal App Data")
        alert.addButton(withTitle: "Restore Original Wallpaper")
        alert.addButton(withTitle: "Privacy & Storage")
        alert.addButton(withTitle: "Close")
        NSApplication.shared.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            openGardenData()
        case .alertSecondButtonReturn:
            restorePreviousWallpaper()
        case .alertThirdButtonReturn:
            openPrivacyStorageSettings()
        default:
            break
        }
    }

    @objc private func saveHealthCheck() {
        GardenHealthCheckExporter.exportInteractively(
            store: store,
            activeSceneName: activeSceneName,
            weatherStatus: weatherStatusSummary,
            timeLapseRecorder: GardenTimeLapseExporter.shared.recorder
        )
    }

    private var activeSceneName: String {
        let key = wallpaperManager.selectedWallpaperSceneKey
        return GardenWallpaperScene(rawValue: key)?.displayName
            ?? wallpaperManager.customWallpapers.first { $0.key == key }?.displayName
            ?? "Custom Scene"
    }

    private func assistantRuntimeContext() -> GardenAssistantRuntimeContext {
        GardenAssistantRuntimeContext(
            state: store.state,
            activeSceneDisplayName: activeSceneName,
            activeSceneKey: wallpaperManager.selectedWallpaperSceneKey,
            selectedPlant: store.selectedPlant
        )
    }

    private var weatherStatusSummary: String {
        guard store.state.settings.isWeatherSyncEnabled else {
            return "Weather sync off"
        }

        return store.state.weather?.summary ?? "Waiting for weather"
    }

    @objc private func applyLivingScene() {
        wallpaperManager.applyLivingSceneWallpaper()
        updateDynamicItems()
    }

    @objc private func applyPreviousWallpaperScene() {
        applyAdjacentWallpaperScene(.previous)
    }

    @objc private func applyNextWallpaperScene() {
        applyAdjacentWallpaperScene(.next)
    }

    @objc private func applyWallpaperScene(_ sender: NSMenuItem) {
        guard let sceneKey = sender.representedObject as? String else {
            return
        }

        applyWallpaperSceneKey(sceneKey)
    }

    @objc private func applyWallpaperSceneRoot(_ sender: NSMenuItem) {
        guard let sceneKey = sender.representedObject as? String else {
            return
        }

        applyWallpaperSceneKey(wallpaperManager.latestWallpaperKey(forSceneRootKey: sceneKey))
    }

    @objc private func applyWallpaperVersion(_ sender: NSMenuItem) {
        guard let sceneKey = sender.representedObject as? String else {
            return
        }

        applyWallpaperSceneKey(sceneKey)
    }

    private func applyAdjacentWallpaperScene(_ direction: GardenSceneNavigationDirection) {
        let sceneKey = GardenSceneNavigator.adjacentSceneKey(
            from: wallpaperManager.wallpaperSceneRootKey(),
            customWallpapers: wallpaperManager.customWallpapers,
            direction: direction,
            experienceMode: store.state.settings.experienceMode
        )
        applyWallpaperSceneKey(wallpaperManager.latestWallpaperKey(forSceneRootKey: sceneKey))
    }

    private func applyWallpaperSceneKey(
        _ sceneKey: String,
        settingsOverride: GardenSettings? = nil,
        screensOverride: [NSScreen]? = nil
    ) {
        let playingRadioStation = GardenRadioPlayer.shared.playingRadioStation
        let playingRadioStream = GardenRadioPlayer.shared.playingRadioStream
        let screens = screensOverride ?? targetScreens()
        let appliedSceneKey = wallpaperManager.applyWallpaperSceneKey(sceneKey, to: screens)
        store.switchGardenScene(
            to: appliedSceneKey,
            screenCount: screens.count,
            playingRadioStation: playingRadioStation,
            playingRadioStream: playingRadioStream,
            settingsOverride: settingsOverride
        )
        store.removePlantsWithoutDisplayableAssets()
        refreshPlantingMenus()
        updateDynamicItems()
    }

    @objc private func chooseWallpaper() {
        let panel = NSOpenPanel()
        panel.title = "Choose Garden Wallpaper"
        panel.prompt = "Choose"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        do {
            let playingRadioStation = GardenRadioPlayer.shared.playingRadioStation
            let screens = targetScreens()
            let record = try wallpaperManager.createChosenWallpaperScene(
                from: url,
                to: screens,
                experienceMode: store.state.settings.experienceMode
            )
            store.switchGardenScene(
                to: record.key,
                screenCount: screens.count,
                playingRadioStation: playingRadioStation,
                playingRadioStream: GardenRadioPlayer.shared.playingRadioStream
            )
            store.removePlantsWithoutDisplayableAssets()
            refreshWallpaperScenesMenu()
            refreshPlantingMenus()
        } catch {
            showError(title: "Wallpaper failed", message: error.localizedDescription)
        }
    }

    @objc private func createAIWallpaper() {
        guard let prompt = aiWallpaperPrompt() else {
            return
        }

        guard let apiKey = OpenAIAPIKeyStore.load() else {
            showError(title: "OpenAI API key needed", message: "Add your OpenAI API key in settings, then create the AI wallpaper again.")
            openAIAPIKeySettings()
            return
        }

        Task { @MainActor in
            do {
                let screens = targetScreens()
                let record = try await wallpaperManager.createAIWallpaper(
                    prompt: prompt,
                    apiKey: apiKey,
                    to: screens,
                    experienceMode: store.state.settings.experienceMode,
                    quality: store.state.settings.wallpaperGenerationQuality
                )
                promptHistoryStore.record(feature: .newWallpaper, title: record.displayName, prompt: prompt)
                store.switchGardenScene(
                    to: record.key,
                    screenCount: screens.count,
                    playingRadioStation: GardenRadioPlayer.shared.playingRadioStation,
                    playingRadioStream: GardenRadioPlayer.shared.playingRadioStream
                )
                store.removePlantsWithoutDisplayableAssets()
                refreshWallpaperScenesMenu()
                refreshPlantingMenus()
            } catch {
                showError(title: "AI wallpaper failed", message: error.localizedDescription)
            }
        }
    }

    @objc private func updateCurrentWallpaper() {
        if isUpdatingWallpaper {
            cancelWallpaperUpdate()
            return
        }

        guard let prompt = wallpaperUpdatePrompt() else {
            return
        }

        generateWallpaperEdit(prompt: prompt) { [weak self] result in
            if case .failure(let error) = result, !(error is CancellationError) {
                self?.showError(title: "Wallpaper update failed", message: error.localizedDescription)
            }
        }
    }

    /// Shared AI wallpaper-edit pipeline used by the menu's "Update Current
    /// Wallpaper" and by the Settings scene editor. Generates a new version of
    /// the currently selected scene, applies it, and reports the outcome.
    func generateWallpaperEdit(
        prompt: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard !isUpdatingWallpaper else {
            completion(.failure(WallpaperManagerError.openAIError("A wallpaper is already generating. Try again once it finishes.")))
            return
        }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            completion(.failure(WallpaperManagerError.openAIError("Describe the wallpaper change you want.")))
            return
        }

        guard let apiKey = OpenAIAPIKeyStore.load() else {
            completion(.failure(WallpaperManagerError.openAIError("Add your OpenAI API key in settings, then generate again.")))
            openAIAPIKeySettings()
            return
        }

        let startingSceneKey = store.activeSceneKey
        let startingState = store.state
        let promptWithStrength = "\(store.state.settings.aiEditStrength.promptInstruction)\n\n\(trimmedPrompt)"
        isUpdatingWallpaper = true
        updateDynamicItems()

        wallpaperUpdateTask = Task { @MainActor in
            defer {
                wallpaperUpdateTask = nil
                isUpdatingWallpaper = false
                refreshWallpaperScenesMenu()
                updateDynamicItems()
            }

            do {
                let screens = targetScreens()
                let record = try await wallpaperManager.createEditedWallpaperScene(
                    updatePrompt: promptWithStrength,
                    apiKey: apiKey,
                    to: screens,
                    quality: store.state.settings.wallpaperGenerationQuality
                )
                try Task.checkCancellation()
                promptHistoryStore.record(feature: .wallpaperEdit, title: record.displayName, prompt: trimmedPrompt)
                let stateToCarry = store.activeSceneKey == startingSceneKey ? store.state : startingState
                try? store.persistence.save(stateToCarry, sceneKey: record.key)
                store.switchGardenScene(
                    to: record.key,
                    screenCount: screens.count,
                    playingRadioStation: GardenRadioPlayer.shared.playingRadioStation,
                    playingRadioStream: GardenRadioPlayer.shared.playingRadioStream
                )
                store.removePlantsWithoutDisplayableAssets()
                refreshPlantingMenus()
                completion(.success(()))
            } catch is CancellationError {
                completion(.failure(CancellationError()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    @objc private func toggleProgressionMode() {
        guard requireProFeature(.progressionMode) else {
            return
        }
        guard let progression = store.state.progression else {
            // No profile yet — turning the mode on means setting it up.
            setupProgressionMode()
            return
        }
        store.setProgressionEnabled(!progression.isEnabled)
        updateDynamicItems()
    }

    @objc private func setupProgressionMode() {
        guard requireProFeature(.progressionMode) else {
            return
        }
        guard let profile = progressionProfileFromUser(existing: store.state.progression?.profile) else {
            return
        }

        let existing = store.state.progression
        store.updateProgression(
            GardenSceneProgression(
                isEnabled: true,
                level: existing?.level ?? 0,
                profile: profile,
                startedAt: existing?.startedAt ?? Date(),
                lastAdvancedAt: existing?.lastAdvancedAt
            )
        )
        updateDynamicItems()
    }

    @objc private func resetProgressionMode() {
        guard requireProFeature(.progressionMode) else {
            return
        }
        guard store.state.progression != nil else {
            return
        }

        let alert = NSAlert()
        alert.messageText = "Reset progression for this scene?"
        alert.informativeText = "This removes the fantasy profile and level tracking from the current scene. Wallpaper versions already generated remain available."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        store.updateProgression(nil)
        updateDynamicItems()
    }

    @objc private func generateNextProgressionLevel() {
        guard requireProFeature(.progressionMode) else {
            return
        }
        if isUpdatingWallpaper {
            cancelWallpaperUpdate()
            return
        }

        guard let progression = store.state.progression else {
            setupProgressionMode()
            return
        }

        // Paused ladders resume rather than erroring; the menu item is normally
        // disabled while paused, so this is a defensive/keyboard-path branch.
        if !progression.isEnabled {
            store.setProgressionEnabled(true)
            updateDynamicItems()
            return
        }

        guard progression.canAdvance else {
            showError(title: "Progression complete", message: "This scene is already at Level \(GardenSceneProgression.maximumLevel).")
            return
        }

        guard let apiKey = OpenAIAPIKeyStore.load() else {
            showError(title: "OpenAI API key needed", message: "Add your OpenAI API key in settings, then generate the next progression level again.")
            openAIAPIKeySettings()
            return
        }

        let targetLevel = progression.nextLevel
        let mode = store.state.settings.experienceMode
        let levelTitle = GardenSceneProgression.title(for: targetLevel, experienceMode: mode)
        let quality = store.state.settings.wallpaperGenerationQuality
        let alert = NSAlert()
        alert.messageText = "Generate Level \(targetLevel): \(levelTitle)?"
        alert.informativeText = "This sends the current wallpaper image to OpenAI at \(quality.displayName) (\(quality.openAISize)). \(quality.settingsNote)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Generate")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        runProgressionGeneration(
            progression: progression,
            targetLevel: targetLevel,
            advancing: true,
            apiKey: apiKey
        )
    }

    @objc private func regenerateCurrentProgressionLevel() {
        guard requireProFeature(.progressionMode) else {
            return
        }
        if isUpdatingWallpaper {
            cancelWallpaperUpdate()
            return
        }

        guard let progression = store.state.progression, progression.level > 0 else {
            showError(
                title: "Nothing to regenerate yet",
                message: "Generate Level 1 first — then you can re-roll a level you don't love."
            )
            return
        }

        guard let apiKey = OpenAIAPIKeyStore.load() else {
            showError(title: "OpenAI API key needed", message: "Add your OpenAI API key in settings, then regenerate this level again.")
            openAIAPIKeySettings()
            return
        }

        let targetLevel = progression.level
        let mode = store.state.settings.experienceMode
        let levelTitle = GardenSceneProgression.title(for: targetLevel, experienceMode: mode)
        let quality = store.state.settings.wallpaperGenerationQuality
        let alert = NSAlert()
        alert.messageText = "Regenerate Level \(targetLevel): \(levelTitle)?"
        alert.informativeText = "This re-rolls the current level into a new version without advancing. It sends the current wallpaper image to OpenAI at \(quality.displayName) (\(quality.openAISize)). \(quality.settingsNote)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Regenerate")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        runProgressionGeneration(
            progression: progression,
            targetLevel: targetLevel,
            advancing: false,
            apiKey: apiKey
        )
    }

    @objc private func selectProgressionAutoAdvanceCadence(_ sender: NSMenuItem) {
        guard requireProFeature(.progressionMode) else {
            return
        }
        guard let rawValue = sender.representedObject as? String,
              let cadence = GardenSceneProgression.AutoAdvanceCadence(rawValue: rawValue) else {
            return
        }
        store.setProgressionAutoAdvanceCadence(cadence)
        updateDynamicItems()
    }

    /// Called periodically by the app clock. Generates the next level on its own
    /// when an enabled ladder's cadence has come due. Silently skips when Pro is
    /// locked, a generation is already running, or there is no API key.
    func checkProgressionAutoAdvanceIfDue() {
        guard isProFeatureUnlocked(.progressionMode), !isUpdatingWallpaper else {
            return
        }
        guard let progression = store.state.progression, progression.isAutoAdvanceDue() else {
            return
        }
        guard let apiKey = OpenAIAPIKeyStore.load() else {
            return
        }

        runProgressionGeneration(
            progression: progression,
            targetLevel: progression.nextLevel,
            advancing: true,
            apiKey: apiKey
        )
    }

    /// Shared progression generation pipeline. `advancing` controls whether the
    /// carried state moves up a level (Generate / Auto-Advance) or holds the
    /// current level (Regenerate). A successful advance fires a celebration.
    private func runProgressionGeneration(
        progression: GardenSceneProgression,
        targetLevel: Int,
        advancing: Bool,
        apiKey: String
    ) {
        let mode = store.state.settings.experienceMode
        let startingSceneKey = store.activeSceneKey
        let startingState = store.state
        isUpdatingWallpaper = true
        updateDynamicItems()

        wallpaperUpdateTask = Task { @MainActor in
            defer {
                wallpaperUpdateTask = nil
                isUpdatingWallpaper = false
                refreshWallpaperScenesMenu()
                updateDynamicItems()
            }

            do {
                let screens = targetScreens()
                let record = try await wallpaperManager.createProgressionWallpaperScene(
                    progression: progression,
                    targetLevel: targetLevel,
                    experienceMode: mode,
                    apiKey: apiKey,
                    to: screens,
                    quality: store.state.settings.wallpaperGenerationQuality
                )
                try Task.checkCancellation()
                promptHistoryStore.record(
                    feature: .wallpaperProgression,
                    title: record.displayName,
                    prompt: WallpaperProgressionPrompt.masterPrompt(
                        progression: progression,
                        targetLevel: targetLevel,
                        experienceMode: mode
                    )
                )

                var stateToCarry = store.activeSceneKey == startingSceneKey ? store.state : startingState
                stateToCarry.progression = advancing ? progression.advanced() : progression
                try? store.persistence.save(stateToCarry, sceneKey: record.key)
                store.switchGardenScene(
                    to: record.key,
                    screenCount: screens.count,
                    playingRadioStation: GardenRadioPlayer.shared.playingRadioStation,
                    playingRadioStream: GardenRadioPlayer.shared.playingRadioStream
                )
                store.removePlantsWithoutDisplayableAssets()
                refreshPlantingMenus()

                if advancing {
                    progressionLevelCelebrationHandler?(
                        targetLevel,
                        GardenSceneProgression.title(for: targetLevel, experienceMode: mode),
                        targetLevel >= GardenSceneProgression.maximumLevel
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                showError(title: "Progression generation failed", message: error.localizedDescription)
            }
        }
    }

    @objc private func openAIAPIKeySettings() {
        let alert = NSAlert()
        alert.messageText = "OpenAI API Key"
        alert.informativeText = """
        AI wallpapers and custom plant assets use your own OpenAI account — a paid OpenAI Platform key (separate from ChatGPT), billed per image. Updating a wallpaper sends that scene's image to OpenAI.

        No key yet? Tap “Get a Key…” to open platform.openai.com/api-keys, create one, then paste it below. It's stored only in your Mac's Keychain.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Get a Key...")
        alert.addButton(withTitle: "Remove Key")
        alert.addButton(withTitle: "Cancel")

        let keyField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 420, height: 24))
        keyField.placeholderString = OpenAIAPIKeyStore.keyFieldPlaceholder
        keyField.stringValue = OpenAIAPIKeyStore.load() ?? ""
        alert.accessoryView = keyField

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            do {
                try OpenAIAPIKeyStore.save(keyField.stringValue)
            } catch {
                showError(title: "Could not save API key", message: error.localizedDescription)
            }
        case .alertSecondButtonReturn:
            // "Get a Key..." opens the OpenAI key page, then re-presents this
            // dialog so the user can paste the key they just created.
            if let url = URL(string: "https://platform.openai.com/api-keys") {
                NSWorkspace.shared.open(url)
            }
            openAIAPIKeySettings()
        case .alertThirdButtonReturn:
            OpenAIAPIKeyStore.delete()
        default:
            return
        }
    }

    private func aiWallpaperPrompt() -> String? {
        let quality = store.state.settings.wallpaperGenerationQuality
        let alert = NSAlert()
        alert.messageText = "Create AI Wallpaper"
        alert.informativeText = "Describe the empty scene you want. Generation is set to \(quality.displayName) (\(quality.openAISize)). \(quality.settingsNote) No current wallpaper image is sent for a new scene."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let promptField = NSTextField(frame: NSRect(x: 0, y: 0, width: 440, height: 26))
        promptField.placeholderString = "Example: a sunlit stone orangery with empty raised soil beds"
        promptField.stringValue = promptHistoryStore.recentPrompt(for: .newWallpaper) ?? ""
        alert.accessoryView = promptField

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        let prompt = promptField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            return nil
        }

        return prompt
    }

    private func progressionProfileFromUser(existing: GardenProgressionProfile?) -> GardenProgressionProfile? {
        let mode = store.state.settings.experienceMode
        let alert = NSAlert()
        alert.messageText = "Progression Mode Fantasy Profile"
        alert.informativeText = mode == .garden
            ? "Describe the garden lifestyle you want this scene to grow toward over 20 levels."
            : "Describe the room or hangout lifestyle you want this scene to grow toward over 20 levels."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save Profile")
        alert.addButton(withTitle: "Cancel")

        let lifestyleField = progressionTextField(
            placeholder: mode == .garden
                ? "Example: quiet old-money estate garden, creative founder villa, tropical cliffside retreat"
                : "Example: music producer loft, cozy gamer den, fashion collector suite, luxe man cave"
        )
        lifestyleField.stringValue = existing?.lifestyleFantasy ?? ""

        let placeField = progressionTextField(
            placeholder: "Example: coastal Brazil, Swedish archipelago, Kyoto mountains, Austin hill country"
        )
        placeField.stringValue = existing?.placeInWorld ?? ""

        let ageField = progressionTextField(
            placeholder: "Example: early 20s first apartment, 30s founder, retired eccentric collector"
        )
        ageField.stringValue = existing?.ageBracket ?? ""

        let vibeField = progressionTextField(
            placeholder: "Example: warm minimal, maximalist surreal, earthy cinematic, playful retro-futurist"
        )
        vibeField.stringValue = existing?.vibe ?? ""

        let avoidField = progressionTextField(
            placeholder: "Optional: anything you do not want the progression to include"
        )
        avoidField.stringValue = existing?.avoidList ?? ""

        let stack = NSStackView(views: [
            progressionFieldGroup(title: "Lifestyle fantasy", field: lifestyleField),
            progressionFieldGroup(title: "Place in the world", field: placeField),
            progressionFieldGroup(title: "Age bracket / life stage", field: ageField),
            progressionFieldGroup(title: "Vibe", field: vibeField),
            progressionFieldGroup(title: "Avoid", field: avoidField)
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.frame = NSRect(x: 0, y: 0, width: 520, height: 310)
        alert.accessoryView = stack

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        let profile = GardenProgressionProfile(
            lifestyleFantasy: lifestyleField.stringValue,
            placeInWorld: placeField.stringValue,
            ageBracket: ageField.stringValue,
            vibe: vibeField.stringValue,
            avoidList: avoidField.stringValue
        )
        guard profile.isUsable else {
            showError(title: "Profile needs a direction", message: "Add at least a lifestyle, place, or vibe so progression has something to steer toward.")
            return nil
        }
        return profile
    }

    private func progressionTextField(placeholder: String) -> NSTextField {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 520, height: 24))
        field.placeholderString = placeholder
        field.lineBreakMode = .byTruncatingTail
        return field
    }

    private func progressionFieldGroup(title: String, field: NSTextField) -> NSView {
        let label = customPlantLabel(
            title,
            font: .systemFont(ofSize: 12, weight: .medium),
            color: .secondaryLabelColor
        )
        let stack = NSStackView(views: [label, field])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        field.widthAnchor.constraint(equalToConstant: 520).isActive = true
        return stack
    }

    private func wallpaperUpdatePrompt() -> String? {
        let quality = store.state.settings.wallpaperGenerationQuality
        let alert = NSAlert()
        alert.messageText = "Update Current Wallpaper"
        alert.informativeText = "Describe only what should change. This sends the current wallpaper image to OpenAI at \(quality.displayName) (\(quality.openAISize)). \(quality.settingsNote) The result is saved as a new version so you can revert."
        alert.alertStyle = .informational
        let generateButton = alert.addButton(withTitle: "Generate")
        let cancelButton = alert.addButton(withTitle: "Cancel")
        generateButton.toolTip = "Start an AI wallpaper edit. The finished image applies automatically."
        cancelButton.toolTip = "Close without changing the wallpaper."

        let descriptionTextView = CustomPlantAssetPlaceholderTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 94))
        descriptionTextView.font = .systemFont(ofSize: 13)
        descriptionTextView.isRichText = false
        descriptionTextView.allowsUndo = true
        descriptionTextView.textContainerInset = NSSize(width: 10, height: 9)
        descriptionTextView.drawsBackground = true
        descriptionTextView.backgroundColor = .textBackgroundColor
        descriptionTextView.placeholderString = "Example: make the afternoon light warmer and change the stone planters to dark slate"
        descriptionTextView.string = promptHistoryStore.recentPrompt(for: .wallpaperEdit) ?? ""
        descriptionTextView.toolTip = "Write a focused wallpaper edit. The master prompt preserves the current composition and applies only this update."

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 500, height: 96))
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = descriptionTextView
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 9
        scrollView.layer?.masksToBounds = true

        let privacy = customPlantLabel(
            "Edit strength: \(store.state.settings.aiEditStrength.displayName). \(quality.displayName) output; current wallpaper image + request are sent to OpenAI.",
            font: .systemFont(ofSize: 11),
            color: .tertiaryLabelColor
        )
        privacy.toolTip = "The generated wallpaper is saved as a new scene version so you can revert later."

        let root = NSStackView(views: [scrollView, privacy])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 8
        root.edgeInsets = NSEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
        root.frame = NSRect(x: 0, y: 0, width: 500, height: 122)

        for view in root.arrangedSubviews {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalToConstant: 500).isActive = true
        }
        scrollView.heightAnchor.constraint(equalToConstant: 96).isActive = true

        alert.accessoryView = root

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        let prompt = descriptionTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            return nil
        }

        return prompt
    }

    private func customPlantAssetRequest(kind: PlantKind) -> CustomPlantAssetRequest? {
        let mode = store.state.settings.experienceMode
        let isAlienMode = mode == .alienUFO
        let isRoomMode = mode == .roomStudio
        let alert = NSAlert()
        alert.messageText = if isAlienMode {
            AlienPlantMenuCatalog.addNewTitle(for: kind)
        } else if isRoomMode {
            RoomStudioPlantMenuCatalog.addNewTitle
        } else {
            GardenPlantCategoryMenuTitle.addNewTitle(for: kind)
        }
        alert.informativeText = if isAlienMode {
            "Create a high-fidelity exobiology plant cutout for this alien scene."
        } else if isRoomMode {
            "Create a high-fidelity indoor plant cutout for this room. Pots and planters are welcome here."
        } else {
            "Create a high-fidelity plant cutout for this scene."
        }
        alert.alertStyle = .informational
        let createButton = alert.addButton(withTitle: "Generate & Plant")
        let cancelButton = alert.addButton(withTitle: "Cancel")
        createButton.toolTip = CustomPlantAssetPromptStudio.primaryButtonTooltip
        cancelButton.toolTip = CustomPlantAssetPromptStudio.cancelButtonTooltip

        let nameField = NSTextField(frame: .zero)
        nameField.placeholderString = if isAlienMode {
            "Name this alien plant (optional)"
        } else if isRoomMode {
            "Name this indoor plant (optional)"
        } else {
            "Name this plant (optional)"
        }
        nameField.toolTip = CustomPlantAssetPromptStudio.nameTooltip
        nameField.controlSize = .large
        nameField.font = .systemFont(ofSize: 14)

        let descriptionTextView = CustomPlantAssetPlaceholderTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 110))
        descriptionTextView.font = .systemFont(ofSize: 13)
        descriptionTextView.string = promptHistoryStore.recentPrompt(for: .customPlant) ?? ""
        descriptionTextView.isRichText = false
        descriptionTextView.allowsUndo = true
        descriptionTextView.toolTip = CustomPlantAssetPromptStudio.descriptionTooltip
        descriptionTextView.placeholderString = if isAlienMode {
            AlienPlantMenuCatalog.starterDescription(for: kind)
        } else if isRoomMode {
            RoomStudioPlantMenuCatalog.starterDescription
        } else {
            CustomPlantAssetPromptStudio.starterDescription(for: kind)
        }
        descriptionTextView.textContainerInset = NSSize(width: 10, height: 9)
        descriptionTextView.drawsBackground = true
        descriptionTextView.backgroundColor = .textBackgroundColor

        let promptAssistant = CustomPlantAssetPromptAssistant(textView: descriptionTextView, kind: kind)
        alert.accessoryView = customPlantAssetAccessoryView(
            kind: kind,
            nameField: nameField,
            descriptionTextView: descriptionTextView,
            assistant: promptAssistant
        )

        let response = withExtendedLifetime(promptAssistant) {
            alert.runModal()
        }

        guard response == .alertFirstButtonReturn else {
            return nil
        }

        guard let request = CustomPlantAssetPrompt.normalizedRequest(
            kind: kind,
            displayName: nameField.stringValue,
            userDescription: descriptionTextView.string,
            experienceMode: mode
        ) else {
            showError(title: "Describe the plant", message: CustomPlantAssetError.invalidDescription.localizedDescription)
            return nil
        }

        return request
    }

    private func customRoomObjectAssetRequest(category: RoomObjectCategory) -> CustomPlantAssetRequest? {
        let alert = NSAlert()
        alert.messageText = category.addNewTitle
        alert.informativeText = "Type what you want, and it'll be generated as a high-fidelity cutout placed at the clicked spot."
        alert.alertStyle = .informational
        let createButton = alert.addButton(withTitle: "Generate & Place")
        let cancelButton = alert.addButton(withTitle: "Cancel")
        createButton.toolTip = "Uses OpenAI image generation to create a transparent PNG room object matched to the clicked perspective."
        cancelButton.toolTip = "Close without creating a room object."

        let nameField = NSTextField(frame: .zero)
        nameField.placeholderString = "Name this object (optional)"
        nameField.toolTip = "Used in the inspector and saved asset list."
        nameField.controlSize = .large
        nameField.font = .systemFont(ofSize: 14)

        let descriptionTextView = CustomPlantAssetPlaceholderTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 112))
        descriptionTextView.font = .systemFont(ofSize: 13)
        descriptionTextView.string = ""
        descriptionTextView.isRichText = false
        descriptionTextView.allowsUndo = true
        descriptionTextView.toolTip = "Describe the exact prop, style, material, era, messiness, and where it should feel like it sits."
        descriptionTextView.placeholderString = category.starterDescription
        descriptionTextView.textContainerInset = NSSize(width: 10, height: 9)
        descriptionTextView.drawsBackground = true
        descriptionTextView.backgroundColor = .textBackgroundColor

        let width: CGFloat = 500
        let target = lastDesktopPlantingTarget ?? Self.plantingTarget(at: NSEvent.mouseLocation)
        let perspectiveContext = RoomObjectPerspectiveContext.inferred(from: target?.position)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: 112))
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = descriptionTextView

        let nameLabel = formLabel("Object name")
        let descriptionLabel = formLabel("Describe the room object")
        let perspectiveLabel = helperText("Perspective: \(perspectiveContext.surfaceHint). The generator will be asked to match the clicked area angle and contact shadows.")

        // NSAlert sizes the accessory view from its frame; without an explicit
        // frame and per-row width constraints the stack collapses to zero height
        // and the input fields never appear (matches the working plant dialog).
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        stack.frame = NSRect(x: 0, y: 0, width: width, height: 250)

        for row in [nameLabel, nameField, descriptionLabel, scrollView, perspectiveLabel] as [NSView] {
            stack.addArrangedSubview(row)
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        nameField.heightAnchor.constraint(equalToConstant: 28).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 112).isActive = true

        alert.accessoryView = stack
        alert.window.initialFirstResponder = descriptionTextView

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        let description = descriptionTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else {
            showError(title: "Describe the room object", message: "Tell the generator what prop you want to place.")
            return nil
        }

        return CustomPlantAssetRequest(
            kind: category.fallbackPlantKind,
            displayName: CustomPlantAssetPrompt.displayName(
                from: nameField.stringValue,
                description: description,
                fallbackKind: category.fallbackPlantKind
            ),
            userDescription: description,
            roomObjectCategory: category,
            roomPerspectiveContext: perspectiveContext
        )
    }

    private func formLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func helperText(_ title: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: title)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 2
        label.preferredMaxLayoutWidth = 500
        return label
    }

    private func customPlantAssetAccessoryView(
        kind: PlantKind,
        nameField: NSTextField,
        descriptionTextView: NSTextView,
        assistant: CustomPlantAssetPromptAssistant
    ) -> NSView {
        let width: CGFloat = 520
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.frame = NSRect(x: 0, y: 0, width: width, height: 360)

        let header = customPlantStudioHeader(kind: kind, assistant: assistant)
        root.addArrangedSubview(header)
        root.addArrangedSubview(customPlantFormCard(
            kind: kind,
            nameField: nameField,
            descriptionTextView: descriptionTextView,
            assistant: assistant
        ))
        root.addArrangedSubview(customPlantStudioFooter())

        for view in root.arrangedSubviews {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalToConstant: width).isActive = true
        }

        return root
    }

    private func customPlantStudioHeader(
        kind: PlantKind,
        assistant: CustomPlantAssetPromptAssistant
    ) -> NSView {
        let iconTile = NSView()
        iconTile.wantsLayer = true
        iconTile.layer?.cornerRadius = 14
        iconTile.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.16).cgColor
        iconTile.translatesAutoresizingMaskIntoConstraints = false
        iconTile.widthAnchor.constraint(equalToConstant: 52).isActive = true
        iconTile.heightAnchor.constraint(equalToConstant: 52).isActive = true
        iconTile.toolTip = "\(kind.displayName) asset"

        let imageView = NSImageView()
        imageView.image = NSImage(
            systemSymbolName: plantKindSymbolName(for: kind),
            accessibilityDescription: kind.displayName
        )
        imageView.symbolConfiguration = .init(pointSize: 24, weight: .semibold)
        imageView.contentTintColor = .systemGreen
        imageView.translatesAutoresizingMaskIntoConstraints = false
        iconTile.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor)
        ])

        let title = customPlantLabel(
            "AI Plant Studio",
            font: .systemFont(ofSize: 17, weight: .semibold),
            color: .labelColor
        )
        let subtitle = customPlantLabel(
            "New \(kind.displayName.lowercased()) asset - OpenAI PNG",
            font: .systemFont(ofSize: 12, weight: .medium),
            color: .secondaryLabelColor
        )
        subtitle.toolTip = "The generated plant is saved as a reusable PNG asset."

        let textStack = NSStackView(views: [title, subtitle])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3

        let exampleButton = NSButton(
            title: "Use Example",
            target: assistant,
            action: #selector(CustomPlantAssetPromptAssistant.useStarterDescription(_:))
        )
        exampleButton.bezelStyle = .rounded
        exampleButton.controlSize = .small
        exampleButton.font = .systemFont(ofSize: 12, weight: .medium)
        exampleButton.image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "Use Example")
        exampleButton.imagePosition = .imageLeading
        exampleButton.toolTip = CustomPlantAssetPromptStudio.useExampleTooltip

        let header = NSStackView(views: [iconTile, textStack, flexibleSpacerView(), exampleButton])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12
        header.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        header.translatesAutoresizingMaskIntoConstraints = false
        header.heightAnchor.constraint(equalToConstant: 56).isActive = true
        return header
    }

    private func customPlantFormCard(
        kind: PlantKind,
        nameField: NSTextField,
        descriptionTextView: NSTextView,
        assistant: CustomPlantAssetPromptAssistant
    ) -> NSView {
        let card = NSStackView()
        card.orientation = .vertical
        card.alignment = .leading
        card.spacing = 9
        card.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        card.wantsLayer = true
        card.layer?.cornerRadius = 14
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.72).cgColor

        let nameLabel = customPlantEyebrow("DISPLAY NAME")
        let descriptionLabel = customPlantEyebrow("DESCRIPTION")

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 492, height: 112))
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = descriptionTextView
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 9
        scrollView.layer?.masksToBounds = true
        scrollView.toolTip = CustomPlantAssetPromptStudio.descriptionTooltip

        let helperRow = NSStackView()
        helperRow.orientation = .horizontal
        helperRow.alignment = .centerY
        helperRow.spacing = 6
        for fragment in CustomPlantAssetPromptStudio.fragments(for: kind) {
            helperRow.addArrangedSubview(customPlantPromptChip(fragment, assistant: assistant))
        }

        let helperLabel = customPlantLabel(
            "Prompt helpers",
            font: .systemFont(ofSize: 11, weight: .medium),
            color: .secondaryLabelColor
        )

        let views: [NSView] = [
            nameLabel,
            nameField,
            descriptionLabel,
            scrollView,
            helperLabel,
            helperRow
        ]
        for view in views {
            card.addArrangedSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalToConstant: 492).isActive = true
        }

        nameField.heightAnchor.constraint(equalToConstant: 28).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 112).isActive = true
        card.translatesAutoresizingMaskIntoConstraints = false
        card.heightAnchor.constraint(equalToConstant: 250).isActive = true
        return card
    }

    private func customPlantStudioFooter() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6

        for rule in CustomPlantAssetPromptStudio.assetRules {
            row.addArrangedSubview(customPlantRulePill(rule))
        }
        row.addArrangedSubview(flexibleSpacerView())

        let privacy = customPlantLabel(
            "Uses your saved OpenAI key for this generation only.",
            font: .systemFont(ofSize: 11),
            color: .tertiaryLabelColor
        )
        privacy.toolTip = "Your API key stays in macOS Keychain."
        row.addArrangedSubview(privacy)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 26).isActive = true
        return row
    }

    private func customPlantPromptChip(
        _ fragment: CustomPlantAssetPromptFragment,
        assistant: CustomPlantAssetPromptAssistant
    ) -> NSButton {
        let button = CustomPlantAssetPromptButton(
            title: fragment.title,
            target: assistant,
            action: #selector(CustomPlantAssetPromptAssistant.insertPromptFragment(_:))
        )
        button.promptInsertion = fragment.insertion
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = .systemFont(ofSize: 11, weight: .medium)
        button.image = NSImage(systemSymbolName: "plus", accessibilityDescription: fragment.title)
        button.imagePosition = .imageLeading
        button.toolTip = fragment.tooltip
        return button
    }

    private func customPlantRulePill(_ title: String) -> NSView {
        let label = customPlantLabel(
            title,
            font: .systemFont(ofSize: 11, weight: .medium),
            color: .secondaryLabelColor
        )
        label.alignment = .center

        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 7
        container.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.16).cgColor
        container.toolTip = "Generation guardrail: \(title)"
        container.translatesAutoresizingMaskIntoConstraints = false
        container.widthAnchor.constraint(equalToConstant: max(58, CGFloat(title.count * 8 + 18))).isActive = true
        container.heightAnchor.constraint(equalToConstant: 22).isActive = true
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }

    private func customPlantEyebrow(_ text: String) -> NSTextField {
        let label = customPlantLabel(
            text,
            font: .systemFont(ofSize: 10, weight: .semibold),
            color: .tertiaryLabelColor
        )
        return label
    }

    private func customPlantLabel(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        return label
    }

    private func flexibleSpacerView() -> NSView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        spacer.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        return spacer
    }

    private func plantKindSymbolName(for kind: PlantKind) -> String {
        switch kind {
        case .flower:
            return "camera.macro"
        case .foliage:
            return "leaf.fill"
        case .tree:
            return "tree.fill"
        case .meadow:
            return "leaf.circle.fill"
        case .edible:
            return "carrot.fill"
        }
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func restorePreviousWallpaper() {
        wallpaperManager.restorePreviousWallpapers()
    }

    @objc private func resetGarden() {
        let alert = NSAlert()
        alert.messageText = "Reset this scene's garden?"
        alert.informativeText = "All plants in the active scene are replaced with the default garden. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset Garden")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        store.resetGarden(screenCount: targetScreens().count)
        store.removePlantsWithoutDisplayableAssets()
    }

    @objc private func startPlantsFromSeedlings() {
        guard store.state.settings.experienceMode == .garden else {
            return
        }

        store.resetPlantsToNascentGrowthInCurrentScene()
    }

    @objc private func deleteAllPlantsInScene() {
        let alert = NSAlert()
        alert.messageText = "Delete all plants in this scene?"
        alert.informativeText = "This only clears the active wallpaper scene. Other scenes keep their saved plant placements."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete Plants")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        store.removeAllPlantsInCurrentScene()
    }

    @objc private func arrangeGarden() {
        store.arrangeGarden(screenCount: targetScreens().count)
    }

    private var promptHistoryStore: GardenAIPromptHistoryStore {
        GardenAIPromptHistoryStore(directoryURL: store.persistence.directoryURL)
    }

    private func targetScreens() -> [NSScreen] {
        let screens = NSScreen.screens
        switch store.state.settings.displayBehavior {
        case .mirrorAllDisplays:
            return screens
        case .mainDisplayOnly:
            return [NSScreen.main ?? screens.first].compactMap { $0 }
        }
    }

    @objc private func quit() {
        store.save()
        NSApplication.shared.terminate(nil)
    }
}

private extension GardenStatusMenu {
    func menuWillOpen(_ menu: NSMenu) {
        isMenuVisible = true
        if lastRenderedExperienceMode != store.state.settings.experienceMode
            || lastRenderedAssistantMenuItemEnabled != store.state.settings.isAssistantMenuItemEnabled {
            buildMenu()
        }
        updateDynamicItems()
        refreshPlantingMenus()
        refreshRoomStudioMenus()
        refreshWallpaperScenesMenu()
        refreshSeedPouchMenu()
        let harvestInsight = GardenGameLoopInsights(state: store.state, sceneKey: store.activeSceneKey).harvest
        harvestCropsItem.isHidden = harvestInsight.readyCropCount == 0
        harvestCropsItem.title = harvestInsight.menuTitle
        harvestCropsItem.toolTip = harvestInsight.summary
        applyStatusMenuTooltipPolicy()
        NotificationCenter.default.post(name: .gardenStatusMenuWillOpen, object: self)
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuVisible = false
        NotificationCenter.default.post(name: .gardenStatusMenuDidClose, object: self)
    }
}
