import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var accessibility: AccessibilityChannel?
  private var zones: ZonesChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    accessibility = AccessibilityChannel(messenger: flutterViewController.engine.binaryMessenger)
    zones = ZonesChannel(messenger: flutterViewController.engine.binaryMessenger)
    LinksChannel.shared.attach(messenger: flutterViewController.engine.binaryMessenger, window: self)

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

/// Time zone offsets from the system's time zone database, for an event set in a zone other than this
/// Mac's: Dart knows only the device's zone and UTC. "offsets" takes a list of [zone id, milliseconds since
/// the epoch] pairs and answers, for each, the zone's offset from UTC in seconds at that instant, or nil
/// for a zone macOS does not know. It reads nothing but the time zone database.
final class ZonesChannel {
  private let channel: FlutterMethodChannel
  private static let maxPairs = 4096

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "mycalendar/zones", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "offsets", let pairs = call.arguments as? [[Any]], pairs.count <= ZonesChannel.maxPairs
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(pairs.map { pair -> Any in
        guard pair.count == 2, let id = pair[0] as? String, let ms = (pair[1] as? NSNumber)?.doubleValue,
              let zone = TimeZone(identifier: id)
        else { return NSNull() }
        return zone.secondsFromGMT(for: Date(timeIntervalSince1970: ms / 1000))
      })
    }
  }
}
