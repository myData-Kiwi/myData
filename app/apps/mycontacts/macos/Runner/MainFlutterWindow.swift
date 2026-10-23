import Cocoa
import FlutterMacOS
import macos_window_utils

class MainFlutterWindow: NSWindow {
  private var accessibility: AccessibilityChannel?
  private var systemColors: SystemColorsChannel?

  override func awakeFromNib() {
    // macos_window_utils' view controller: the window's materials behind a transparent Flutter view, so the
    // Mac frame's sidebar can be translucent (mycontacts/lib/src/mac_window.dart).
    let windowUtils = MacOSWindowUtilsViewController()
    let flutterViewController = windowUtils.flutterViewController
    self.contentViewController = windowUtils
    // The first window's size (as the M1a stack gate compared it with Contacts.app); the system restores the
    // user's size later.
    self.setContentSize(NSSize(width: 1280, height: 800))
    self.minSize = NSSize(width: 720, height: 480)
    self.center()
    MainFlutterWindowManipulator.start(mainFlutterWindow: self)

    RegisterGeneratedPlugins(registry: flutterViewController)
    accessibility = AccessibilityChannel(messenger: flutterViewController.engine.binaryMessenger)
    systemColors = SystemColorsChannel(messenger: flutterViewController.engine.binaryMessenger)
    LinksChannel.shared.attach(messenger: flutterViewController.engine.binaryMessenger, window: self)

    super.awakeFromNib()
  }
}

/// Tells Dart the system's colours, the accent among them, in the light and the dark appearance, now and when
/// the user changes them (mydata_ui's MacSystemColorsScope, token names from design/tokens.json "macos").
final class SystemColorsChannel {
  private let channel: FlutterMethodChannel
  private var observers: [NSObjectProtocol] = []

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "mydata/system_colors", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      if call.method == "get" {
        result(SystemColorsChannel.current())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    let changed: (Notification) -> Void = { [weak self] _ in
      self?.channel.invokeMethod("changed", arguments: SystemColorsChannel.current())
    }
    observers.append(NotificationCenter.default.addObserver(
      forName: NSColor.systemColorsDidChangeNotification, object: nil, queue: .main, using: changed))
    observers.append(DistributedNotificationCenter.default().addObserver(
      forName: NSNotification.Name("AppleColorPreferencesChangedNotification"), object: nil, queue: .main,
      using: changed))
  }

  deinit {
    for o in observers {
      NotificationCenter.default.removeObserver(o)
      DistributedNotificationCenter.default().removeObserver(o)
    }
  }

  private static let colors: [(String, NSColor)] = [
    ("accent", .controlAccentColor),
    ("on-accent", .alternateSelectedControlTextColor),
    ("label", .labelColor),
    ("secondary-label", .secondaryLabelColor),
    ("tertiary-label", .tertiaryLabelColor),
    ("quaternary-label", .quaternaryLabelColor),
    ("separator", .separatorColor),
    ("content-background", .controlBackgroundColor),
    ("window-background", .windowBackgroundColor),
    ("selection-inactive", .unemphasizedSelectedContentBackgroundColor),
  ]

  /// Each colour as 0xAARRGGBB in sRGB, resolved in [appearance].
  private static func resolve(_ appearance: NSAppearance.Name) -> [String: Int] {
    var out: [String: Int] = [:]
    NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
      for (name, color) in colors {
        guard let c = color.usingColorSpace(.sRGB) else { continue }
        func byte(_ v: CGFloat) -> Int { Int((max(0, min(1, v)) * 255).rounded()) }
        out[name] = byte(c.alphaComponent) << 24 | byte(c.redComponent) << 16 | byte(c.greenComponent) << 8
          | byte(c.blueComponent)
      }
    }
    return out
  }

  private static func current() -> [String: [String: Int]] {
    ["light": resolve(.aqua), "dark": resolve(.darkAqua)]
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
