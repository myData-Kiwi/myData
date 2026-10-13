import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Registered as soon as the delegate exists, so the link that starts the app is not missed.
  override init() {
    super.init()
    addApplicationLifecycleDelegate(LinksChannel.shared)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
