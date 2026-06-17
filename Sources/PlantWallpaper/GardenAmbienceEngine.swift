import AVFoundation
import Foundation
import PlantGardenCore
import os

/// Procedurally synthesized garden ambience - no audio files involved.
///
/// Four layers, mixed live and driven by the simulation:
/// - **Wind**: leaky-integrated noise with slow gust swells, level follows
///   the garden's wind strength.
/// - **Rain**: filtered noise bed plus sparse drips, level follows the live
///   weather feed (so real rain outside is audible rain on the desktop).
/// - **Birdsong**: gentle frequency-swept chirp phrases during daylight, tuned
///   by the active scene's likely birds and acoustic setting.
/// - **Crickets**: pulsed night trains, tuned by the active scene.
/// - **Place beds**: light synthetic water, city/road murmur, room tone,
///   cicadas, room life, electronics, alien fauna, habitat machinery, low
///   rumbles, crystalline shimmer, and rare chimes based on scene soundscape
///   metadata.
///
/// The render callback is real-time safe: parameters cross the thread
/// boundary through a lock-guarded snapshot taken once per render quantum,
/// and every layer eases toward its target to avoid zipper noise.
final class GardenAmbienceEngine {
    struct Mix: Equatable {
        var masterVolume: Double = 0
        var wind: Double = 0
        var rain: Double = 0
        var birds: Double = 0
        var crickets: Double = 0
        var water: Double = 0
        var urbanMurmur: Double = 0
        var roomTone: Double = 0
        var cicadas: Double = 0
        var chimes: Double = 0
        var smallWildlife: Double = 0
        var roomLife: Double = 0
        var electronics: Double = 0
        var alienFauna: Double = 0
        var habitatHum: Double = 0
        var crystallineShimmer: Double = 0
        var lowRumble: Double = 0
        var birdPitch: Double = 1
        var birdDensity: Double = 1
        var birdBrightness: Double = 1
        var cricketPitch: Double = 1

        static let silent = Mix()
    }

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var isRunning = false

    private let mixLock = OSAllocatedUnfairLock(initialState: Mix.silent)

    // MARK: - Render state (audio thread only)

    private final class RenderState {
        var smoothedMaster = 0.0
        var smoothedWind = 0.0
        var smoothedRain = 0.0
        var smoothedBirds = 0.0
        var smoothedCrickets = 0.0
        var smoothedWater = 0.0
        var smoothedUrbanMurmur = 0.0
        var smoothedRoomTone = 0.0
        var smoothedCicadas = 0.0
        var smoothedChimes = 0.0
        var smoothedSmallWildlife = 0.0
        var smoothedRoomLife = 0.0
        var smoothedElectronics = 0.0
        var smoothedAlienFauna = 0.0
        var smoothedHabitatHum = 0.0
        var smoothedCrystallineShimmer = 0.0
        var smoothedLowRumble = 0.0

        var windBrown = 0.0
        var gustPhase = 0.0
        var rainLowPass = 0.0
        var dripEnvelope = 0.0
        var dripPhase = 0.0
        var waterLowPass = 0.0
        var waterPhase = 0.0
        var urbanLowPass = 0.0
        var trafficEnvelope = 0.0
        var trafficPhase = 0.0
        var roomTonePhase = 0.0
        var roomLifeLowPass = 0.0
        var roomCreakEnvelope = 0.0
        var roomCreakPhase = 0.0
        var roomCreakHz = 110.0
        var electronicsPhase = 0.0
        var digitalTickEnvelope = 0.0
        var wildlifeRustleLowPass = 0.0
        var wildlifeEnvelope = 0.0
        var wildlifePhase = 0.0
        var wildlifeHz = 320.0
        var wildlifeTimer = 5.0
        var alienChirpEnvelope = 0.0
        var alienChirpPhase = 0.0
        var alienChirpTimer = 2.0
        var alienChirpAge = 0.0
        var habitatHumPhase = 0.0
        var crystalTimer = 11.0
        var crystalEnvelope = 0.0
        var crystalPhase = 0.0
        var crystalHz = 1_200.0
        var rumblePhase = 0.0

        var birdTimer = 2.0
        var birdSyllablesLeft = 0
        var birdSyllableTime = 0.0
        var birdSyllableDuration = 0.09
        var birdGapTime = 0.0
        var birdStartHz = 2_600.0
        var birdEndHz = 3_400.0
        var birdPhase = 0.0

        var cricketPhase = 0.0
        var cricketTrainTime = 0.0
        var cicadaPhase = 0.0
        var cicadaPulseTime = 0.0
        var chimeTimer = 19.0
        var chimeEnvelope = 0.0
        var chimePhase = 0.0
        var chimeHz = 620.0
        var rng: UInt64 = 0x9E37_79B9_7F4A_7C15

        func nextRandom() -> Double {
            rng ^= rng << 13
            rng ^= rng >> 7
            rng ^= rng << 17
            return Double(rng % 1_000_000) / 1_000_000
        }
    }

    func setMix(_ mix: Mix) {
        mixLock.withLock { $0 = mix }
        let shouldRun = mix.masterVolume > 0.001
        if shouldRun && !isRunning {
            start()
        } else if !shouldRun && isRunning {
            stop()
        }
    }

    /// Derives the layer mix from the garden state and wall clock.
    static func mix(for state: GardenState, sceneKey: String? = nil, at date: Date = Date()) -> Mix {
        guard state.settings.isAmbientSoundEnabled, state.settings.ambientSoundVolume > 0 else {
            return .silent
        }

        let soundscape = GardenSceneSoundscape(sceneKey: sceneKey)
        let hour = Calendar.current.component(.hour, from: date)
        let minute = Calendar.current.component(.minute, from: date)
        let dayProgress = Double(hour) + Double(minute) / 60

        // Birds sing from dawn, peak mid-morning, quiet by dusk.
        let birds: Double
        switch dayProgress {
        case 5.5..<8:
            birds = 0.5 + (dayProgress - 5.5) / 2.5 * 0.5
        case 8..<17:
            birds = 0.85
        case 17..<20:
            birds = max(0, (20 - dayProgress) / 3) * 0.7
        default:
            birds = 0
        }

        // Crickets own the night.
        let crickets: Double
        switch dayProgress {
        case 20..<22:
            crickets = (dayProgress - 20) / 2
        case 22..<24, 0..<4.5:
            crickets = 1.0
        case 4.5..<6:
            crickets = max(0, (6 - dayProgress) / 1.5)
        default:
            crickets = 0
        }

        let weather = state.weather.flatMap { $0.isStale(at: date) ? nil : $0 }
        let rain: Double
        switch weather?.kind {
        case .drizzle:
            rain = 0.35
        case .rain:
            rain = 0.7
        case .storm:
            rain = 1.0
        default:
            rain = 0
        }

        // Rain hushes the singers.
        let rainDampening = 1.0 - rain * 0.65
        let daylightCicadas = dayProgress >= 10 && dayProgress < 18
            ? soundscape.insects.cicadaPresence
            : soundscape.insects.cicadaPresence * 0.30
        let baseWind = min(1, max(0, state.windStrength))
        let shapedWind = min(1, baseWind * soundscape.place.windExposure + soundscape.place.leafRustle * 0.16)
        return Mix(
            masterVolume: state.settings.ambientSoundVolume,
            wind: state.settings.isWindSoundEnabled ? shapedWind * 0.9 : 0,
            rain: state.settings.isRainSoundEnabled ? rain : 0,
            birds: state.settings.isBirdsongEnabled ? birds * rainDampening * soundscape.birds.presence : 0,
            crickets: state.settings.isCricketSoundEnabled
                ? crickets * rainDampening * soundscape.insects.nightPresence
                : 0,
            water: state.settings.isWaterSoundEnabled
                ? soundscape.place.water * (0.70 + baseWind * 0.30)
                : 0,
            urbanMurmur: state.settings.isUrbanMurmurSoundEnabled ? soundscape.place.urbanMurmur : 0,
            roomTone: state.settings.isRoomToneSoundEnabled ? soundscape.place.roomTone : 0,
            cicadas: state.settings.isCricketSoundEnabled && state.settings.isCicadaSoundEnabled
                ? daylightCicadas * rainDampening
                : 0,
            chimes: state.settings.isChimeSoundEnabled ? soundscape.place.chimes : 0,
            smallWildlife: state.settings.isSmallWildlifeSoundEnabled
                ? soundscape.place.smallWildlife * rainDampening
                : 0,
            roomLife: state.settings.isRoomLifeSoundEnabled ? soundscape.place.roomLife : 0,
            electronics: state.settings.isElectronicsSoundEnabled ? soundscape.place.electronics : 0,
            alienFauna: state.settings.isAlienFaunaSoundEnabled
                ? soundscape.place.alienFauna * rainDampening
                : 0,
            habitatHum: state.settings.isHabitatHumSoundEnabled ? soundscape.place.habitatHum : 0,
            crystallineShimmer: state.settings.isCrystallineShimmerSoundEnabled
                ? soundscape.place.crystallineShimmer
                : 0,
            lowRumble: state.settings.isLowRumbleSoundEnabled ? soundscape.place.lowRumble : 0,
            birdPitch: soundscape.birds.pitch,
            birdDensity: soundscape.birds.density,
            birdBrightness: soundscape.birds.brightness,
            cricketPitch: soundscape.insects.pitch
        )
    }

    private func start() {
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 44_100
        let renderState = RenderState()
        let mixLock = mixLock

        let node = AVAudioSourceNode(format: AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        )!) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let targetMix = mixLock.withLock { $0 }
            let state = renderState
            let dt = 1.0 / sampleRate
            // ~80 ms easing for level changes.
            let ease = min(1, dt * 12)

            for frame in 0..<Int(frameCount) {
                state.smoothedMaster += (targetMix.masterVolume - state.smoothedMaster) * ease
                state.smoothedWind += (targetMix.wind - state.smoothedWind) * ease
                state.smoothedRain += (targetMix.rain - state.smoothedRain) * ease
                state.smoothedBirds += (targetMix.birds - state.smoothedBirds) * ease
                state.smoothedCrickets += (targetMix.crickets - state.smoothedCrickets) * ease
                state.smoothedWater += (targetMix.water - state.smoothedWater) * ease
                state.smoothedUrbanMurmur += (targetMix.urbanMurmur - state.smoothedUrbanMurmur) * ease
                state.smoothedRoomTone += (targetMix.roomTone - state.smoothedRoomTone) * ease
                state.smoothedCicadas += (targetMix.cicadas - state.smoothedCicadas) * ease
                state.smoothedChimes += (targetMix.chimes - state.smoothedChimes) * ease
                state.smoothedSmallWildlife += (targetMix.smallWildlife - state.smoothedSmallWildlife) * ease
                state.smoothedRoomLife += (targetMix.roomLife - state.smoothedRoomLife) * ease
                state.smoothedElectronics += (targetMix.electronics - state.smoothedElectronics) * ease
                state.smoothedAlienFauna += (targetMix.alienFauna - state.smoothedAlienFauna) * ease
                state.smoothedHabitatHum += (targetMix.habitatHum - state.smoothedHabitatHum) * ease
                state.smoothedCrystallineShimmer += (targetMix.crystallineShimmer - state.smoothedCrystallineShimmer) * ease
                state.smoothedLowRumble += (targetMix.lowRumble - state.smoothedLowRumble) * ease

                var sample = 0.0

                // Wind: leaky integrator over white noise + slow gust swell.
                let white = state.nextRandom() * 2 - 1
                state.windBrown = (state.windBrown + white * 0.02).clampedAudio * 0.995
                state.gustPhase += dt * 0.07
                let gust = 0.55 + 0.45 * sin(state.gustPhase * 2 * .pi)
                sample += state.windBrown * 5.5 * gust * state.smoothedWind * 0.16

                // Rain: low-passed noise bed plus occasional bright drips.
                if state.smoothedRain > 0.002 {
                    let rainNoise = state.nextRandom() * 2 - 1
                    state.rainLowPass += (rainNoise - state.rainLowPass) * 0.18
                    var rainSample = state.rainLowPass * 0.5
                    if state.dripEnvelope > 0.0001 {
                        state.dripPhase += dt * 2_300 * 2 * .pi
                        rainSample += sin(state.dripPhase) * state.dripEnvelope * 0.25
                        state.dripEnvelope *= 1 - dt * 60
                    } else if state.nextRandom() < dt * 6 * state.smoothedRain {
                        state.dripEnvelope = 0.5 + state.nextRandom() * 0.5
                        state.dripPhase = 0
                    }
                    sample += rainSample * state.smoothedRain * 0.30
                }

                // Water: filtered noise shaped by slow overlapping wavelets.
                if state.smoothedWater > 0.002 {
                    let waterNoise = state.nextRandom() * 2 - 1
                    state.waterLowPass += (waterNoise - state.waterLowPass) * 0.045
                    state.waterPhase += dt * 0.52
                    let ripple = 0.58
                        + 0.24 * sin(state.waterPhase * 2 * .pi)
                        + 0.18 * sin(state.waterPhase * 3.7 * 2 * .pi + 0.8)
                    sample += state.waterLowPass * ripple * state.smoothedWater * 0.18
                }

                // Urban/road murmur: distant low-frequency movement, never a car horn.
                if state.smoothedUrbanMurmur > 0.002 {
                    let roadNoise = state.nextRandom() * 2 - 1
                    state.urbanLowPass += (roadNoise - state.urbanLowPass) * 0.018
                    if state.trafficEnvelope > 0.0001 {
                        state.trafficPhase += dt * (44 + state.trafficEnvelope * 26) * 2 * .pi
                        state.trafficEnvelope *= 1 - dt * 0.55
                    } else if state.nextRandom() < dt * (0.08 + state.smoothedUrbanMurmur * 0.18) {
                        state.trafficEnvelope = 0.5 + state.nextRandom() * 0.5
                    }
                    let traffic = sin(state.trafficPhase) * state.trafficEnvelope * 0.18
                    sample += (state.urbanLowPass * 0.42 + traffic) * state.smoothedUrbanMurmur * 0.22
                }

                // Room/glasshouse tone: a very quiet, breathable interior resonance.
                if state.smoothedRoomTone > 0.002 {
                    state.roomTonePhase += dt * 86 * 2 * .pi
                    let breath = 0.65 + 0.35 * sin(state.gustPhase * 2 * .pi * 0.37 + 1.2)
                    sample += sin(state.roomTonePhase) * breath * state.smoothedRoomTone * 0.018
                    sample += state.windBrown * state.smoothedRoomTone * 0.030
                }

                // Small wildlife: leaf-edge rustles plus rare low chirps/croaks
                // for patios, yards, courtyards, and warm rural gardens.
                if state.smoothedSmallWildlife > 0.002 {
                    let rustleNoise = state.nextRandom() * 2 - 1
                    state.wildlifeRustleLowPass += (rustleNoise - state.wildlifeRustleLowPass) * 0.10
                    sample += state.wildlifeRustleLowPass * state.smoothedSmallWildlife * 0.025

                    state.wildlifeTimer -= dt
                    if state.wildlifeEnvelope > 0.0001 {
                        state.wildlifePhase += dt * state.wildlifeHz * 2 * .pi
                        sample += sin(state.wildlifePhase) * state.wildlifeEnvelope * state.smoothedSmallWildlife * 0.050
                        state.wildlifeEnvelope *= 1 - dt * 5.0
                    } else if state.wildlifeTimer <= 0 {
                        state.wildlifeEnvelope = 0.35 + state.nextRandom() * 0.45
                        state.wildlifePhase = 0
                        state.wildlifeHz = 220 + state.nextRandom() * 430
                        state.wildlifeTimer = 7 + state.nextRandom() * 18
                    }
                }

                // Room life: wood/fabric micro-movement and very rare creaks,
                // intentionally low so bedroom/den modes feel alive, not haunted.
                if state.smoothedRoomLife > 0.002 {
                    let roomNoise = state.nextRandom() * 2 - 1
                    state.roomLifeLowPass += (roomNoise - state.roomLifeLowPass) * 0.026
                    sample += state.roomLifeLowPass * state.smoothedRoomLife * 0.030

                    if state.roomCreakEnvelope > 0.0001 {
                        state.roomCreakPhase += dt * state.roomCreakHz * 2 * .pi
                        sample += sin(state.roomCreakPhase) * state.roomCreakEnvelope * state.smoothedRoomLife * 0.030
                        state.roomCreakEnvelope *= 1 - dt * 2.2
                    } else if state.nextRandom() < dt * (0.035 + state.smoothedRoomLife * 0.055) {
                        state.roomCreakEnvelope = 0.25 + state.nextRandom() * 0.35
                        state.roomCreakPhase = 0
                        state.roomCreakHz = 80 + state.nextRandom() * 120
                    }
                }

                // Electronics: tiny speaker/monitor/console hums and occasional
                // softened relay ticks for media dens, rooms, and starships.
                if state.smoothedElectronics > 0.002 {
                    state.electronicsPhase += dt * 60 * 2 * .pi
                    let hum = sin(state.electronicsPhase) * 0.014
                        + sin(state.electronicsPhase * 2.003) * 0.006
                        + sin(state.electronicsPhase * 3.997) * 0.003
                    sample += hum * state.smoothedElectronics

                    if state.digitalTickEnvelope > 0.0001 {
                        sample += (state.nextRandom() * 2 - 1) * state.digitalTickEnvelope * state.smoothedElectronics * 0.060
                        state.digitalTickEnvelope *= 1 - dt * 90
                    } else if state.nextRandom() < dt * (0.10 + state.smoothedElectronics * 0.26) {
                        state.digitalTickEnvelope = 0.18 + state.nextRandom() * 0.22
                    }
                }

                // Alien fauna: musical non-Earth calls with slow glissandi and
                // glassy wing pulses, separate from normal birds/crickets.
                if state.smoothedAlienFauna > 0.002 {
                    state.alienChirpTimer -= dt
                    if state.alienChirpEnvelope > 0.0001 {
                        state.alienChirpAge += dt
                        let sweep = 0.5 + 0.5 * sin(state.alienChirpAge * 5.2)
                        let hz = 620 + sweep * 980 + state.nextRandom() * 35
                        state.alienChirpPhase += dt * hz * 2 * .pi
                        let overtone = sin(state.alienChirpPhase * 1.503) * 0.45
                        sample += (sin(state.alienChirpPhase) + overtone)
                            * state.alienChirpEnvelope
                            * state.smoothedAlienFauna
                            * 0.030
                        state.alienChirpEnvelope *= 1 - dt * 3.0
                    } else if state.alienChirpTimer <= 0 {
                        state.alienChirpEnvelope = 0.45 + state.nextRandom() * 0.45
                        state.alienChirpPhase = 0
                        state.alienChirpAge = 0
                        state.alienChirpTimer = 2.8 + state.nextRandom() * 8.5 / max(0.35, state.smoothedAlienFauna)
                    }
                }

                // Habitat machinery and low rumble: sealed domes, starship
                // life-support, levitation fields, and deep hull/body resonance.
                if state.smoothedHabitatHum > 0.002 {
                    state.habitatHumPhase += dt * 52 * 2 * .pi
                    let modulation = 0.72 + 0.28 * sin(state.gustPhase * 2 * .pi * 0.19)
                    let hum = sin(state.habitatHumPhase) * 0.020
                        + sin(state.habitatHumPhase * 1.79) * 0.010
                    sample += hum * modulation * state.smoothedHabitatHum
                }

                if state.smoothedLowRumble > 0.002 {
                    state.rumblePhase += dt * 34 * 2 * .pi
                    let rumble = sin(state.rumblePhase) * 0.018
                        + sin(state.rumblePhase * 1.41 + 0.7) * 0.010
                    sample += rumble * state.smoothedLowRumble
                }

                // Crystalline shimmer: delicate high glints for glasshouses,
                // temple air, and alien mineral/energy-field spaces.
                if state.smoothedCrystallineShimmer > 0.002 {
                    if state.crystalEnvelope > 0.0001 {
                        state.crystalPhase += dt * state.crystalHz * 2 * .pi
                        sample += sin(state.crystalPhase)
                            * state.crystalEnvelope
                            * state.smoothedCrystallineShimmer
                            * 0.028
                        state.crystalEnvelope *= 1 - dt * 1.25
                    } else {
                        state.crystalTimer -= dt
                        if state.crystalTimer <= 0 {
                            state.crystalEnvelope = 0.36 + state.nextRandom() * 0.30
                            state.crystalPhase = 0
                            state.crystalHz = 920 + state.nextRandom() * 1_240
                            state.crystalTimer = 12 + state.nextRandom() * 34
                        }
                    }
                }

                // Birdsong: phrase scheduler -> frequency-swept syllables.
                if state.smoothedBirds > 0.01 {
                    if state.birdSyllablesLeft > 0 {
                        if state.birdGapTime > 0 {
                            state.birdGapTime -= dt
                        } else {
                            state.birdSyllableTime += dt
                            let progress = state.birdSyllableTime / state.birdSyllableDuration
                            if progress >= 1 {
                                state.birdSyllablesLeft -= 1
                                state.birdSyllableTime = 0
                                state.birdGapTime = 0.04 + state.nextRandom() * 0.10
                                state.birdStartHz = (2_200 + state.nextRandom() * 1_400) * targetMix.birdPitch
                                state.birdEndHz = state.birdStartHz
                                    + (state.nextRandom() - 0.35) * 1_600 * targetMix.birdPitch
                            } else {
                                let hz = state.birdStartHz + (state.birdEndHz - state.birdStartHz) * progress
                                state.birdPhase += dt * hz * 2 * .pi
                                // Raised-cosine envelope keeps chirps soft.
                                let envelope = 0.5 - 0.5 * cos(progress * 2 * .pi)
                                sample += sin(state.birdPhase)
                                    * envelope
                                    * state.smoothedBirds
                                    * (0.045 + targetMix.birdBrightness * 0.030)
                            }
                        }
                    } else {
                        state.birdTimer -= dt
                        if state.birdTimer <= 0 {
                            state.birdSyllablesLeft = 2 + Int(state.nextRandom() * 4 * targetMix.birdDensity)
                            state.birdSyllableDuration = (0.06 + state.nextRandom() * 0.07)
                                / max(0.65, targetMix.birdDensity)
                            state.birdStartHz = (2_200 + state.nextRandom() * 1_400) * targetMix.birdPitch
                            state.birdEndHz = state.birdStartHz
                                + (state.nextRandom() - 0.35) * 1_600 * targetMix.birdPitch
                            state.birdTimer = (3.5 + state.nextRandom() * 7) / max(0.45, targetMix.birdDensity)
                            state.birdGapTime = 0
                        }
                    }
                }

                // Crickets: 4.3 kHz pulse trains, one chirp per ~1.1 s.
                if state.smoothedCrickets > 0.01 {
                    state.cricketTrainTime += dt
                    let trainPeriod = 1.1
                    let timeInTrain = state.cricketTrainTime.truncatingRemainder(dividingBy: trainPeriod)
                    // Three 30 ms pulses, 60 ms apart, at the train start.
                    let pulseIndex = Int(timeInTrain / 0.06)
                    let timeInPulse = timeInTrain.truncatingRemainder(dividingBy: 0.06)
                    if pulseIndex < 3 && pulseIndex.isMultiple(of: 1) && timeInPulse < 0.03 {
                        state.cricketPhase += dt * 4_300 * targetMix.cricketPitch * 2 * .pi
                        let envelope = sin(timeInPulse / 0.03 * .pi)
                        sample += sin(state.cricketPhase) * envelope * state.smoothedCrickets * 0.035
                    }
                }

                // Cicadas: daytime heat buzzes, shaped as restless high bands.
                if state.smoothedCicadas > 0.01 {
                    state.cicadaPulseTime += dt
                    let cycle = state.cicadaPulseTime.truncatingRemainder(dividingBy: 1.7)
                    let pulse = cycle < 1.05 ? sin(cycle / 1.05 * .pi) : 0
                    state.cicadaPhase += dt * (6_200 + state.nextRandom() * 800) * 2 * .pi
                    sample += sin(state.cicadaPhase) * pulse * state.smoothedCicadas * 0.018
                }

                // Chimes: rare, soft sine strikes for spaces that imply bells or metal.
                if state.smoothedChimes > 0.002 {
                    if state.chimeEnvelope > 0.0001 {
                        state.chimePhase += dt * state.chimeHz * 2 * .pi
                        sample += sin(state.chimePhase) * state.chimeEnvelope * state.smoothedChimes * 0.05
                        state.chimeEnvelope *= 1 - dt * 1.6
                    } else {
                        state.chimeTimer -= dt
                        if state.chimeTimer <= 0 {
                            state.chimeEnvelope = 0.65 + state.nextRandom() * 0.35
                            state.chimePhase = 0
                            state.chimeHz = 520 + state.nextRandom() * 360
                            state.chimeTimer = 28 + state.nextRandom() * 72
                        }
                    }
                }

                let output = Float((sample * state.smoothedMaster).clampedAudio)
                for buffer in buffers {
                    guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else {
                        continue
                    }
                    data[frame] = output
                }
            }
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: nil)
        sourceNode = node

        do {
            try engine.start()
            isRunning = true
        } catch {
            NSLog("Plant Wallpaper could not start ambient sound: \(error.localizedDescription)")
            engine.detach(node)
            sourceNode = nil
        }
    }

    private func stop() {
        engine.stop()
        if let sourceNode {
            engine.detach(sourceNode)
        }
        sourceNode = nil
        isRunning = false
    }
}

private extension Double {
    var clampedAudio: Double {
        Swift.min(1, Swift.max(-1, self))
    }
}
