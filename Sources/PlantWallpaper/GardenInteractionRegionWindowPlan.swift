import AppKit

struct GardenInteractionRegionWindowPlan {
    static let minimumFrameSize: CGFloat = 8
    static let frameEqualityTolerance: CGFloat = 3
    static let defaultMergePadding: CGFloat = 18

    static func displayableFrames(from frames: [NSRect]) -> [NSRect] {
        frames.filter { $0.width >= minimumFrameSize && $0.height >= minimumFrameSize }
    }

    static func optimizedDisplayableFrames(
        from frames: [NSRect],
        maximumFrameCount: Int,
        mergePadding: CGFloat = defaultMergePadding
    ) -> [NSRect] {
        guard maximumFrameCount > 0 else {
            return []
        }

        var plannedFrames = coalescedFrames(
            from: displayableFrames(from: frames),
            mergePadding: mergePadding
        )
        guard plannedFrames.count > maximumFrameCount else {
            return plannedFrames
        }

        while plannedFrames.count > maximumFrameCount {
            guard let pair = closestPairIndex(in: plannedFrames) else {
                break
            }
            let mergedFrame = plannedFrames[pair.first].union(plannedFrames[pair.second]).integral
            plannedFrames[pair.first] = mergedFrame
            plannedFrames.remove(at: pair.second)
            plannedFrames = sorted(plannedFrames)
        }

        return plannedFrames
    }

    static func shouldRebuild(
        currentFrames: [NSRect],
        proposedFrames: [NSRect],
        existingWindowCount: Int
    ) -> Bool {
        guard existingWindowCount == proposedFrames.count,
              currentFrames.count == proposedFrames.count else {
            return true
        }

        return !zip(currentFrames, proposedFrames).allSatisfy { framesAreEquivalent($0, $1) }
    }

    private static func framesAreEquivalent(_ lhs: NSRect, _ rhs: NSRect) -> Bool {
        abs(lhs.minX - rhs.minX) <= frameEqualityTolerance
            && abs(lhs.minY - rhs.minY) <= frameEqualityTolerance
            && abs(lhs.width - rhs.width) <= frameEqualityTolerance
            && abs(lhs.height - rhs.height) <= frameEqualityTolerance
    }

    private static func coalescedFrames(from frames: [NSRect], mergePadding: CGFloat) -> [NSRect] {
        var plannedFrames = sorted(frames.map(\.integral))
        var index = 0
        while index < plannedFrames.count {
            var frame = plannedFrames[index]
            var mergedAny = false
            var candidateIndex = index + 1
            while candidateIndex < plannedFrames.count {
                let candidate = plannedFrames[candidateIndex]
                guard shouldMerge(frame, candidate, mergePadding: mergePadding) else {
                    candidateIndex += 1
                    continue
                }

                frame = frame.union(candidate).integral
                plannedFrames[index] = frame
                plannedFrames.remove(at: candidateIndex)
                mergedAny = true
            }

            if mergedAny {
                index = 0
            } else {
                index += 1
            }
        }

        return sorted(plannedFrames)
    }

    private static func shouldMerge(_ lhs: NSRect, _ rhs: NSRect, mergePadding: CGFloat) -> Bool {
        lhs.insetBy(dx: -mergePadding, dy: -mergePadding).intersects(rhs)
    }

    private static func closestPairIndex(in frames: [NSRect]) -> (first: Int, second: Int)? {
        guard frames.count > 1 else {
            return nil
        }

        var bestPair: (first: Int, second: Int)?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for first in frames.indices {
            for second in frames.indices where second > first {
                let distance = edgeDistance(frames[first], frames[second])
                if distance < bestDistance {
                    bestDistance = distance
                    bestPair = (first, second)
                }
            }
        }
        return bestPair
    }

    private static func edgeDistance(_ lhs: NSRect, _ rhs: NSRect) -> CGFloat {
        let horizontalGap = max(0, max(lhs.minX - rhs.maxX, rhs.minX - lhs.maxX))
        let verticalGap = max(0, max(lhs.minY - rhs.maxY, rhs.minY - lhs.maxY))
        return hypot(horizontalGap, verticalGap)
    }

    private static func sorted(_ frames: [NSRect]) -> [NSRect] {
        frames.sorted {
            if abs($0.minY - $1.minY) > frameEqualityTolerance {
                return $0.minY < $1.minY
            }
            if abs($0.minX - $1.minX) > frameEqualityTolerance {
                return $0.minX < $1.minX
            }
            if abs($0.width - $1.width) > frameEqualityTolerance {
                return $0.width < $1.width
            }
            return $0.height < $1.height
        }
    }
}
