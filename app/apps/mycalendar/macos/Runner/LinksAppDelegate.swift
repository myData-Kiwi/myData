// Links between the myData apps: the macOS runner side of mydata_core's IncomingLinks.
//
// Copy this file into the app's runner (macos/Runner/LinksAppDelegate.swift) and add it to the Runner
// target in Xcode (or to project.pbxproj next to AppDelegate.swift). Then:
//
// 1. AppDelegate.swift: register the forwarder as soon as the delegate exists, so the link that starts
//    the app is not missed:
//
//        @main
//        class AppDelegate: FlutterAppDelegate {
//          override init() {
//            super.init()
//            addApplicationLifecycleDelegate(LinksChannel.shared)
//          }
//          ...
//        }
//
// 2. MainFlutterWindow.swift, in awakeFromNib, after RegisterGeneratedPlugins:
//
//        LinksChannel.shared.attach(messenger: flutterViewController.engine.binaryMessenger, window: self)
//
// 3. Info.plist: register only this app's own scheme (mycontacts, mycalendar or mydata):
//
//        <key>CFBundleURLTypes</key>
//        <array>
//          <dict>
//            <key>CFBundleURLName</key>
//            <string>kiwi.mydata.mycontacts</string>
//            <key>CFBundleTypeRole</key>
//            <string>Viewer</string>
//            <key>CFBundleURLSchemes</key>
//            <array>
//              <string>mycontacts</string>
//            </array>
//          </dict>
//        </array>
//
// 4. Dart: `IncomingLinks(app: MyDataAppId.mycontacts)..start()` and listen to `links`.
//
// What it does: FlutterAppDelegate passes `application(_:open:)` to its lifecycle delegates; this one
// takes only the myData schemes (others are left to plugins), shows the window (the myData app hides it
// instead of quitting), and sends each URL to Dart as "open" on the "mydata/links" channel. Until Dart
// calls "ready", URLs are held (at most 16) and returned as that call's result. This code does not
// validate links: Dart does, and ignores anything that is not a valid link for this app.

import Cocoa
import FlutterMacOS

final class LinksChannel: NSObject, FlutterAppLifecycleDelegate {
  static let shared = LinksChannel()

  /// The schemes the myData apps use. Each app registers only its own in Info.plist.
  private static let schemes: Set<String> = ["mydata", "mycontacts", "mycalendar"]
  private static let maxHeld = 16

  private var channel: FlutterMethodChannel?
  private weak var window: NSWindow?
  private var held: [String] = []
  private var dartReady = false

  /// Connects the channel once the Flutter engine exists. Links that arrived earlier stay held until Dart
  /// asks for them.
  func attach(messenger: FlutterBinaryMessenger, window: NSWindow?) {
    self.window = window
    let channel = FlutterMethodChannel(name: "mydata/links", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self, call.method == "ready" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.dartReady = true
      let out = self.held
      self.held = []
      result(out)
    }
    self.channel = channel
  }

  // FlutterAppLifecycleDelegate: called by FlutterAppDelegate's application(_:open:).
  func handleOpen(_ urls: [URL]) -> Bool {
    let ours = urls.filter { url in
      guard let scheme = url.scheme?.lowercased() else { return false }
      return LinksChannel.schemes.contains(scheme)
    }
    if ours.isEmpty { return false }
    for url in ours {
      let link = url.absoluteString
      if dartReady, let channel {
        channel.invokeMethod("open", arguments: link)
      } else if held.count < LinksChannel.maxHeld {
        held.append(link)
      }
    }
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    return true
  }
}
