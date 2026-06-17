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

        #expect(slides.count >= 6)
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
            "privacy"
        ] {
            #expect(text.contains(phrase), "Welcome tour should mention \(phrase)")
        }
    }

    @Test("each welcome slide stays scannable")
    func eachWelcomeSlideStaysScannable() {
        for slide in GardenWelcomeSlide.catalog {
            #expect(slide.features.count == 3)
            #expect(slide.title.count <= 56)
            #expect(slide.body.count <= 190)
            for feature in slide.features {
                #expect(feature.title.count <= 26)
                #expect(feature.detail.count <= 125)
            }
        }
    }
}
