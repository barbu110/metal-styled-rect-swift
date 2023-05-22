import Cocoa
import MetalKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!
    let windowDelegate = WindowDelegate()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        window.delegate = windowDelegate
        
        let metalLayerView = MetalLayerView(frame: NSRect(origin: .zero, size: window.frame.size))
        window.contentView = metalLayerView
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

class WindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.terminate(self)
    }
}
