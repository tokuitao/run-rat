import Foundation

struct RatAnimator {
    private(set) var frameIndex = 0
    private var frameProgress = 0.0
    let frameCount: Int

    init(frameCount: Int) {
        self.frameCount = max(frameCount, 1)
    }

    mutating func tick(deltaTime: TimeInterval, cpuUsage: Double) -> Bool {
        let framesPerSecond = Self.framesPerSecond(for: cpuUsage)
        frameProgress += deltaTime * framesPerSecond

        guard frameProgress >= 1 else {
            return false
        }

        let advancedFrames = Int(frameProgress)
        frameProgress -= Double(advancedFrames)
        frameIndex = (frameIndex + advancedFrames) % frameCount
        return true
    }

    static func framesPerSecond(for cpuUsage: Double) -> Double {
        let clampedUsage = min(max(cpuUsage, 0), 1)
        return 2.5 + pow(clampedUsage, 0.8) * 15.5
    }

    static func paceLabel(for cpuUsage: Double) -> String {
        switch cpuUsage {
        case ..<0.15:
            return "sleepy shuffle"
        case ..<0.4:
            return "light jog"
        case ..<0.7:
            return "busy scamper"
        default:
            return "full sprint"
        }
    }
}
