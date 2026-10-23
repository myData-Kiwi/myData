import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var shell: MacShellChannels?

  override func awakeFromNib() {
    // The Mac shell's window (MacShell.swift, copied from mydata_ui/macos_snippets): the window's materials
    // behind a transparent Flutter view, so the sidebar can be translucent.
    let flutterViewController = MacShell.install(in: self)
    RegisterGeneratedPlugins(registry: flutterViewController)
    shell = MacShellChannels(messenger: flutterViewController.engine.binaryMessenger)
    LinksChannel.shared.attach(messenger: flutterViewController.engine.binaryMessenger, window: self)

    super.awakeFromNib()
  }
}
