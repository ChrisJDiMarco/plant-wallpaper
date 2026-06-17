import AppKit
import QuartzCore

@MainActor
enum GardenBugSprites {
    struct Motion {
        let jitter: CGFloat
        let speed: Double
        let alignsToPath: Bool
    }

    static func containerSize(for species: GardenBugSystem.Species) -> CGFloat {
        switch species {
        case .dragonfly:
            44
        case .blueMorphoButterfly, .monarchButterfly:
            38
        case .whiteButterfly, .moth:
            32
        case .bee, .hoverfly:
            24
        case .firefly:
            18
        }
    }

    static func motion(for species: GardenBugSystem.Species) -> Motion {
        switch species {
        case .dragonfly:
            // Fast and direct: high speed, low jitter so legs read as crisp
            // darts and straight zips rather than a fluttery wander.
            Motion(jitter: 14, speed: 158, alignsToPath: true)
        case .bee, .hoverfly:
            Motion(jitter: 34, speed: 76, alignsToPath: false)
        case .firefly:
            Motion(jitter: 42, speed: 34, alignsToPath: false)
        case .moth:
            Motion(jitter: 52, speed: 42, alignsToPath: false)
        case .blueMorphoButterfly, .monarchButterfly, .whiteButterfly:
            Motion(jitter: 64, speed: 54, alignsToPath: false)
        }
    }

    static func populate(container: CALayer, species: GardenBugSystem.Species, scale: CGFloat) {
        let size = container.bounds.width
        container.sublayers?.forEach { $0.removeFromSuperlayer() }
        switch species {
        case .bee, .hoverfly:
            populateBee(container: container, size: size, isHoverfly: species == .hoverfly)
        case .dragonfly:
            populateDragonfly(container: container, size: size)
        case .firefly:
            populateFirefly(container: container, size: size)
        case .moth:
            populateButterfly(
                container: container,
                size: size,
                leftColor: NSColor(calibratedRed: 0.78, green: 0.72, blue: 0.58, alpha: 0.72),
                rightColor: NSColor(calibratedRed: 0.66, green: 0.62, blue: 0.52, alpha: 0.68),
                bodyColor: NSColor(calibratedRed: 0.32, green: 0.25, blue: 0.20, alpha: 0.86)
            )
        case .whiteButterfly:
            populateButterfly(
                container: container,
                size: size,
                leftColor: NSColor(calibratedWhite: 0.96, alpha: 0.76),
                rightColor: NSColor(calibratedWhite: 0.90, alpha: 0.70),
                bodyColor: NSColor(calibratedRed: 0.32, green: 0.30, blue: 0.23, alpha: 0.84)
            )
        case .blueMorphoButterfly:
            populateButterfly(
                container: container,
                size: size,
                leftColor: NSColor(calibratedRed: 0.12, green: 0.54, blue: 0.95, alpha: 0.72),
                rightColor: NSColor(calibratedRed: 0.06, green: 0.38, blue: 0.78, alpha: 0.68),
                bodyColor: NSColor(calibratedRed: 0.10, green: 0.17, blue: 0.28, alpha: 0.88)
            )
        case .monarchButterfly:
            populateButterfly(
                container: container,
                size: size,
                leftColor: NSColor(calibratedRed: 0.95, green: 0.42, blue: 0.12, alpha: 0.76),
                rightColor: NSColor(calibratedRed: 0.86, green: 0.30, blue: 0.08, alpha: 0.72),
                bodyColor: NSColor(calibratedRed: 0.10, green: 0.08, blue: 0.06, alpha: 0.90)
            )
        }
    }

    static func applyBehavior(
        _ behavior: GardenBugSystem.BehaviorKind,
        to container: CALayer,
        species: GardenBugSystem.Species
    ) {
        container.removeAnimation(forKey: "behaviorBob")
        container.removeAnimation(forKey: "behaviorTurn")
        container.sublayers?.forEach { layer in
            layer.removeAnimation(forKey: "forage")
            layer.removeAnimation(forKey: "restOpacity")
        }

        switch behavior {
        case .nectarFeed:
            addBodyBob(to: container, distance: species == .bee ? 1.8 : 1.2, duration: 0.34)
            container.sublayers?.first(where: { $0.name == "head" })?.add(forageAnimation(), forKey: "forage")
        case .plantVisit:
            addBodyBob(to: container, distance: 2.6, duration: 0.46)
        case .leafRest:
            addRestStillness(to: container)
        case .bask:
            if species == .dragonfly {
                // Crisp hover: hang nearly still with a fast wing-hum and a
                // micro yaw, the way a darner pins itself in mid-air.
                addBodyBob(to: container, distance: 0.45, duration: 0.15)
                addSlowTurn(to: container, amplitude: 0.05, duration: 1.6)
            } else {
                addBodyBob(to: container, distance: 0.7, duration: 1.4)
                addSlowTurn(to: container, amplitude: 0.10, duration: 3.2)
            }
        case .groom:
            addSlowTurn(to: container, amplitude: 0.16, duration: 0.9)
            container.sublayers?.filter { $0.name == "foreleg" }.forEach {
                $0.add(forageAnimation(), forKey: "forage")
            }
        case .patrol:
            // Dragonfly: a tight, fast hover-hum rather than a wide bob.
            addBodyBob(to: container, distance: species == .dragonfly ? 0.5 : 2.0, duration: species == .dragonfly ? 0.16 : 0.32)
        case .glowDrift:
            addBodyBob(to: container, distance: 3.0, duration: 1.8)
        case .travel:
            addBodyBob(to: container, distance: species == .dragonfly ? 0.4 : 2.4, duration: species == .dragonfly ? 0.14 : (species == .bee ? 0.18 : 0.42))
        }
    }

    private static func populateButterfly(
        container: CALayer,
        size: CGFloat,
        leftColor: NSColor,
        rightColor: NSColor,
        bodyColor: NSColor
    ) {
        let center = CGPoint(x: size / 2, y: size / 2)
        let leftWing = wingLayer(
            frame: CGRect(x: size * 0.04, y: size * 0.16, width: size * 0.46, height: size * 0.62),
            color: leftColor,
            mirrored: false
        )
        let rightWing = wingLayer(
            frame: CGRect(x: size * 0.50, y: size * 0.16, width: size * 0.46, height: size * 0.62),
            color: rightColor,
            mirrored: true
        )
        let body = ovalLayer(
            frame: CGRect(x: center.x - size * 0.045, y: size * 0.24, width: size * 0.09, height: size * 0.52),
            color: bodyColor
        )
        leftWing.anchorPoint = CGPoint(x: 1, y: 0.5)
        leftWing.position = CGPoint(x: size * 0.50, y: size * 0.47)
        rightWing.anchorPoint = CGPoint(x: 0, y: 0.5)
        rightWing.position = CGPoint(x: size * 0.50, y: size * 0.47)
        container.addSublayer(leftWing)
        container.addSublayer(rightWing)
        container.addSublayer(body)
        body.name = "body"
        addButterflyWingDetails(to: leftWing, mirrored: false, speciesSize: size)
        addButterflyWingDetails(to: rightWing, mirrored: true, speciesSize: size)
        addAntennae(to: container, center: CGPoint(x: center.x, y: size * 0.28), size: size, color: bodyColor.withAlphaComponent(0.74))
        addTinyEyes(to: container, center: CGPoint(x: center.x, y: size * 0.25), size: size * 0.09)
        addWingFlap(to: leftWing, keyPath: "transform.rotation.y", amplitude: -0.72, duration: 0.34)
        addWingFlap(to: rightWing, keyPath: "transform.rotation.y", amplitude: 0.72, duration: 0.34)
    }

    private static func populateBee(container: CALayer, size: CGFloat, isHoverfly: Bool) {
        let wingColor = NSColor(calibratedWhite: 0.96, alpha: 0.46)
        let bodyColor = isHoverfly
            ? NSColor(calibratedRed: 0.52, green: 0.43, blue: 0.19, alpha: 0.90)
            : NSColor(calibratedRed: 0.85, green: 0.58, blue: 0.12, alpha: 0.94)
        let body = ovalLayer(
            frame: CGRect(x: size * 0.26, y: size * 0.35, width: size * 0.48, height: size * 0.30),
            color: bodyColor
        )
        body.name = "body"
        body.borderColor = NSColor(calibratedRed: 0.12, green: 0.10, blue: 0.06, alpha: 0.52).cgColor
        body.borderWidth = 1
        for fraction in [0.38, 0.50, 0.62] {
            body.addSublayer(stripeLayer(
                frame: CGRect(x: body.bounds.width * fraction, y: 0, width: max(1, size * 0.035), height: body.bounds.height),
                color: NSColor(calibratedRed: 0.08, green: 0.07, blue: 0.05, alpha: isHoverfly ? 0.32 : 0.62)
            ))
        }
        let head = ovalLayer(
            frame: CGRect(x: size * 0.18, y: size * 0.39, width: size * 0.16, height: size * 0.20),
            color: NSColor(calibratedRed: 0.14, green: 0.10, blue: 0.06, alpha: 0.86)
        )
        head.name = "head"
        let leftWing = ovalLayer(
            frame: CGRect(x: size * 0.18, y: size * 0.18, width: size * 0.30, height: size * 0.26),
            color: wingColor
        )
        leftWing.name = "wing"
        let rightWing = ovalLayer(
            frame: CGRect(x: size * 0.52, y: size * 0.18, width: size * 0.30, height: size * 0.26),
            color: wingColor
        )
        rightWing.name = "wing"
        addInsectLegs(to: container, bodyFrame: body.frame, color: NSColor(calibratedRed: 0.10, green: 0.08, blue: 0.05, alpha: 0.50), size: size)
        addAntennae(to: container, center: CGPoint(x: size * 0.25, y: size * 0.40), size: size * 0.55, color: NSColor(calibratedRed: 0.10, green: 0.08, blue: 0.05, alpha: 0.58))
        addPollenBaskets(to: container, bodyFrame: body.frame, size: size, isHoverfly: isHoverfly)
        container.addSublayer(leftWing)
        container.addSublayer(rightWing)
        container.addSublayer(body)
        container.addSublayer(head)
        addWingFlap(to: leftWing, keyPath: "transform.scale.y", amplitude: 0.28, duration: 0.09)
        addWingFlap(to: rightWing, keyPath: "transform.scale.y", amplitude: 0.28, duration: 0.09)
    }

    /// Per-instance abdomen colorways for the darner — picked at random so a
    /// swarm reads as a mix of common species rather than identical clones.
    private struct DragonflyColorway {
        let abdomenTop: NSColor      // bright dorsal band color
        let abdomenBottom: NSColor   // darker tail / ventral shade
        let bandTint: NSColor        // segment-joint banding accent
        let thorax: NSColor
        let eye: NSColor
        let wingSheen: NSColor       // iridescent membrane tint
    }

    private static let dragonflyColorways: [DragonflyColorway] = [
        // Common blue darner — electric teal-blue.
        DragonflyColorway(
            abdomenTop: NSColor(calibratedRed: 0.18, green: 0.62, blue: 0.86, alpha: 0.95),
            abdomenBottom: NSColor(calibratedRed: 0.07, green: 0.24, blue: 0.40, alpha: 0.95),
            bandTint: NSColor(calibratedRed: 0.02, green: 0.10, blue: 0.16, alpha: 0.42),
            thorax: NSColor(calibratedRed: 0.14, green: 0.42, blue: 0.40, alpha: 0.94),
            eye: NSColor(calibratedRed: 0.16, green: 0.58, blue: 0.78, alpha: 0.92),
            wingSheen: NSColor(calibratedRed: 0.62, green: 0.86, blue: 1.00, alpha: 0.10)
        ),
        // Emerald / green darner.
        DragonflyColorway(
            abdomenTop: NSColor(calibratedRed: 0.22, green: 0.66, blue: 0.40, alpha: 0.95),
            abdomenBottom: NSColor(calibratedRed: 0.08, green: 0.26, blue: 0.18, alpha: 0.95),
            bandTint: NSColor(calibratedRed: 0.02, green: 0.12, blue: 0.08, alpha: 0.42),
            thorax: NSColor(calibratedRed: 0.16, green: 0.46, blue: 0.30, alpha: 0.94),
            eye: NSColor(calibratedRed: 0.24, green: 0.62, blue: 0.46, alpha: 0.92),
            wingSheen: NSColor(calibratedRed: 0.70, green: 1.00, blue: 0.84, alpha: 0.10)
        ),
        // Amber / golden-winged skimmer.
        DragonflyColorway(
            abdomenTop: NSColor(calibratedRed: 0.86, green: 0.58, blue: 0.20, alpha: 0.95),
            abdomenBottom: NSColor(calibratedRed: 0.40, green: 0.20, blue: 0.06, alpha: 0.95),
            bandTint: NSColor(calibratedRed: 0.16, green: 0.08, blue: 0.02, alpha: 0.42),
            thorax: NSColor(calibratedRed: 0.50, green: 0.34, blue: 0.14, alpha: 0.94),
            eye: NSColor(calibratedRed: 0.66, green: 0.46, blue: 0.18, alpha: 0.92),
            wingSheen: NSColor(calibratedRed: 1.00, green: 0.88, blue: 0.62, alpha: 0.12)
        )
    ]

    private static func populateDragonfly(container: CALayer, size: CGFloat) {
        let colorway = dragonflyColorways.randomElement() ?? dragonflyColorways[0]
        let center = size / 2

        // Four membranous wings held outstretched: fore pair (upper, narrower)
        // and hind pair (lower, broader at the base). Built leading-edge-up so
        // veins, sheen, and the pterostigma all read like a real darner.
        let wingSpecs: [(frame: CGRect, mirrored: Bool, isHind: Bool)] = [
            // Fore pair — slimmer, swept slightly forward.
            (CGRect(x: size * 0.02, y: size * 0.30, width: size * 0.46, height: size * 0.165), false, false),
            (CGRect(x: size * 0.52, y: size * 0.30, width: size * 0.46, height: size * 0.165), true, false),
            // Hind pair — broader base, set just below.
            (CGRect(x: size * 0.00, y: size * 0.49, width: size * 0.48, height: size * 0.205), false, true),
            (CGRect(x: size * 0.52, y: size * 0.49, width: size * 0.48, height: size * 0.205), true, true)
        ]
        for spec in wingSpecs {
            let wing = dragonflyWingLayer(
                frame: spec.frame,
                mirrored: spec.mirrored,
                isHind: spec.isHind,
                sheen: colorway.wingSheen,
                size: size
            )
            // Very fast, low-amplitude beat → reads as a blur, like a real
            // darner. Fore and hind pairs beat slightly out of phase, and the
            // hind pair sweeps a touch wider. Wings pivot at the root.
            let amplitude: CGFloat = (spec.isHind ? 0.16 : 0.13) * (spec.mirrored ? -1 : 1)
            let duration: CFTimeInterval = spec.isHind ? 0.052 : 0.046
            addWingFlap(to: wing, keyPath: "transform.rotation.z", amplitude: amplitude, duration: duration)
            container.addSublayer(wing)
        }

        // Robust thorax just behind the head — the flight-muscle block.
        let thorax = ovalLayer(
            frame: CGRect(x: center - size * 0.075, y: size * 0.50, width: size * 0.15, height: size * 0.21),
            color: colorway.thorax
        )
        thorax.name = "thorax"
        thorax.shadowColor = NSColor.black.cgColor
        thorax.shadowOpacity = 0.28
        thorax.shadowRadius = size * 0.03
        thorax.shadowOffset = CGSize(width: 0, height: -size * 0.01)
        addThoraxSheen(to: thorax, highlight: colorway.abdomenTop)
        container.addSublayer(thorax)

        // Long, slender, segmented abdomen tapering to the tail.
        let abdomen = dragonflyAbdomenLayer(
            frame: CGRect(x: center - size * 0.055, y: size * 0.06, width: size * 0.11, height: size * 0.46),
            colorway: colorway,
            size: size
        )
        container.addSublayer(abdomen)

        // Large head dominated by two bulbous compound eyes that nearly meet.
        addDragonflyHead(to: container, center: CGPoint(x: center, y: size * 0.74), size: size, colorway: colorway)
    }

    /// One membranous darner wing: a long narrow blade with a faint iridescent
    /// gradient sheen, a fine vein network, and a dark pterostigma cell near
    /// the leading-edge tip. Anchored at the wing root so flaps pivot correctly.
    private static func dragonflyWingLayer(
        frame: CGRect,
        mirrored: Bool,
        isHind: Bool,
        sheen: NSColor,
        size: CGFloat
    ) -> CAShapeLayer {
        let wing = CAShapeLayer()
        wing.frame = frame
        wing.name = "wing"
        let w = frame.width
        let h = frame.height
        // Root is the inner edge (toward the body); tip is the outer edge.
        let rootX: CGFloat = mirrored ? 0 : w
        let tipX: CGFloat = mirrored ? w : 0
        let leadY = h * 0.10                       // leading (upper) edge
        let trailY = h * (isHind ? 0.94 : 0.90)    // trailing (lower) edge
        let baseBulge: CGFloat = isHind ? 0.62 : 0.46

        let path = CGMutablePath()
        path.move(to: CGPoint(x: rootX, y: h * 0.50))
        // Leading edge: nearly straight to a rounded tip.
        path.addCurve(
            to: CGPoint(x: tipX, y: leadY),
            control1: CGPoint(x: rootX + (tipX - rootX) * 0.35, y: leadY * 0.6),
            control2: CGPoint(x: rootX + (tipX - rootX) * 0.82, y: leadY)
        )
        // Rounded outer tip.
        path.addQuadCurve(
            to: CGPoint(x: tipX, y: trailY),
            control: CGPoint(x: tipX + (rootX - tipX) * -0.04, y: h * 0.50)
        )
        // Trailing edge: bulges near the base (broader for the hind wing).
        path.addCurve(
            to: CGPoint(x: rootX, y: h * 0.50),
            control1: CGPoint(x: rootX + (tipX - rootX) * 0.82, y: trailY),
            control2: CGPoint(x: rootX + (tipX - rootX) * 0.20, y: h * (0.50 + baseBulge * 0.5))
        )
        wing.path = path

        wing.fillColor = NSColor(calibratedRed: 0.86, green: 0.95, blue: 1.0, alpha: 0.14).cgColor
        wing.strokeColor = NSColor(calibratedWhite: 0.18, alpha: 0.22).cgColor
        wing.lineWidth = max(0.5, size * 0.012)

        // Iridescent sheen: a gradient clipped to the wing silhouette.
        let gradient = CAGradientLayer()
        gradient.frame = wing.bounds
        gradient.colors = [
            sheen.withAlphaComponent(0.02).cgColor,
            sheen.cgColor,
            sheen.withAlphaComponent(0.04).cgColor
        ]
        gradient.locations = [0.0, 0.45, 1.0]
        gradient.startPoint = CGPoint(x: mirrored ? 0 : 1, y: 0)
        gradient.endPoint = CGPoint(x: mirrored ? 1 : 0, y: 1)
        let mask = CAShapeLayer()
        mask.path = path
        mask.fillColor = NSColor.white.cgColor
        gradient.mask = mask
        wing.addSublayer(gradient)

        addDragonflyWingVeins(to: wing, color: NSColor(calibratedWhite: 1.0, alpha: 0.22))

        // Pterostigma: a small dark cell near the leading-edge tip.
        let stigmaW = w * 0.10
        let stigmaH = h * 0.16
        let stigmaX = mirrored ? (w * 0.82 - stigmaW / 2) : (w * 0.18 - stigmaW / 2)
        let stigma = ovalLayer(
            frame: CGRect(x: stigmaX, y: leadY + h * 0.02, width: stigmaW, height: stigmaH),
            color: NSColor(calibratedRed: 0.20, green: 0.16, blue: 0.10, alpha: 0.62)
        )
        stigma.cornerRadius = min(stigmaW, stigmaH) * 0.32
        wing.addSublayer(stigma)

        // Pivot at the wing root so the flap rotates from the thorax.
        wing.anchorPoint = CGPoint(x: mirrored ? 0 : 1, y: 0.5)
        wing.position = CGPoint(x: frame.minX + (mirrored ? 0 : w), y: frame.midY)
        return wing
    }

    /// Slender segmented abdomen with iridescent dorsal banding, tapering to
    /// the tail. Eight visible segments separated by dark joints.
    private static func dragonflyAbdomenLayer(
        frame: CGRect,
        colorway: DragonflyColorway,
        size: CGFloat
    ) -> CALayer {
        let abdomen = CALayer()
        abdomen.frame = frame
        abdomen.name = "body"
        abdomen.cornerRadius = frame.width * 0.5
        abdomen.masksToBounds = true

        // Base dorsal gradient: bright at the thorax end, dark at the tail.
        let gradient = CAGradientLayer()
        gradient.frame = abdomen.bounds
        gradient.colors = [
            colorway.abdomenBottom.cgColor,
            colorway.abdomenTop.cgColor
        ]
        gradient.locations = [0.0, 1.0]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.0)   // tail (low y)
        gradient.endPoint = CGPoint(x: 0.5, y: 1.0)     // thorax (high y)
        abdomen.addSublayer(gradient)

        // Lateral shading so the cylinder reads as round, not flat.
        let sideShade = CAGradientLayer()
        sideShade.frame = abdomen.bounds
        sideShade.colors = [
            NSColor(calibratedWhite: 0.0, alpha: 0.30).cgColor,
            NSColor(calibratedWhite: 1.0, alpha: 0.14).cgColor,
            NSColor(calibratedWhite: 0.0, alpha: 0.30).cgColor
        ]
        sideShade.locations = [0.0, 0.42, 1.0]
        sideShade.startPoint = CGPoint(x: 0.0, y: 0.5)
        sideShade.endPoint = CGPoint(x: 1.0, y: 0.5)
        abdomen.addSublayer(sideShade)

        // Eight segment joints — thin dark bands across the abdomen.
        let segments = 8
        let h = frame.height
        for index in 1..<segments {
            let y = h * CGFloat(index) / CGFloat(segments)
            let joint = stripeLayer(
                frame: CGRect(x: 0, y: y - max(0.4, size * 0.006), width: frame.width, height: max(0.8, size * 0.012)),
                color: colorway.bandTint
            )
            joint.cornerRadius = 0
            abdomen.addSublayer(joint)
        }
        return abdomen
    }

    /// Big darner head: two bulbous compound eyes that nearly meet on top,
    /// plus a small face/frons between them.
    private static func addDragonflyHead(
        to container: CALayer,
        center: CGPoint,
        size: CGFloat,
        colorway: DragonflyColorway
    ) {
        let eyeR = size * 0.14
        let frons = ovalLayer(
            frame: CGRect(x: center.x - size * 0.085, y: center.y - size * 0.07, width: size * 0.17, height: size * 0.13),
            color: NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.18, alpha: 0.90)
        )
        frons.name = "head"
        container.addSublayer(frons)

        for xSign in [-1.0, 1.0] {
            let cx = center.x + CGFloat(xSign) * eyeR * 0.62
            let eye = ovalLayer(
                frame: CGRect(x: cx - eyeR, y: center.y - eyeR, width: eyeR * 2, height: eyeR * 2),
                color: colorway.eye
            )
            eye.name = "eye"
            // Compound-eye facet shading + a bright specular highlight.
            let shade = CAGradientLayer()
            shade.frame = eye.bounds
            shade.type = .radial
            shade.colors = [
                NSColor(calibratedWhite: 1.0, alpha: 0.40).cgColor,
                colorway.eye.cgColor,
                NSColor(calibratedWhite: 0.0, alpha: 0.34).cgColor
            ]
            shade.locations = [0.0, 0.55, 1.0]
            shade.startPoint = CGPoint(x: 0.36, y: 0.70)
            shade.endPoint = CGPoint(x: 1.0, y: 0.0)
            shade.cornerRadius = eyeR
            shade.masksToBounds = true
            eye.addSublayer(shade)
            eye.addSublayer(ovalLayer(
                frame: CGRect(x: eyeR * 0.42, y: eyeR * 1.06, width: eyeR * 0.5, height: eyeR * 0.5),
                color: NSColor(calibratedWhite: 1.0, alpha: 0.72)
            ))
            container.addSublayer(eye)
        }
    }

    private static func addThoraxSheen(to thorax: CALayer, highlight: NSColor) {
        let sheen = CAGradientLayer()
        sheen.frame = thorax.bounds
        sheen.colors = [
            highlight.withAlphaComponent(0.30).cgColor,
            NSColor(calibratedWhite: 0.0, alpha: 0.0).cgColor,
            NSColor(calibratedWhite: 0.0, alpha: 0.26).cgColor
        ]
        sheen.locations = [0.0, 0.5, 1.0]
        sheen.startPoint = CGPoint(x: 0.2, y: 1.0)
        sheen.endPoint = CGPoint(x: 0.85, y: 0.0)
        sheen.cornerRadius = thorax.cornerRadius
        sheen.masksToBounds = true
        thorax.addSublayer(sheen)
    }

    private static func populateFirefly(container: CALayer, size: CGFloat) {
        let body = ovalLayer(
            frame: CGRect(x: size * 0.30, y: size * 0.20, width: size * 0.40, height: size * 0.56),
            color: NSColor(calibratedRed: 0.16, green: 0.14, blue: 0.09, alpha: 0.76)
        )
        body.name = "body"
        let glow = ovalLayer(
            frame: CGRect(x: size * 0.24, y: size * 0.52, width: size * 0.52, height: size * 0.36),
            color: NSColor(calibratedRed: 1.00, green: 0.94, blue: 0.36, alpha: 0.42)
        )
        glow.name = "glow"
        glow.shadowColor = NSColor(calibratedRed: 1.00, green: 0.93, blue: 0.35, alpha: 0.80).cgColor
        glow.shadowRadius = size * 0.55
        glow.shadowOpacity = 0.9
        glow.shadowOffset = .zero
        container.addSublayer(body)
        container.addSublayer(glow)
        addTinyEyes(to: container, center: CGPoint(x: size * 0.50, y: size * 0.22), size: size * 0.08)
        addPulse(to: glow)
    }

    private static func wingLayer(frame: CGRect, color: NSColor, mirrored: Bool) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.frame = frame
        let path = CGMutablePath()
        if mirrored {
            path.move(to: CGPoint(x: 0, y: frame.height * 0.50))
            path.addCurve(
                to: CGPoint(x: frame.width * 0.86, y: frame.height * 0.10),
                control1: CGPoint(x: frame.width * 0.20, y: -frame.height * 0.08),
                control2: CGPoint(x: frame.width * 0.88, y: -frame.height * 0.02)
            )
            path.addCurve(
                to: CGPoint(x: 0, y: frame.height * 0.50),
                control1: CGPoint(x: frame.width * 0.92, y: frame.height * 0.82),
                control2: CGPoint(x: frame.width * 0.28, y: frame.height * 0.98)
            )
        } else {
            path.move(to: CGPoint(x: frame.width, y: frame.height * 0.50))
            path.addCurve(
                to: CGPoint(x: frame.width * 0.14, y: frame.height * 0.10),
                control1: CGPoint(x: frame.width * 0.80, y: -frame.height * 0.08),
                control2: CGPoint(x: frame.width * 0.12, y: -frame.height * 0.02)
            )
            path.addCurve(
                to: CGPoint(x: frame.width, y: frame.height * 0.50),
                control1: CGPoint(x: frame.width * 0.08, y: frame.height * 0.82),
                control2: CGPoint(x: frame.width * 0.72, y: frame.height * 0.98)
            )
        }
        layer.path = path
        layer.fillColor = color.cgColor
        layer.strokeColor = NSColor(calibratedWhite: 0.08, alpha: 0.18).cgColor
        layer.lineWidth = 0.8
        return layer
    }

    private static func ovalLayer(frame: CGRect, color: NSColor) -> CALayer {
        let layer = CALayer()
        layer.frame = frame
        layer.backgroundColor = color.cgColor
        layer.cornerRadius = min(frame.width, frame.height) / 2
        return layer
    }

    private static func stripeLayer(frame: CGRect, color: NSColor) -> CALayer {
        let layer = CALayer()
        layer.frame = frame
        layer.backgroundColor = color.cgColor
        layer.cornerRadius = min(frame.width, frame.height) / 2
        return layer
    }

    private static func lineLayer(from start: CGPoint, to end: CGPoint, color: NSColor, width: CGFloat) -> CAShapeLayer {
        let layer = CAShapeLayer()
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        layer.path = path
        layer.strokeColor = color.cgColor
        layer.fillColor = nil
        layer.lineWidth = width
        layer.lineCap = .round
        return layer
    }

    private static func addButterflyWingDetails(to wing: CALayer, mirrored: Bool, speciesSize: CGFloat) {
        guard let shape = wing as? CAShapeLayer else {
            return
        }
        shape.name = "wing"
        let veinColor = NSColor(calibratedWhite: 0.05, alpha: 0.22)
        let w = wing.bounds.width
        let h = wing.bounds.height
        let rootX = mirrored ? 0 : w
        let tipX = mirrored ? w * 0.78 : w * 0.22
        for fraction in [0.22, 0.42, 0.62, 0.80] {
            shape.addSublayer(lineLayer(
                from: CGPoint(x: rootX, y: h * 0.50),
                to: CGPoint(x: tipX, y: h * CGFloat(fraction)),
                color: veinColor,
                width: max(0.45, speciesSize * 0.018)
            ))
        }
        for index in 0..<3 {
            let spot = ovalLayer(
                frame: CGRect(
                    x: (mirrored ? w * 0.54 : w * 0.28) + CGFloat(index) * w * 0.06,
                    y: h * (0.28 + CGFloat(index) * 0.16),
                    width: max(1.4, speciesSize * 0.055),
                    height: max(1.4, speciesSize * 0.055)
                ),
                color: NSColor(calibratedWhite: 0.04, alpha: 0.18)
            )
            shape.addSublayer(spot)
        }
    }

    private static func addDragonflyWingVeins(to wing: CALayer, color: NSColor) {
        let w = wing.bounds.width
        let h = wing.bounds.height
        let major = color
        let minor = color.withAlphaComponent(color.alphaComponent * 0.55)

        // Thick leading-edge (costal) vein — the wing's structural spar.
        wing.addSublayer(lineLayer(
            from: CGPoint(x: w * 0.04, y: h * 0.50),
            to: CGPoint(x: w * 0.96, y: h * 0.16),
            color: major,
            width: 0.75
        ))
        // Longitudinal veins fanning root → tip along the membrane.
        for frac in [0.34, 0.50, 0.66, 0.82] {
            wing.addSublayer(lineLayer(
                from: CGPoint(x: w * 0.06, y: h * 0.50),
                to: CGPoint(x: w * 0.94, y: h * CGFloat(frac)),
                color: minor,
                width: 0.42
            ))
        }
        // Fine cross-veins giving the membrane its lattice texture.
        for frac in [0.24, 0.40, 0.56, 0.72, 0.86] {
            let x = w * CGFloat(frac)
            wing.addSublayer(lineLayer(
                from: CGPoint(x: x, y: h * 0.22),
                to: CGPoint(x: x, y: h * 0.80),
                color: minor.withAlphaComponent(minor.alphaComponent * 0.6),
                width: 0.30
            ))
        }
    }

    private static func addAntennae(to container: CALayer, center: CGPoint, size: CGFloat, color: NSColor) {
        let left = lineLayer(
            from: center,
            to: CGPoint(x: center.x - size * 0.20, y: center.y - size * 0.22),
            color: color,
            width: max(0.5, size * 0.018)
        )
        let right = lineLayer(
            from: center,
            to: CGPoint(x: center.x + size * 0.20, y: center.y - size * 0.22),
            color: color,
            width: max(0.5, size * 0.018)
        )
        left.name = "antenna"
        right.name = "antenna"
        container.addSublayer(left)
        container.addSublayer(right)
    }

    private static func addTinyEyes(to container: CALayer, center: CGPoint, size: CGFloat) {
        let eyeColor = NSColor(calibratedWhite: 0.02, alpha: 0.84)
        let sparkle = NSColor(calibratedWhite: 1.0, alpha: 0.65)
        for xOffset in [-size * 0.42, size * 0.42] {
            let eye = ovalLayer(
                frame: CGRect(x: center.x + xOffset - size * 0.22, y: center.y - size * 0.22, width: size * 0.44, height: size * 0.44),
                color: eyeColor
            )
            eye.name = "eye"
            eye.addSublayer(ovalLayer(
                frame: CGRect(x: size * 0.10, y: size * 0.08, width: size * 0.12, height: size * 0.12),
                color: sparkle
            ))
            container.addSublayer(eye)
        }
    }

    private static func addInsectLegs(to container: CALayer, bodyFrame: CGRect, color: NSColor, size: CGFloat) {
        for fraction in [0.20, 0.48, 0.76] {
            let y = bodyFrame.minY + bodyFrame.height * CGFloat(fraction)
            let left = lineLayer(
                from: CGPoint(x: bodyFrame.minX + bodyFrame.width * 0.22, y: y),
                to: CGPoint(x: bodyFrame.minX - size * 0.14, y: y + size * 0.08),
                color: color,
                width: max(0.45, size * 0.016)
            )
            let right = lineLayer(
                from: CGPoint(x: bodyFrame.maxX - bodyFrame.width * 0.22, y: y),
                to: CGPoint(x: bodyFrame.maxX + size * 0.14, y: y + size * 0.08),
                color: color,
                width: max(0.45, size * 0.016)
            )
            left.name = fraction == 0.20 ? "foreleg" : "leg"
            right.name = fraction == 0.20 ? "foreleg" : "leg"
            container.addSublayer(left)
            container.addSublayer(right)
        }
    }

    private static func addPollenBaskets(to container: CALayer, bodyFrame: CGRect, size: CGFloat, isHoverfly: Bool) {
        guard !isHoverfly else {
            return
        }
        let pollen = NSColor(calibratedRed: 0.96, green: 0.72, blue: 0.18, alpha: 0.80)
        for x in [bodyFrame.minX + bodyFrame.width * 0.18, bodyFrame.maxX - bodyFrame.width * 0.26] {
            let basket = ovalLayer(
                frame: CGRect(x: x, y: bodyFrame.maxY - size * 0.03, width: size * 0.08, height: size * 0.06),
                color: pollen
            )
            basket.name = "pollen"
            container.addSublayer(basket)
        }
    }

    private static func addWingFlap(to layer: CALayer, keyPath: String, amplitude: CGFloat, duration: CFTimeInterval) {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = -amplitude
        animation.toValue = amplitude
        animation.duration = duration
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "flap")
    }

    private static func addPulse(to layer: CALayer) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0.35
        animation.toValue = 1.0
        animation.duration = 1.4
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "pulse")
    }

    private static func addBodyBob(to layer: CALayer, distance: CGFloat, duration: CFTimeInterval) {
        let animation = CABasicAnimation(keyPath: "transform.translation.y")
        animation.fromValue = -distance
        animation.toValue = distance
        animation.duration = duration
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "behaviorBob")
    }

    private static func addSlowTurn(to layer: CALayer, amplitude: CGFloat, duration: CFTimeInterval) {
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = -amplitude
        animation.toValue = amplitude
        animation.duration = duration
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "behaviorTurn")
    }

    private static func forageAnimation() -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        animation.values = [-0.18, 0.16, -0.10, 0.12, -0.18]
        animation.duration = 0.72
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return animation
    }

    private static func addRestStillness(to layer: CALayer) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0.78
        animation.toValue = 1.0
        animation.duration = 2.4
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "restOpacity")
    }
}
