import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBarController = StatusBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController.stop()
    }
}
