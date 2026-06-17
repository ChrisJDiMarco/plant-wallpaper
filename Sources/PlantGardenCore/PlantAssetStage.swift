import Foundation

public struct PlantAssetStage: Equatable, Sendable {
    public static let defaultStageCount = 10

    public let index: Int
    public let nextIndex: Int?
    public let progressToNext: Double
    public let blendOpacity: Double

    public init(
        growth: Double,
        stageCount: Int = PlantAssetStage.defaultStageCount,
        blendStart: Double = 0.68,
        maximumBlendOpacity: Double = 0.62
    ) {
        let safeStageCount = max(1, stageCount)
        let normalizedGrowth = growth.clampedUnit

        if normalizedGrowth >= 1 || safeStageCount == 1 {
            index = safeStageCount - 1
            nextIndex = nil
            progressToNext = 1
            blendOpacity = 0
            return
        }

        let scaledGrowth = normalizedGrowth * Double(safeStageCount)
        let rawIndex = Int(scaledGrowth.rounded(.down))
        let safeIndex = min(safeStageCount - 1, max(0, rawIndex))
        let fractionalProgress = scaledGrowth - floor(scaledGrowth)
        let safeProgress = fractionalProgress.clampedUnit

        index = safeIndex
        nextIndex = safeIndex < safeStageCount - 1 ? safeIndex + 1 : nil
        progressToNext = safeProgress

        guard nextIndex != nil, safeProgress > blendStart else {
            blendOpacity = 0
            return
        }

        let blendRange = max(0.0001, 1 - blendStart)
        let blendProgress = ((safeProgress - blendStart) / blendRange).clampedUnit
        let easedBlend = blendProgress * blendProgress * (3 - 2 * blendProgress)
        blendOpacity = (easedBlend * maximumBlendOpacity).clampedUnit
    }
}
