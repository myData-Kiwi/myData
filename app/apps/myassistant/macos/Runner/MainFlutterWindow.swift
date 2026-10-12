import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var accessibility: AccessibilityChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    accessibility = AccessibilityChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// Tells Dart the system's reduced-motion and reduced-transparency settings, now and when they change.
/// Flutter has no reduced-transparency flag; mydata_ui's MyDataAccessibilityScope reads this channel.
final class AccessibilityChannel {
  private let channel: FlutterMethodChannel
  private var observer: NSObjectProtocol?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "mydata/accessibility", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      if call.method == "get" {
        result(AccessibilityChannel.current())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.channel.invokeMethod("changed", arguments: AccessibilityChannel.current())
    }
  }

  deinit {
    if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
  }

  private static func current() -> [String: Bool] {
    [
      "reduceMotion": NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
      "reduceTransparency": NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
    ]
  }
}
