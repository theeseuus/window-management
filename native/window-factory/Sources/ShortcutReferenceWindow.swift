import AppKit

@MainActor
final class ShortcutReferenceWindow: NSObject {
    let window: NSWindow
    private let preferences: FactoryPreferences
    private let text = NSTextView()
    private let restore = NSButton(title:"Restore last stashed window",target:nil,action:nil)
    weak var launcher: LauncherControls?
    weak var spaceIndicator: SpaceIndicator?
    weak var spaceMove: DirectSpaceMoveControls?
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
        let states: [ShortcutGroup:Bool] = [.geometry:geometry?.active == true,.focus:focus?.active == true,.stash:stash?.active == true,.switcher:switcher?.active == true,.accordion:accordion?.active == true,.spaces:spaceMove?.active == true,.library:launcher?.active == true]
        var sections = ["WINDOW FACTORY KEYBOARD SHORTCUTS"]
        for group in ShortcutGroup.allCases {
            let rows = ShortcutDefinition.all.filter{$0.group == group}.map { "\(preferences.shortcuts.chord($0).label)\t\($0.title)" }
            sections.append("\(group.title.uppercased())  [\(states[group] == true ? "On" : "Off")]\n"+rows.joined(separator:"\n"))
        }
        sections.append("Stashed windows in this app session: \(stash?.count ?? 0)")
        func section(_ title: String,_ rows: [(String,String)]) -> String {
            title+"\n"+rows.map{$0.0+"\t"+$0.1}.joined(separator:"\n")
        }
        sections.append(section("SWITCHER NAVIGATION",[("↑ / ↓","Previous / next window"),("← / →","Previous / next desktop"),("Return / Enter","Select window"),("Escape","Close")]))
        sections.append(section("LAYOUT LIBRARY",[("↑ / ↓","Select layout"),("Return","Restore"),("⌘ Return","Establish"),("⌘ N","Capture"),("⌘ F","Search"),("⌘ I / ⇧⌘ E","Import / export"),("⌘ Delete","Delete layout"),("Escape","Cancel or close"),("⌘ ,","Settings"),("⌘ ?","Keyboard Shortcuts"),("⌘ W / ⌘ Q","Close / quit")]))
        sections.append(section("HAMMERSPOON FALLBACK",[("⌃⌥⇧⌘ R","Open fallback library"),("⌃ ← / ⌃ →","Switch desktop (macOS)")]))
        text.string = sections.joined(separator:"\n\n")
        let body = NSMutableAttributedString(string:text.string,attributes:[.font:NSFont.monospacedSystemFont(ofSize:13,weight:.regular),.foregroundColor:NSColor.labelColor])
        let columns = NSMutableParagraphStyle()
        columns.tabStops = [NSTextTab(textAlignment:.left,location:190)]
        columns.defaultTabInterval = 190; columns.headIndent = 190
        (body.string as NSString).enumerateSubstrings(in:NSRange(location:0,length:body.length),options:.byParagraphs) { line,range,_,_ in
            if line?.contains("\t") == true { body.addAttribute(.paragraphStyle,value:columns,range:range) }
        }
        text.textStorage?.setAttributedString(body)
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
