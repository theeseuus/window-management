import AppKit

@MainActor private final class SettingsDocument: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
final class FactoryPreferences {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults:["showShortcutHints":true,"keepLibraryOnTop":false,"launcherEnabled":true,"showDockIcon":true])
    }
    var showShortcutHints: Bool {
        get { defaults.bool(forKey:"showShortcutHints") }
        set { defaults.set(newValue,forKey:"showShortcutHints") }
    }
    var showDockIcon: Bool {
        get { defaults.bool(forKey:"showDockIcon") }
        set { defaults.set(newValue,forKey:"showDockIcon") }
    }
    var spaceIndicatorEnabled: Bool {
        get { defaults.bool(forKey:"nativeSpaceIndicatorEnabled") }
        set { defaults.set(newValue,forKey:"nativeSpaceIndicatorEnabled") }
    }
    var launcherEnabled: Bool {
        get { defaults.bool(forKey:"launcherEnabled") }
        set { defaults.set(newValue,forKey:"launcherEnabled") }
    }
    var geometryEnabled: Bool {
        get { defaults.bool(forKey:"nativeGeometryEnabled") }
        set { defaults.set(newValue,forKey:"nativeGeometryEnabled") }
    }
    var focusEnabled: Bool {
        get { defaults.bool(forKey:"nativeFocusEnabled") }
        set { defaults.set(newValue,forKey:"nativeFocusEnabled") }
    }
    var stashEnabled: Bool {
        get { defaults.bool(forKey:"nativeStashEnabled") }
        set { defaults.set(newValue,forKey:"nativeStashEnabled") }
    }
    var spaceMoveEnabled: Bool {
        get { defaults.bool(forKey:"nativeSpaceMoveEnabled") }
        set { defaults.set(newValue,forKey:"nativeSpaceMoveEnabled") }
    }
    var accordionEnabled: Bool {
        get { defaults.bool(forKey:"nativeAccordionEnabled") }
        set { defaults.set(newValue,forKey:"nativeAccordionEnabled") }
    }
    var switcherEnabled: Bool {
        get { defaults.bool(forKey:"nativeSwitcherEnabled") }
        set { defaults.set(newValue,forKey:"nativeSwitcherEnabled") }
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
    weak var launcher: LauncherControls?
    private let launcherEnabled = NSButton(checkboxWithTitle:"Enable Tab+R launcher",target:nil,action:nil)
    private let launcherStatus = NSTextField(wrappingLabelWithString:"")
    private let loginEnabled = NSButton(checkboxWithTitle:"Start Window Factory at login",target:nil,action:nil)
    private let loginStatus = NSTextField(wrappingLabelWithString:"")
    weak var spaceIndicator: SpaceIndicator?
    private let indicatorEnabled = NSButton(checkboxWithTitle:"Show menu-bar Space indicator",target:nil,action:nil)
    private let indicatorStatus = NSTextField(wrappingLabelWithString:"")
    weak var spaceMove: DirectSpaceMoveControls?
    private let spaceMoveEnabled = NSButton(checkboxWithTitle:"Enable native Space move-and-follow shortcuts",target:nil,action:nil)
    private let spaceMoveStatus = NSTextField(wrappingLabelWithString:"")
    weak var accordion: DirectAccordionControls?
    private let accordionEnabled = NSButton(checkboxWithTitle:"Enable native accordion shortcut",target:nil,action:nil)
    private let accordionStatus = NSTextField(wrappingLabelWithString:"")
    weak var switcher: DirectSwitcherControls?
    private let switcherEnabled = NSButton(checkboxWithTitle:"Enable native window switching shortcuts",target:nil,action:nil)
    private let switcherStatus = NSTextField(wrappingLabelWithString:"")
    weak var stash: DirectStashControls?
    private let stashEnabled = NSButton(checkboxWithTitle:"Enable native stash/restore shortcut",target:nil,action:nil)
    private let stashStatus = NSTextField(wrappingLabelWithString:"")
    var onShortcuts: (() -> Void)?
    weak var focus: DirectFocusControls?
    private let focusEnabled = NSButton(checkboxWithTitle:"Enable native directional focus shortcuts",target:nil,action:nil)
    private let focusStatus = NSTextField(wrappingLabelWithString:"")
    weak var geometry: DirectWindowControls?
    private let geometryEnabled = NSButton(checkboxWithTitle:"Enable native geometry shortcuts",target:nil,action:nil)
    private let geometryStatus = NSTextField(wrappingLabelWithString:"")
    private let dockIcon = NSButton(checkboxWithTitle:"Show Dock icon",target:nil,action:nil)
    private let hints = NSButton(checkboxWithTitle:"Show keyboard shortcuts beside actions",target:nil,action:nil)
    private let floating = NSButton(checkboxWithTitle:"Keep the library above other windows",target:nil,action:nil)
    private let access = NSTextField(wrappingLabelWithString:"")
    private var monitor: Any?
    init(store: LayoutStore,preferences: FactoryPreferences) {
        self.store = store; self.preferences = preferences
        window = NSWindow(contentRect:NSRect(x:0,y:0,width:660,height:min(900,max(500,(NSScreen.main?.visibleFrame.height ?? 1000)-100))),
            styleMask:[.titled,.closable],backing:.buffered,defer:false)
        super.init()
        window.title = "Window Factory Settings"; window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        let general = Self.heading("General")
        dockIcon.target = self; dockIcon.action = #selector(changeDockIcon)
        let dockHelp = NSTextField(wrappingLabelWithString:"When hidden, Window Factory stays out of the Dock and Command+Tab. Use its menu-bar badge, Tab+R, or reopen it from Applications.")
        dockHelp.font = .systemFont(ofSize:12)
        launcherEnabled.target = self; launcherEnabled.action = #selector(changeLauncher)
        loginEnabled.target = self; loginEnabled.action = #selector(changeLogin)
        loginEnabled.allowsMixedState = true
        for label in [launcherStatus,loginStatus] { label.font = .systemFont(ofSize:11); label.textColor = .secondaryLabelColor }
        let loginSettings = NSButton(title:"Login Items Settings…",target:self,action:#selector(openLoginSettings)); loginSettings.bezelStyle = .rounded
        let launcherHelp = NSTextField(wrappingLabelWithString:"Tab+R works while Window Factory is running. After quitting, reopen it from the Dock or Applications. Start at login makes it available after signing in.")
        launcherHelp.font = .systemFont(ofSize:12)
        indicatorEnabled.target = self; indicatorEnabled.action = #selector(changeIndicator)
        indicatorStatus.font = .systemFont(ofSize:11); indicatorStatus.textColor = .secondaryLabelColor
        spaceMoveEnabled.target = self; spaceMoveEnabled.action = #selector(changeSpaceMove)
        spaceMoveStatus.font = .systemFont(ofSize:11); spaceMoveStatus.textColor = .secondaryLabelColor
        accordionEnabled.target = self; accordionEnabled.action = #selector(changeAccordion)
        accordionStatus.font = .systemFont(ofSize:11); accordionStatus.textColor = .secondaryLabelColor
        switcherEnabled.target = self; switcherEnabled.action = #selector(changeSwitcher)
        switcherStatus.font = .systemFont(ofSize:11); switcherStatus.textColor = .secondaryLabelColor
        stashEnabled.target = self; stashEnabled.action = #selector(changeStash)
        stashStatus.font = .systemFont(ofSize:11); stashStatus.textColor = .secondaryLabelColor
        let reference = NSButton(title:"Keyboard Shortcuts…  ⌘?",target:self,action:#selector(openShortcuts)); reference.bezelStyle = .rounded
        focusEnabled.target = self; focusEnabled.action = #selector(changeFocus)
        focusStatus.font = .systemFont(ofSize:11); focusStatus.textColor = .secondaryLabelColor
        let focusKeys = NSTextField(wrappingLabelWithString:"Hold Tab + H/J/K/L: focus left/down/up/right. Same display first; current visible ordinary desktops only.")
        focusKeys.font = .systemFont(ofSize:12)
        geometryEnabled.target = self; geometryEnabled.action = #selector(changeGeometry)
        geometryStatus.font = .systemFont(ofSize:11); geometryStatus.textColor = .secondaryLabelColor
        let geometryKeys = NSTextField(wrappingLabelWithString:"Hold Tab for Hyper (⌃⌥⌘).\n− / =  Size / position cycles; add Shift to reverse\n2 / 3 / 4 / 8  Halves / thirds / quarters / eighths; Shift reverses\n↑ / ↓  Centred half / previous frame     [ / ]  Narrow / widen\n↩  Centre horizontally     ⇧↩  Maximize     D  Minimize\nSpace movement has its own native pilot below.")
        geometryKeys.font = .systemFont(ofSize:12)
        for button in [hints,floating] { button.target = self; button.action = #selector(changePreferences) }
        let keys = NSTextField(wrappingLabelWithString:
            "⌘N  Capture a layout\n↑ / ↓  Select a layout\n↩  Restore existing windows    ⌘↩  Establish missing windows\n⌘F  Search    ⌘⌫  Delete selected layout (with confirmation)\n⌘I  Import    ⇧⌘E  Export\n↩  Save a named capture    ⎋  Cancel or close\n⌘,  Settings    ⌘W  Close window    ⌘Q  Quit")
        keys.font = .systemFont(ofSize:13)
        let ownership = NSTextField(wrappingLabelWithString:"These commands work inside the library. The geometry group is shown below. Window Factory owns the direct controls and Tab+R launcher. Tab+Shift+R remains the Hammerspoon library fallback.")
        ownership.textColor = .secondaryLabelColor
        let permission = NSButton(title:"Open Accessibility Settings…",target:self,action:#selector(openAccess))
        permission.bezelStyle = .rounded
        let version = Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "unknown"
        let location = NSTextField(wrappingLabelWithString:"Version: \(version) (\(build))\nApp: \(Bundle.main.bundlePath)\nLayouts: \(store.url.path)")
        location.font = .systemFont(ofSize:11); location.isSelectable = true
        let folder = NSButton(title:"Show Layout Folder",target:self,action:#selector(showFolder)); folder.bezelStyle = .rounded
        let stack = NSStackView(views:[general,dockIcon,dockHelp,launcherEnabled,launcherStatus,loginEnabled,loginStatus,loginSettings,launcherHelp,hints,floating,indicatorEnabled,indicatorStatus,reference,Self.heading("Keyboard commands"),keys,ownership,
            Self.heading("Direct window controls — geometry pilot"),geometryEnabled,geometryStatus,geometryKeys,
            Self.heading("Directional focus — pilot"),focusEnabled,focusStatus,focusKeys,
            Self.heading("Stash / restore — pilot"),stashEnabled,stashStatus,
            Self.heading("Window switching — pilot"),switcherEnabled,switcherStatus,
            Self.heading("Accordion — pilot"),accordionEnabled,accordionStatus,
            Self.heading("Space move-and-follow — pilot"),spaceMoveEnabled,spaceMoveStatus,
            Self.heading("Access and storage"),access,permission,location,folder])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let document = SettingsDocument(); document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document; document.addSubview(stack); window.contentView!.addSubview(scroll)
        NSLayoutConstraint.activate([scroll.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor),
            scroll.topAnchor.constraint(equalTo:window.contentView!.topAnchor),
            scroll.bottomAnchor.constraint(equalTo:window.contentView!.bottomAnchor),
            document.leadingAnchor.constraint(equalTo:scroll.contentView.leadingAnchor),
            document.topAnchor.constraint(equalTo:scroll.contentView.topAnchor),
            document.widthAnchor.constraint(equalTo:scroll.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo:document.leadingAnchor,constant:22),
            stack.trailingAnchor.constraint(equalTo:document.trailingAnchor,constant:-22),
            stack.topAnchor.constraint(equalTo:document.topAnchor,constant:20),
            stack.bottomAnchor.constraint(equalTo:document.bottomAnchor,constant:-20)])
        for label in [keys,ownership,access,location,dockHelp,launcherHelp,launcherStatus,loginStatus,indicatorStatus,geometryKeys,focusKeys,geometryStatus,focusStatus,stashStatus,switcherStatus,accordionStatus,spaceMoveStatus] {
            label.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive = true
        }
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
    @objc func changeDockIcon() {
        let show = dockIcon.state == .on
        guard NSApp.setActivationPolicy(show ? .regular : .accessory) else {
            let alert = NSAlert(); alert.messageText = "Dock icon could not be changed"; alert.runModal(); refresh(); return
        }
        preferences.showDockIcon = show
        refresh()
    }
    @objc func changeLauncher() {
        guard let launcher else { return }
        if launcherEnabled.state == .on {
            do { try launcher.enable() }
            catch { let alert = NSAlert(); alert.messageText = "Tab+R was not enabled"; alert.informativeText = error.localizedDescription; alert.runModal() }
        } else { launcher.disable() }
        refresh()
    }
    @objc func changeLogin() {
        guard let launcher else { return }
        launcher.refreshLoginState()
        launcher.setLoginEnabled(launcher.loginState != .enabled && launcher.loginState != .requiresApproval); refresh()
    }
    @objc func openLoginSettings() { launcher?.openLoginSettings() }
    @objc func changeIndicator() {
        guard let spaceIndicator else { return }
        if indicatorEnabled.state == .on { spaceIndicator.enable() } else { spaceIndicator.disable() }
        refresh()
    }
    @objc func changeSpaceMove() {
        guard let spaceMove else { return }
        if spaceMoveEnabled.state == .on {
            do { try spaceMove.enable() }
            catch { let alert = NSAlert(); alert.messageText = "Space movement was not enabled"; alert.informativeText = error.localizedDescription; alert.runModal() }
        } else { spaceMove.disable() }
        refresh()
    }
    @objc func changeAccordion() {
        guard let accordion else { return }
        if accordionEnabled.state == .on {
            do { try accordion.enable() }
            catch { let alert = NSAlert(); alert.messageText = "Accordion was not enabled"; alert.informativeText = error.localizedDescription; alert.runModal() }
        } else { accordion.disable() }
        refresh()
    }
    @objc func changeGeometry() {
        guard let geometry else { return }
        if geometryEnabled.state == .on {
            do { try geometry.enable() }
            catch { let alert = NSAlert(); alert.messageText = "Geometry shortcuts were not enabled"; alert.informativeText = error.localizedDescription; alert.runModal() }
        } else { geometry.disable() }
        refresh()
    }
    @objc func changeSwitcher() {
        guard let switcher else { return }
        if switcherEnabled.state == .on {
            do { try switcher.enable() }
            catch { let alert = NSAlert(); alert.messageText = "Switcher shortcuts were not enabled"; alert.informativeText = error.localizedDescription; alert.runModal() }
        } else { switcher.disable() }
        refresh()
    }
    @objc func openShortcuts() { onShortcuts?() }
    @objc func changeStash() {
        guard let stash else { return }
        if stashEnabled.state == .on {
            do { try stash.enable() }
            catch { let alert = NSAlert(); alert.messageText = "Stash shortcut was not enabled"; alert.informativeText = error.localizedDescription; alert.runModal() }
        } else { stash.disable() }
        refresh()
    }
    @objc func changeFocus() {
        guard let focus else { return }
        if focusEnabled.state == .on {
            do { try focus.enable() }
            catch { let alert = NSAlert(); alert.messageText = "Directional focus was not enabled"; alert.informativeText = error.localizedDescription; alert.runModal() }
        } else { focus.disable() }
        refresh()
    }
    func refresh() {
        dockIcon.state = preferences.showDockIcon ? .on : .off
        launcherEnabled.state = launcher?.active == true ? .on : .off
        launcherEnabled.isEnabled = launcher != nil
        launcherStatus.stringValue = launcher?.lastResult ?? "Unavailable in preview."
        loginEnabled.isEnabled = launcher?.loginAvailable == true
        if let launcher {
            switch launcher.loginState {
            case .enabled: loginEnabled.state = .on
            case .requiresApproval: loginEnabled.state = .mixed
            default: loginEnabled.state = .off
            }
        } else { loginEnabled.state = .off }
        loginStatus.stringValue = launcher?.loginDescription ?? "Unavailable in preview."
        indicatorEnabled.state = spaceIndicator?.active == true ? .on : .off
        indicatorEnabled.isEnabled = spaceIndicator != nil
        indicatorStatus.stringValue = spaceIndicator?.lastResult ?? "Unavailable in preview."
        spaceMoveEnabled.state = spaceMove?.active == true ? .on : .off
        spaceMoveEnabled.isEnabled = spaceMove != nil
        spaceMoveStatus.stringValue = spaceMove?.lastResult ?? "Unavailable in preview."
        accordionEnabled.state = accordion?.active == true ? .on : .off
        accordionEnabled.isEnabled = accordion != nil
        accordionStatus.stringValue = accordion?.lastResult ?? "Unavailable in preview."
        switcherEnabled.state = switcher?.active == true ? .on : .off
        switcherEnabled.isEnabled = switcher != nil
        switcherStatus.stringValue = switcher?.lastResult ?? "Unavailable in preview."
        stashEnabled.state = stash?.active == true ? .on : .off
        stashEnabled.isEnabled = stash != nil
        stashStatus.stringValue = stash?.lastResult ?? "Unavailable in preview."
        focusEnabled.state = focus?.active == true ? .on : .off
        focusEnabled.isEnabled = focus != nil
        focusStatus.stringValue = focus?.lastResult ?? "Unavailable in preview."
        geometryEnabled.state = geometry?.active == true ? .on : .off
        geometryEnabled.isEnabled = geometry != nil
        geometryStatus.stringValue = geometry?.lastResult ?? "Unavailable in preview."

        hints.state = preferences.showShortcutHints ? .on : .off
        floating.state = preferences.keepLibraryOnTop ? .on : .off
        access.stringValue = AXIsProcessTrusted() ? "Accessibility: enabled." : "Accessibility: not enabled. Grant access to this installed app in System Settings, then restart it."
    }
    func show() { launcher?.refreshLoginState(); window.level = preferences.keepLibraryOnTop ? .floating : .normal; refresh(); window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true) }
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
