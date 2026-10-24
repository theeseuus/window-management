import AppKit

@MainActor final class WindowControlPilot: NSObject,NSApplicationDelegate,NSWindowDelegate {
    var window: NSWindow?
    let frameLabel = NSTextField(labelWithString:"")
    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:640,height:420),
            styleMask:[.titled,.closable,.resizable,.miniaturizable],backing:.buffered,defer:false)
        window.title = "Window Factory — Disposable Control Test"
        window.delegate = self
        window.minSize = NSSize(width:80,height:80); window.collectionBehavior = [.moveToActiveSpace]
        let text = NSTextField(wrappingLabelWithString:"Disposable window-control test\n\nKeep this window focused while trying the existing Tab-held shortcuts.\n\n2 / 3 / 4 / 8: position cycles (Shift reverses)\n− / =: canonical size / position (Shift reverses)\n↑ then ↓: centred half and previous frame\n↩: centre horizontally; ⇧↩: maximize\n[ / ]: narrow / widen; D: minimize\n\nClick this app in the Dock to bring it back after minimizing.\nClose its red button when finished. No documents or terminal sessions are involved.")
        text.font = .systemFont(ofSize:15); text.translatesAutoresizingMaskIntoConstraints = false
        frameLabel.font = .monospacedSystemFont(ofSize:12,weight:.medium)
        frameLabel.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(frameLabel)
        window.contentView!.addSubview(text)
        NSLayoutConstraint.activate([text.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:18),
            text.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-18),
            frameLabel.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:16),
            frameLabel.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:18),
            frameLabel.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-18),
            text.topAnchor.constraint(equalTo:frameLabel.bottomAnchor,constant:12)])
        let menu = NSMenu(), item = NSMenuItem(), appMenu = NSMenu()
        appMenu.addItem(withTitle:"Quit Window Control Test",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
        item.submenu = appMenu; menu.addItem(item); NSApp.mainMenu = menu
        self.window = window; window.center(); reportFrame(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    func reportFrame() {
        guard let window else { return }
        let f = window.frame, top = NSScreen.screens.first?.frame.maxY ?? 0
        frameLabel.stringValue = String(format:"Frame: x %.0f · y %.0f · width %.0f · height %.0f",f.minX,top-f.maxY,f.width,f.height)
    }
    func windowDidMove(_ notification: Notification) { reportFrame() }
    func windowDidResize(_ notification: Notification) { reportFrame() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldHandleReopen(_ sender: NSApplication,hasVisibleWindows flag: Bool) -> Bool {
        window?.deminiaturize(nil); window?.makeKeyAndOrderFront(nil); return true
    }
}
@main enum PilotMain {
    @MainActor static func main() {
        let app = NSApplication.shared; app.setActivationPolicy(.regular)
        let delegate = WindowControlPilot(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
