import AppKit

@MainActor
final class ShortcutReferenceWindow: NSObject {
    let window: NSWindow
    private let preferences: FactoryPreferences
    private let text = NSTextView()
    private let restore = NSButton(title:"Restore last stashed window",target:nil,action:nil)
    weak var accordion: DirectAccordionControls?
    weak var geometry: DirectWindowControls?
    weak var focus: DirectFocusControls?
    weak var switcher: DirectSwitcherControls?
    weak var stash: DirectStashControls?
    private var monitor: Any?
    init(preferences: FactoryPreferences) {
        self.preferences = preferences
        window = NSWindow(contentRect:NSRect(x:0,y:0,width:720,height:720),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        super.init()
        window.title = "Window Factory Keyboard Shortcuts"; window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]; window.minSize = NSSize(width:560,height:420)
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        text.isEditable = false; text.isSelectable = true; text.isRichText = false
        text.font = .monospacedSystemFont(ofSize:13,weight:.regular)
        text.textContainerInset = NSSize(width:14,height:14); text.autoresizingMask = [.width]
        text.minSize = NSSize(width:0,height:0); text.maxSize = NSSize(width:CGFloat.greatestFiniteMagnitude,height:CGFloat.greatestFiniteMagnitude)
        text.isVerticallyResizable = true; text.isHorizontallyResizable = false
        text.textContainer?.widthTracksTextView = true; scroll.documentView = text
        restore.target = self; restore.action = #selector(restoreLast); restore.bezelStyle = .rounded
        let close = NSButton(title:"Close  ⎋",target:self,action:#selector(closeWindow)); close.bezelStyle = .rounded
        let actions = NSStackView(views:[restore,close]); actions.spacing = 12
        let stack = NSStackView(views:[scroll,actions]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false; window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:16),
            stack.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-16),
            stack.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:16),
            stack.bottomAnchor.constraint(equalTo:window.contentView!.bottomAnchor,constant:-16),
            scroll.widthAnchor.constraint(equalTo:stack.widthAnchor),scroll.heightAnchor.constraint(greaterThanOrEqualToConstant:260)])
        monitor = NSEvent.addLocalMonitorForEvents(matching:.keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated { guard let self,event.window === self.window,event.keyCode == 53 else { return false }; self.window.close(); return true }
            return handled ? nil : event
        }
    }
    func refresh() {
        func state(_ enabled: Bool) -> String { enabled ? "Native — enabled" : "Native — disabled" }
        let geometryRows = GeometryShortcut.all.map { "  \($0.label)  \($0.command.title)" }.joined(separator:"\n")
        let hammerspoon = NSRunningApplication.runningApplications(withBundleIdentifier:"org.hammerspoon.Hammerspoon").isEmpty ? "Hammerspoon — stopped" : "Hammerspoon — running"
        text.string = """
        WINDOW FACTORY KEYBOARD SHORTCUTS

        Hold Tab for Hyper: ⌃⌥⌘ (Control + Option + Command).
        Click the app window you want to control before using global keys.
        ⌘ means Command; ⇧ means Shift. This window opens with ⌘?.

        GEOMETRY  [\(state(geometry?.active == true))]
        \(geometryRows)

        DIRECTIONAL FOCUS  [\(state(focus?.active == true))]
          Hyper + H / J / K / L   Left / down / up / right
          Same display first; an aligned neighbour is required.

        STASH / RESTORE  [\(state(stash?.active == true))]
          Hyper + S   Stash the focused window / restore its saved frame
          Stashed windows in this app session: \(stash?.count ?? 0)
          Click Restore last stashed window below to recover one after
          focus has moved elsewhere. Restore stashed windows before quitting.

        WINDOW SWITCHING  [\(state(switcher?.active == true))]
          Hyper + W         Open / close the persistent window picker
          ↑ / ↓             Previous / next window in desktop groups
          ← / →             Previous / next desktop group
          Return / Enter    Select and close     Esc cancels
          Hyper + ⇧W        Open / step backward
          Windows on other Spaces are included; the selected Space is followed.

        ACCORDION  [\(state(accordion?.active == true))]
          Hyper + ⇧S        Fan the active app’s windows from the focused anchor
          Anchor stays unchanged; other windows match its size, offset 28 × 22.
          Current ordinary desktop/display only.

        REMAINING HAMMERSPOON CONTROLS  [\(hammerspoon)]
          Hyper + ← / →     Move window to adjacent Space and follow
          Hyper + R         Open native Window Factory
          Hyper + ⇧R        Open Hammerspoon layout fallback
          Control + ← / →   macOS: switch desktop without moving a window

        INSIDE THE LAYOUT LIBRARY
          ↑ / ↓         Select layout
          Return        Restore existing windows
          ⌘Return       Establish missing windows
          ⌘N            Capture layout
          ⌘F            Search
          ⌘I / ⇧⌘E      Import / export
          ⌘Delete       Delete selected layout (confirmation)
          Escape        Cancel or close
          ⌘,            Settings
          ⌘?            This shortcut reference
          ⌘W / ⌘Q       Close window / quit Window Factory

        Native groups can be enabled independently in Settings.
        The Hammerspoon fallback is selected through the managed loader;
        do not enable both owners for the same shortcut group.
        """
        restore.isEnabled = (stash?.count ?? 0)>0
    }
    func show() {
        refresh(); window.level = preferences.keepLibraryOnTop ? .floating : .normal
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    @objc func restoreLast() { stash?.restoreLast(); refresh() }
    @objc func closeWindow() { window.close() }
    func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
}
