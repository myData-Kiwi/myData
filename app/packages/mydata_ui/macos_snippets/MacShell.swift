// The Mac shell's Runner side (mydata_ui: lib/src/mac/mac_shell.dart). Copy this file unchanged into an
// app's macos/Runner, add it to the Runner target, and in MainFlutterWindow:
//
//   class MainFlutterWindow: NSWindow {
//     private var shell: MacShellChannels?
//
//     override func awakeFromNib() {
//       let flutterViewController = MacShell.install(in: self)  // or install(in: self, project: project)
//       RegisterGeneratedPlugins(registry: flutterViewController)
//       shell = MacShellChannels(messenger: flutterViewController.engine.binaryMessenger)
//       super.awakeFromNib()
//     }
//   }
//
// It replaces the app's own AccessibilityChannel (delete that class). Dart then calls MacShell.setUp()
// before runApp. macos_window_utils comes with mydata_ui; RegisterGeneratedPlugins registers it.

import Cocoa
import FlutterMacOS
import macos_window_utils

enum MacShell {
  /// Puts Flutter's view into [window] behind macos_window_utils' view controller, so the window's own
  /// materials (the translucent sidebar) show through, at [size] the first time (the system restores the
  /// user's size later), at least [minSize]. Returns the FlutterViewController for the plugins and channels.
  static func install(
    in window: NSWindow,
    project: FlutterDartProject? = nil,
    size: NSSize = NSSize(width: 1280, height: 800),
    minSize: NSSize = NSSize(width: 720, height: 480)
  ) -> FlutterViewController {
    let flutterViewController = project.map { FlutterViewController(project: $0) } ?? FlutterViewController()
    window.contentViewController = MacOSWindowUtilsViewController(flutterViewController: flutterViewController)
    window.setContentSize(size)
    window.minSize = minSize
    window.center()
    MainFlutterWindowManipulator.start(mainFlutterWindow: window)
    return flutterViewController
  }
}

/// The system settings the Mac shell follows: its colours (the accent among them) and reduced motion and
/// transparency. Keep it for the window's life.
final class MacShellChannels {
  private let systemColors: SystemColorsChannel
  private let accessibility: AccessibilityChannel

  init(messenger: FlutterBinaryMessenger) {
    systemColors = SystemColorsChannel(messenger: messenger)
    accessibility = AccessibilityChannel(messenger: messenger)
  }
}

/// Tells Dart the system's colours, the accent among them, in the light and the dark appearance, now and when
/// the user changes them (mydata_ui's MacSystemColorsScope, token names from design/tokens.json "macos").
final class SystemColorsChannel {
  private let channel: FlutterMethodChannel
  private var observers: [(NotificationCenter, NSObjectProtocol)] = []

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
    let local = NotificationCenter.default
    observers.append((local, local.addObserver(
      forName: NSColor.systemColorsDidChangeNotification, object: nil, queue: .main, using: changed)))
    let distributed = DistributedNotificationCenter.default()
    observers.append((distributed, distributed.addObserver(
      forName: NSNotification.Name("AppleColorPreferencesChangedNotification"), object: nil, queue: .main,
      using: changed)))
  }

  deinit {
    for (center, observer) in observers { center.removeObserver(observer) }
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
    ("focus-ring", .keyboardFocusIndicatorColor),
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
