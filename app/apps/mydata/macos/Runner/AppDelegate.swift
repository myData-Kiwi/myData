import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Registered as soon as the delegate exists, so a mydata://settings/sources link that starts the app is
  // not missed (LinksAppDelegate.swift). It also shows the hidden window.
  override init() {
    super.init()
    addApplicationLifecycleDelegate(LinksChannel.shared)
  }

  // Closing the window only hides it; the app keeps running in the menu bar until Quit.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  // Clicking the Dock icon, or `open`ing the app again, shows the hidden window.
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      mainFlutterWindow?.makeKeyAndOrderFront(nil)
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
