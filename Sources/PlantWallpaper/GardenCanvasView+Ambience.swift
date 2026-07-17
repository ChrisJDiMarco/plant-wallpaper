import AppKit
import PlantGardenCore

/// Ambient scenery layers: weather (rain, snow, fog), mist,
/// air particles, and the atmosphere gradients drawn behind the plants.
extension GardenCanvasView {
    @MainActor private static let rainforestCanvasBackdropImage: NSImage? = {
        let key = GardenExperienceModeScenePolicy.rainforestCanvasSceneKey
        let url = Bundle.appResources.url(forResource: key, withExtension: "png", subdirectory: "SceneAssets")
            ?? Bundle.appResources.url(forResource: key, withExtension: "png")
        guard let url,
        let image = NSImage(contentsOf: url) else {
            return nil
        }

        image.cacheMode = .always
        return image
    }()

    func drawRainforestCanvasBackdrop(profile: GardenSceneVisualProfile) {
        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        let rect = NSRect(origin: .zero, size: bounds.size)
        if let image = Self.rainforestCanvasBackdropImage {
            drawRainforestCanvasImage(image, in: rect)
            return
        } else {
            NSGradient(colors: [
                color(red: 196, green: 222, blue: 225, alpha: 1.00),
                color(red: 226, green: 235, blue: 211, alpha: 1.00),
                color(red: 196, green: 213, blue: 179, alpha: 1.00)
            ])?.draw(in: rect, angle: -90)
        }

        NSGradient(colors: [
            color(red: 255, green: 246, blue: 205, alpha: 0.22),
            color(red: 255, green: 246, blue: 205, alpha: 0.00)
        ])?.draw(
            in: NSRect(x: bounds.width * 0.30, y: 0, width: bounds.width * 0.50, height: bounds.height * 0.58),
            angle: -72
        )

        for index in 0..<5 {
            let fraction = CGFloat(index) / 4
            let y = bounds.height * (0.12 + fraction * 0.15)
            let height = bounds.height * (0.10 + fraction * 0.025)
            NSGradient(colors: [
                color(red: 234, green: 240, blue: 223, alpha: 0),
                color(red: 234, green: 240, blue: 223, alpha: CGFloat(profile.mistOpacity) * (0.18 + fraction * 0.08)),
                color(red: 234, green: 240, blue: 223, alpha: 0)
            ])?.draw(
                in: NSRect(x: -bounds.width * 0.08, y: y, width: bounds.width * 1.16, height: height),
                angle: 0
            )
        }

        color(red: 33, green: 67, blue: 47, alpha: 0.045).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: bounds.height * 0.83, width: bounds.width, height: bounds.height * 0.17)).fill()
    }

    private func drawRainforestCanvasImage(_ image: NSImage, in rect: NSRect) {
        let sourceSize = image.size
        let sourceAspect = sourceSize.width / max(1, sourceSize.height)
        let targetAspect = rect.width / max(1, rect.height)
        let sourceRect: NSRect

        if targetAspect > sourceAspect {
            let cropHeight = sourceSize.width / targetAspect
            sourceRect = NSRect(
                x: 0,
                y: (sourceSize.height - cropHeight) / 2,
                width: sourceSize.width,
                height: cropHeight
            )
        } else {
            let cropWidth = sourceSize.height * targetAspect
            sourceRect = NSRect(
                x: (sourceSize.width - cropWidth) / 2,
                y: 0,
                width: cropWidth,
                height: sourceSize.height
            )
        }

        image.draw(
            in: rect,
            from: sourceRect,
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    // MARK: - Weather overlay

    /// Draws real-world weather over the garden: rain streaks, drifting snow,
    /// or fog banks. Motion derives deterministically from wall-clock time so
    /// no per-frame state is needed (matching how wind sway is animated).
    func drawWeatherOverlay(profile: GardenSceneVisualProfile) {
        guard let weather = store.state.weather,
              !weather.isStale(),
              bounds.width > 0,
              bounds.height > 0 else {
            return
        }

        let time = Date().timeIntervalSince1970
        switch weather.kind {
        case .drizzle:
            drawRain(dropCount: 46, speed: 420, time: time, alpha: 0.10)
        case .rain:
            drawRain(dropCount: 110, speed: 560, time: time, alpha: 0.13)
        case .storm:
            color(red: 36, green: 44, blue: 58, alpha: 0.06).setFill()
            bounds.fill(using: .sourceOver)
            drawRain(dropCount: 170, speed: 700, time: time, alpha: 0.16)
        case .snow:
            drawSnow(flakeCount: 70, time: time)
        case .fog:
            drawFogBands(time: time, mistOpacity: CGFloat(profile.mistOpacity))
        case .clear, .partlyCloudy, .overcast:
            break
        }
    }

    func weatherNoise(_ index: Int, _ salt: Double) -> CGFloat {
        let value = sin(Double(index) * 127.1 + salt * 311.7) * 43_758.5453
        return CGFloat(value - value.rounded(.down))
    }

    func drawRain(dropCount: Int, speed: Double, time: TimeInterval, alpha: CGFloat) {
        let slant = CGFloat(store.state.windStrength) * 26 - 8
        let path = NSBezierPath()
        path.lineWidth = 1.1

        for index in 0..<dropCount {
            let laneX = weatherNoise(index, 1) * bounds.width
            let phase = Double(weatherNoise(index, 2))
            let length = 9 + weatherNoise(index, 3) * 8
            let cycle = Double(bounds.height) + 40
            let fallY = (time * speed * (0.82 + phase * 0.36) + phase * cycle)
                .truncatingRemainder(dividingBy: cycle)
            let y = bounds.height + 20 - CGFloat(fallY)
            path.move(to: NSPoint(x: laneX, y: y))
            path.line(to: NSPoint(x: laneX + slant * (length / 22), y: y + length))
        }

        color(red: 198, green: 222, blue: 244, alpha: alpha).setStroke()
        path.stroke()
    }

    func drawSnow(flakeCount: Int, time: TimeInterval) {
        let path = NSBezierPath()
        for index in 0..<flakeCount {
            let laneX = weatherNoise(index, 4) * bounds.width
            let phase = Double(weatherNoise(index, 5))
            let radius = 1.1 + weatherNoise(index, 6) * 1.5
            let cycle = Double(bounds.height) + 30
            let fallY = (time * (34 + phase * 26) + phase * cycle)
                .truncatingRemainder(dividingBy: cycle)
            let flakeOffsetX = CGFloat(sin(time * 0.8 + Double(index))) * 14
            let y = bounds.height + 12 - CGFloat(fallY)
            let rect = NSRect(
                x: laneX + flakeOffsetX - radius,
                y: y - radius,
                width: radius * 2,
                height: radius * 2
            )
            path.appendOval(in: rect)
        }

        color(red: 246, green: 250, blue: 255, alpha: 0.22).setFill()
        path.fill()
    }

    func drawFogBands(time: TimeInterval, mistOpacity: CGFloat) {
        let bandHeight = bounds.height * 0.16
        for band in 0..<3 {
            let offset = CGFloat(sin(time * 0.05 + Double(band) * 2.1)) * bounds.width * 0.04
            let y = bounds.height * (0.18 + CGFloat(band) * 0.24)
            let rect = NSRect(x: -40 + offset, y: y, width: bounds.width + 80, height: bandHeight)
            let alpha = 0.05 + mistOpacity * 0.07 + CGFloat(band) * 0.012
            NSGradient(colors: [
                color(red: 214, green: 222, blue: 228, alpha: 0),
                color(red: 214, green: 222, blue: 228, alpha: alpha),
                color(red: 214, green: 222, blue: 228, alpha: 0)
            ])?.draw(in: rect, angle: 90)
        }
    }

    func drawAtmosphereBehindPlants(profile: GardenSceneVisualProfile) {
        guard bounds.width > 0 && bounds.height > 0 else {
            return
        }

        let sunlight = store.state.sunlightCondition()
        let rect = NSRect(origin: .zero, size: bounds.size)
        let topTint: NSColor
        let bottomTint: NSColor
        let lightIntensity = CGFloat(sunlight.intensity)
        switch sunlight.mood {
        case .morning:
            topTint = color(red: 255, green: 225, blue: 164, alpha: 0.020 + lightIntensity * 0.028 + CGFloat(profile.warmth) * 0.018)
            bottomTint = color(red: 206, green: 230, blue: 196, alpha: 0.010 + lightIntensity * 0.020 + CGFloat(profile.humidity) * 0.014)
        case .bright:
            topTint = color(red: 255, green: 250, blue: 212, alpha: 0.008 + lightIntensity * 0.016 + CGFloat(profile.warmth) * 0.010)
            bottomTint = color(red: 207, green: 226, blue: 203, alpha: 0.006 + lightIntensity * 0.012 + CGFloat(profile.humidity) * 0.010)
        case .golden:
            topTint = color(red: 255, green: 184, blue: 126, alpha: 0.014 + lightIntensity * 0.030 + CGFloat(profile.warmth) * 0.018)
            bottomTint = color(red: 183, green: 187, blue: 214, alpha: 0.008 + lightIntensity * 0.020 + CGFloat(profile.humidity) * 0.010)
        default:
            topTint = color(red: 113, green: 149, blue: 190, alpha: 0.028 + lightIntensity * 0.026 + CGFloat(profile.mistOpacity) * 0.10)
            bottomTint = color(red: 29, green: 47, blue: 58, alpha: 0.018 + lightIntensity * 0.024 + CGFloat(profile.mistOpacity) * 0.070)
        }

        NSGradient(colors: [topTint, bottomTint])?.draw(in: rect, angle: -90)
    }

    func drawSceneMist(profile: GardenSceneVisualProfile) {
        guard profile.mistOpacity > 0.01, bounds.width > 0, bounds.height > 0 else {
            return
        }

        let alpha = CGFloat(profile.mistOpacity)
        let baseY = bounds.height * 0.60
        for layer in 0..<4 {
            let fraction = CGFloat(layer) / 3
            let height = bounds.height * (0.08 + fraction * 0.05)
            let rect = NSRect(
                x: -bounds.width * 0.08,
                y: baseY + fraction * bounds.height * 0.08,
                width: bounds.width * 1.16,
                height: height
            )
            NSGradient(colors: [
                color(red: 228, green: 235, blue: 218, alpha: 0),
                color(red: 228, green: 235, blue: 218, alpha: alpha * (0.10 + fraction * 0.06)),
                color(red: 228, green: 235, blue: 218, alpha: 0)
            ])?.draw(in: rect, angle: 0)
        }

        drawAirParticles(
            alpha: CGFloat(profile.dustMoteOpacity + profile.mistOpacity * 0.18),
            count: max(12, Int(bounds.width / 72))
        )
    }

    func drawAirParticles(alpha: CGFloat, count: Int) {
        guard alpha > 0.006 else {
            return
        }

        let now = Date().timeIntervalSinceReferenceDate
        for index in 0..<count {
            let phase = now * (0.035 + Double(index % 5) * 0.006)
            let x = bounds.width * CGFloat(abs(deterministicWave(seed: 7_101 + Double(index), index: index)) * 0.96 + 0.02)
            let y = bounds.height * CGFloat(0.14 + abs(deterministicWave(seed: 7_317 + phase, index: index)) * 0.54)
            let length = CGFloat(2 + index % 5)
            drawLine(
                from: NSPoint(x: x, y: y),
                to: NSPoint(x: x + length, y: y - length * 0.32),
                color: color(red: 255, green: 247, blue: 206, alpha: alpha * CGFloat(0.28 + Double(index % 4) * 0.10)),
                width: 0.65
            )
        }
    }

    func drawForegroundSceneHaze(profile: GardenSceneVisualProfile) {
        let opacity = CGFloat(max(0, profile.mistOpacity - 0.04))
        guard opacity > 0.005 else {
            return
        }

        let rect = NSRect(x: 0, y: bounds.height * 0.80, width: bounds.width, height: bounds.height * 0.20)
        NSGradient(colors: [
            color(red: 231, green: 228, blue: 202, alpha: 0),
            color(red: 231, green: 228, blue: 202, alpha: opacity * 0.22)
        ])?.draw(in: rect, angle: -90)
    }

}
