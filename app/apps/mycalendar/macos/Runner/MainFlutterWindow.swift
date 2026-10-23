import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var shell: MacShellChannels?
  private var zones: ZonesChannel?

  override func awakeFromNib() {
    // The Mac shell's window (MacShell.swift, copied from mydata_ui/macos_snippets): the window's materials
    // behind a transparent Flutter view, so the sidebar can be translucent. 1280 by 900, as MainMenu.xib
    // has it: six weeks at a readable cell height beside the day list.
    let flutterViewController = MacShell.install(in: self, size: NSSize(width: 1280, height: 900))
    RegisterGeneratedPlugins(registry: flutterViewController)
    shell = MacShellChannels(messenger: flutterViewController.engine.binaryMessenger)
    zones = ZonesChannel(messenger: flutterViewController.engine.binaryMessenger)
    LinksChannel.shared.attach(messenger: flutterViewController.engine.binaryMessenger, window: self)

    super.awakeFromNib()
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
