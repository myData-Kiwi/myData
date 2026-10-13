import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override init() {
    super.init()
    // Links from the other myData apps (mycalendar://day/<date>); registered now so the link that starts
    // the app is not missed. See LinksAppDelegate.swift.
    addApplicationLifecycleDelegate(LinksChannel.shared)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
