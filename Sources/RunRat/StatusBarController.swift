import AppKit

@MainActor
final class StatusBarController {
    private enum DefaultsKey {
        static let usesFixedPreviewSpeed = "usesFixedPreviewSpeed"
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: RatRenderer.canvasSize.width + 2)
    private let menu = NSMenu()
    private let cpuUsageItem = NSMenuItem(title: "CPU usage: --", action: nil, keyEquivalent: "")
    private let paceItem = NSMenuItem(title: "Rat pace: warming up", action: nil, keyEquivalent: "")
    private let playbackItem = NSMenuItem(title: "Playback: --", action: nil, keyEquivalent: "")
    private let fixedPreviewItem = NSMenuItem(title: "Use Fixed Preview Speed", action: #selector(toggleFixedPreviewSpeed), keyEquivalent: "f")
    private let cpuMonitor = CPUUsageMonitor()

    private var animator = RatAnimator(frameCount: RatRenderer.frameCount)
    private var animationTimer: Timer?
    private var cpuTimer: Timer?
    private var cpuUsage = 0.0
    private var usesFixedPreviewSpeed = UserDefaults.standard.bool(forKey: DefaultsKey.usesFixedPreviewSpeed)
    private var lastAnimationTick = Date()

    func start() {
        configureMenu()
        refreshIcon()
        sampleCPU()

        animationTimer = Timer.scheduledTimer(
            timeInterval: 1.0 / 60.0,
            target: self,
            selector: #selector(handleAnimationTick),
            userInfo: nil,
            repeats: true
        )

        cpuTimer = Timer.scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(handleCPUTick),
            userInfo: nil,
            repeats: true
        )
    }

    func stop() {
        animationTimer?.invalidate()
        cpuTimer?.invalidate()
    }

    private func configureMenu() {
        cpuUsageItem.isEnabled = false
        paceItem.isEnabled = false
        playbackItem.isEnabled = false
        fixedPreviewItem.target = self
        fixedPreviewItem.state = usesFixedPreviewSpeed ? .on : .off

        let quitItem = NSMenuItem(title: "Quit RunRat", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self

        menu.autoenablesItems = false
        menu.items = [
            cpuUsageItem,
            paceItem,
            playbackItem,
            fixedPreviewItem,
            .separator(),
            quitItem,
        ]

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
            button.toolTip = "RunRat"
        }

        statusItem.menu = menu
    }

    private var playbackMode: RatAnimator.PlaybackMode {
        usesFixedPreviewSpeed ? .fixedPreview : .adaptive(cpuUsage: cpuUsage)
    }

    private func refreshIcon() {
        statusItem.button?.image = RatRenderer.cachedImage(frameIndex: animator.frameIndex)
        let fps = RatAnimator.framesPerSecond(for: playbackMode)
        let modeLabel = usesFixedPreviewSpeed ? "fixed" : "adaptive"
        statusItem.button?.toolTip = String(
            format: "RunRat - CPU %d%% - %@ %.1f fps",
            Int((cpuUsage * 100).rounded()),
            modeLabel,
            fps
        )
    }

    private func updateMenuText() {
        let percentage = Int((cpuUsage * 100).rounded())
        cpuUsageItem.title = "CPU usage: \(percentage)%"
        paceItem.title = "Rat pace: \(RatAnimator.paceLabel(for: playbackMode))"
        playbackItem.title = String(format: "Playback: %.1f fps", RatAnimator.framesPerSecond(for: playbackMode))
        fixedPreviewItem.state = usesFixedPreviewSpeed ? .on : .off
    }

    private func sampleCPU() {
        cpuUsage = cpuMonitor.sampleUsage()
        updateMenuText()
    }

    @objc private func handleAnimationTick() {
        let now = Date()
        let delta = now.timeIntervalSince(lastAnimationTick)
        lastAnimationTick = now

        let clampedDelta = min(delta, 0.05)

        guard animator.tick(deltaTime: clampedDelta, playbackMode: playbackMode) else {
            return
        }

        refreshIcon()
    }

    @objc private func handleCPUTick() {
        sampleCPU()
        refreshIcon()
    }

    @objc private func toggleFixedPreviewSpeed() {
        usesFixedPreviewSpeed.toggle()
        UserDefaults.standard.set(usesFixedPreviewSpeed, forKey: DefaultsKey.usesFixedPreviewSpeed)
        updateMenuText()
        refreshIcon()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
