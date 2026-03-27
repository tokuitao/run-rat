import AppKit

@MainActor
final class StatusBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let cpuUsageItem = NSMenuItem(title: "CPU usage: --", action: nil, keyEquivalent: "")
    private let paceItem = NSMenuItem(title: "Rat pace: warming up", action: nil, keyEquivalent: "")
    private let cpuMonitor = CPUUsageMonitor()

    private var animator = RatAnimator(frameCount: RatRenderer.poses.count)
    private var animationTimer: Timer?
    private var cpuTimer: Timer?
    private var cpuUsage = 0.0
    private var lastAnimationTick = Date()

    func start() {
        configureMenu()
        refreshIcon()
        sampleCPU()

        animationTimer = Timer.scheduledTimer(
            timeInterval: 1.0 / 30.0,
            target: self,
            selector: #selector(handleAnimationTick),
            userInfo: nil,
            repeats: true
        )

        cpuTimer = Timer.scheduledTimer(
            timeInterval: 1.0,
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

        menu.autoenablesItems = false
        menu.items = [
            cpuUsageItem,
            paceItem,
            .separator(),
            NSMenuItem(title: "Quit RunRat", action: #selector(quit), keyEquivalent: "q"),
        ]

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = "RunRat"
        }

        statusItem.menu = menu
    }

    private func refreshIcon() {
        statusItem.button?.image = RatRenderer.makeImage(frameIndex: animator.frameIndex)
        statusItem.button?.toolTip = "RunRat - CPU \(Int((cpuUsage * 100).rounded()))%"
    }

    private func updateMenuText() {
        let percentage = Int((cpuUsage * 100).rounded())
        cpuUsageItem.title = "CPU usage: \(percentage)%"
        paceItem.title = "Rat pace: \(RatAnimator.paceLabel(for: cpuUsage))"
    }

    private func sampleCPU() {
        cpuUsage = cpuMonitor.sampleUsage()
        updateMenuText()
    }

    @objc private func handleAnimationTick() {
        let now = Date()
        let delta = now.timeIntervalSince(lastAnimationTick)
        lastAnimationTick = now

        guard animator.tick(deltaTime: delta, cpuUsage: cpuUsage) else {
            return
        }

        refreshIcon()
    }

    @objc private func handleCPUTick() {
        sampleCPU()
        refreshIcon()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
