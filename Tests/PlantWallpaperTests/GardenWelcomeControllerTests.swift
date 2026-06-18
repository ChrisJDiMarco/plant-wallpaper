import Testing
@testable import PlantWallpaper

@Suite("Garden welcome tour")
struct GardenWelcomeControllerTests {
    @Test("welcome carousel covers the major app surfaces")
    func welcomeCarouselCoversMajorAppSurfaces() {
        let slides = GardenWelcomeSlide.catalog
        let text = slides
            .flatMap { slide in
                [slide.id, slide.title, slide.body] + slide.features.flatMap { [$0.title, $0.detail] }
            }
            .joined(separator: " ")
            .lowercased()

        #expect(slides.count >= 8)
        for phrase in [
            "click",
            "drag",
            "double-click",
            "harvest",
            "seeds",
            "focus",
            "ai",
            "room studio",
            "cat",
            "radio",
            "gnome",
            "weather",
            "screen saver",
            "storage",
            "privacy",
            // Callouts added so new users are not left confused.
            "lock",
            "menu bar",
            "key",
            "pro",
            "input monitoring"
        ] {
            #expect(text.contains(phrase), "Welcome tour should mention \(phrase)")
        }
    }

    @Test("each welcome slide stays scannable")
    func eachWelcomeSlideStaysScannable() {
        for slide in GardenWelcomeSlide.catalog {
            #expect((3...4).contains(slide.features.count))
            #expect(slide.title.count <= 56)
            #expect(slide.body.count <= 200)
            for feature in slide.features {
                #expect(feature.title.count <= 26)
                #expect(feature.detail.count <= 150)
            }
        }
    }

    @Test("every slide pairs copy with an illustration")
    func everySlidePairsCopyWithIllustration() {
        // The redesigned tour leads each slide with a crafted hero illustration.
        let artworks = GardenWelcomeSlide.catalog.map(\.artwork)
        #expect(artworks.count == GardenWelcomeSlide.catalog.count)
        #expect(Set(GardenWelcomeSlide.catalog.map(\.id)).count == GardenWelcomeSlide.catalog.count)
    }
}
