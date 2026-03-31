import Foundation

struct RatAnimator {
    enum PlaybackMode {
        case adaptive(cpuUsage: Double)
        case fixedPreview
    }

    static let referenceFrameDuration = 0.085
    static let referenceFramesPerSecond = 1.0 / referenceFrameDuration
    private static let maximumAdaptiveMultiplier = 1.35

    private(set) var frameIndex = 0
    private var frameProgress = 0.0
    let frameCount: Int

    init(frameCount: Int) {
        self.frameCount = max(frameCount, 1)
    }

    mutating func tick(deltaTime: TimeInterval, playbackMode: PlaybackMode) -> Bool {
        let framesPerSecond = Self.framesPerSecond(for: playbackMode)
        frameProgress += deltaTime * framesPerSecond

        guard frameProgress >= 1 else {
            return false
        }

        let advancedFrames = Int(frameProgress)
        frameProgress -= Double(advancedFrames)
        frameIndex = (frameIndex + advancedFrames) % frameCount
        return true
    }

    static func framesPerSecond(for playbackMode: PlaybackMode) -> Double {
        switch playbackMode {
        case .fixedPreview:
            return referenceFramesPerSecond
        case let .adaptive(cpuUsage):
            return framesPerSecond(forCPUUsage: cpuUsage)
        }
    }

    static func framesPerSecond(forCPUUsage cpuUsage: Double) -> Double {
        let clampedUsage = min(max(cpuUsage, 0), 1)
        let easedUsage = pow(clampedUsage, 0.72)
        let speedMultiplier = 1.0 + easedUsage * (maximumAdaptiveMultiplier - 1.0)
        return referenceFramesPerSecond * speedMultiplier
    }

    static func paceLabel(for playbackMode: PlaybackMode) -> String {
        switch playbackMode {
        case .fixedPreview:
            return String(format: "fixed preview (%.1f fps)", referenceFramesPerSecond)
        case let .adaptive(cpuUsage):
            return paceLabel(forCPUUsage: cpuUsage)
        }
    }

    private static func paceLabel(forCPUUsage cpuUsage: Double) -> String {
        switch cpuUsage {
        case ..<0.2:
            return "steady jog"
        case ..<0.45:
            return "quick jog"
        case ..<0.75:
            return "busy scamper"
        default:
            return "full sprint"
        }
    }
}
