import AppKit

@MainActor
final class FactoryPreferences {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults:["showShortcutHints":true,"keepLibraryOnTop":false])
    }
    var showShortcutHints: Bool {
        get { defaults.bool(forKey:"showShortcutHints") }
        set { defaults.set(newValue,forKey:"showShortcutHints") }
    }
    var keepLibraryOnTop: Bool {
        get { defaults.bool(forKey:"keepLibraryOnTop") }
        set { defaults.set(newValue,forKey:"keepLibraryOnTop") }
    }
}

@MainActor
final class SettingsWindow: NSObject {
    let window: NSWindow
    let preferences: FactoryPreferences
    let store: LayoutStore
    var changed: (() -> Void)?
    private let hints = NSButton(checkboxWithTitle:"Show keyboard shortcuts beside actions",target:nil,action:nil)
    private let floating = NSButton(checkboxWithTitle:"Keep the library above other windows",target:nil,action:nil)
    private let access = NSTextField(wrappingLabelWithString:"")
    private var monitor: Any?
    init(store: LayoutStore,preferences: FactoryPreferences) {
        self.store = store; self.preferences = preferences
        window = NSWindow(contentRect:NSRect(x:0,y:0,width:620,height:580),
            styleMask:[.titled,.closable],backing:.buffered,defer:false)
        super.init()
        window.title = "Window Factory Settings"; window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        let general = Self.heading("General")
        for button in [hints,floating] { button.target = self; button.action = #selector(changePreferences) }
        let keys = NSTextField(wrappingLabelWithString:
            "⌘N  Capture a layout\n↑ / ↓  Select a layout\n↩  Restore existing windows    ⌘↩  Establish missing windows\n⌘F  Search    ⌘⌫  Delete selected layout (with confirmation)\n⌘I  Import    ⇧⌘E  Export\n↩  Save a named capture    ⎋  Cancel or close\n⌘,  Settings    ⌘W  Close window    ⌘Q  Quit")
        keys.font = .systemFont(ofSize:13)
        let ownership = NSTextField(wrappingLabelWithString:"These commands work inside Window Factory. Hyper+R and the other global window shortcuts remain with Hammerspoon.")
        ownership.textColor = .secondaryLabelColor
        let permission = NSButton(title:"Open Accessibility Settings…",target:self,action:#selector(openAccess))
        permission.bezelStyle = .rounded
        let version = Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "unknown"
        let location = NSTextField(wrappingLabelWithString:"Version: \(version) (\(build))\nApp: \(Bundle.main.bundlePath)\nLayouts: \(store.url.path)")
        location.font = .systemFont(ofSize:11); location.isSelectable = true
        let folder = NSButton(title:"Show Layout Folder",target:self,action:#selector(showFolder)); folder.bezelStyle = .rounded
        let stack = NSStackView(views:[general,hints,floating,Self.heading("Keyboard commands"),keys,ownership,
            Self.heading("Access and storage"),access,permission,location,folder])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:22),
            stack.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-22),
            stack.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo:window.contentView!.bottomAnchor,constant:-20),
            keys.widthAnchor.constraint(equalTo:stack.widthAnchor),ownership.widthAnchor.constraint(equalTo:stack.widthAnchor),
            access.widthAnchor.constraint(equalTo:stack.widthAnchor),location.widthAnchor.constraint(equalTo:stack.widthAnchor)])
        monitor = NSEvent.addLocalMonitorForEvents(matching:.keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated {
                guard let self, event.window === self.window, event.keyCode == 53 else { return false }
                self.window.close(); return true
            }
            return handled ? nil : event
        }
    }
    static func heading(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString:text); field.font = .systemFont(ofSize:14,weight:.semibold); return field
    }
    func refresh() {
        hints.state = preferences.showShortcutHints ? .on : .off
        floating.state = preferences.keepLibraryOnTop ? .on : .off
        access.stringValue = AXIsProcessTrusted() ? "Accessibility: enabled." : "Accessibility: not enabled. Grant access to this installed app in System Settings, then restart it."
    }
    func show() { window.level = preferences.keepLibraryOnTop ? .floating : .normal; refresh(); window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true) }
    @objc func changePreferences() {
        preferences.showShortcutHints = hints.state == .on
        preferences.keepLibraryOnTop = floating.state == .on
        window.level = preferences.keepLibraryOnTop ? .floating : .normal
        changed?()
    }
    @objc func openAccess() {
        NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc func showFolder() {
        if FileManager.default.fileExists(atPath:store.url.path) { NSWorkspace.shared.activateFileViewerSelecting([store.url]) }
        else {
            let alert = NSAlert(); alert.messageText = "No saved layouts yet"
            alert.informativeText = "The layout folder is created when you save or import your first layout."; alert.runModal()
        }
    }
    func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
}
