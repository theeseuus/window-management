import AppKit

@MainActor
private final class SwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
@MainActor
final class WindowSwitcherPanel: NSObject {
    private let panel: NSPanel
    private let preview = NSImageView()
    private let title = NSTextField(wrappingLabelWithString:"")
    private let scroll = NSScrollView()
    private var rows: [NSButton] = []
    var choose: ((Int) -> Void)?
    override init() {
        panel = SwitcherPanel(contentRect:NSRect(x:0,y:0,width:780,height:570),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        super.init()
        panel.level = .floating; panel.hidesOnDeactivate = false; panel.isOpaque = false
        panel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.97)
        panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary,.transient,.ignoresCycle]
        let content = NSView(frame:NSRect(x:0,y:0,width:780,height:570)); content.wantsLayer = true
        content.layer?.cornerRadius = 14; content.layer?.masksToBounds = true
        preview.frame = NSRect(x:20,y:350,width:320,height:190); preview.imageScaling = .scaleProportionallyUpOrDown
        title.frame = NSRect(x:362,y:350,width:390,height:190); title.font = .systemFont(ofSize:17,weight:.medium)
        scroll.frame = NSRect(x:20,y:58,width:740,height:276); scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        let hint = NSTextField(labelWithString:"Hold Tab · W next · Shift+W back · release Tab to switch · Esc cancels")
        hint.font = .systemFont(ofSize:12); hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x:20,y:20,width:740,height:22)
        for view in [preview,title,scroll,hint] { content.addSubview(view) }
        panel.contentView = content
    }
    func loading() {
        title.stringValue = "Collecting windows…"; preview.image = nil; rows = []; scroll.documentView = NSView()
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let f = screen.visibleFrame; panel.setFrameOrigin(NSPoint(x:f.midX-390,y:f.midY-285))
        }
        panel.orderFrontRegardless()
    }
    func render(_ records: [SwitcherWindowRecord],selected: Int,origin: SwitcherOrigin) {
        guard records.indices.contains(selected) else { return }
        let height = CGFloat(records.count*48)
        let document = NSView(frame:NSRect(x:0,y:0,width:720,height:height)); rows = []
        for (i,record) in records.enumerated() {
            let current = origin.desktops.contains{$0.display == record.display && $0.space == record.space}
            let text = record.title.replacingOccurrences(of:"\n",with:" ")
            let button = NSButton(title:"  \(record.window.appName) — \(text.isEmpty ? "Untitled window" : text)  [\(current ? "This Space" : "Other Space")]",target:self,action:#selector(clickRow(_:)))
            button.tag = i; button.isBordered = false; button.alignment = .left; button.font = .systemFont(ofSize:13)
            button.image = record.icon; button.imagePosition = .imageLeft; button.imageScaling = .scaleProportionallyDown
            button.frame = NSRect(x:4,y:height-CGFloat((i+1)*48)+2,width:710,height:44)
            button.wantsLayer = true; button.layer?.cornerRadius = 7
            button.layer?.backgroundColor = (i == selected ? NSColor.controlAccentColor.withAlphaComponent(0.35) : .clear).cgColor
            document.addSubview(button); rows.append(button)
        }
        scroll.documentView = document
        if rows.indices.contains(selected) { document.scrollToVisible(rows[selected].frame) }
        let record = records[selected]
        title.stringValue = "\(record.window.appName)\n\n\(record.title.isEmpty ? "Untitled window" : record.title)\n\n\(selected+1) of \(records.count)"
        preview.image = record.icon
    }
    func showPreview(_ image: NSImage) { preview.image = image }
    @objc private func clickRow(_ sender: NSButton) { choose?(sender.tag) }
    func hide() { panel.orderOut(nil); rows = []; scroll.documentView = NSView(); preview.image = nil }
}
