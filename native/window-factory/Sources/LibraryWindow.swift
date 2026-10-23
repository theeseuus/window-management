import AppKit
import UniformTypeIdentifiers

@MainActor
final class PreviewView: NSView {
    var recipe: Recipe? { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill(); bounds.fill()
        let canvas = bounds.insetBy(dx:12,dy:12)
        NSColor.separatorColor.setStroke(); NSBezierPath(rect:canvas).stroke()
        guard let recipe else { return }
        for (index,slot) in recipe.windows.enumerated() {
            let f = slot.frame
            let rect = NSRect(x:canvas.minX+f.x*canvas.width,y:canvas.minY+f.y*canvas.height,
                              width:f.w*canvas.width,height:f.h*canvas.height).intersection(canvas)
            guard !rect.isEmpty else { continue }
            NSColor.controlAccentColor.withAlphaComponent(0.12+Double(index%3)*0.06).setFill()
            let path = NSBezierPath(roundedRect:rect.insetBy(dx:1,dy:1),xRadius:3,yRadius:3)
            path.fill(); NSColor.controlAccentColor.setStroke(); path.stroke()
            (slot.appName as NSString).draw(in:rect.insetBy(dx:5,dy:5),withAttributes:[
                .font:NSFont.systemFont(ofSize:10),.foregroundColor:NSColor.labelColor])
        }
    }
}

@MainActor
final class LibraryWindow: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    let window: NSWindow
    let store: LayoutStore
    let coordinator: Coordinator
    let preview: Bool
    let search = NSSearchField(), table = NSTableView(), drawing = PreviewView()
    let status = NSTextField(wrappingLabelWithString:"")
    let name = NSTextField(), nameLabel = NSTextField(labelWithString:"Layout name")
    let save = NSButton(title:"Save",target:nil,action:nil)
    let capture = NSButton(title:"Capture…",target:nil,action:nil)
    let restore = NSButton(title:"Restore",target:nil,action:nil)
    let establish = NSButton(title:"Establish here",target:nil,action:nil)
    let cancel = NSButton(title:"Cancel",target:nil,action:nil)
    var filtered: [Recipe] = [], frozen: Recipe?, task: Task<Void,Never>?, monitor: Any?
    var lastReceipt: Receipt?
    init(store: LayoutStore,registry: AdapterRegistry,preview: Bool) {
        self.store = store; self.coordinator = Coordinator(registry:registry); self.preview = preview
        window = NSWindow(contentRect:NSRect(x:0,y:0,width:760,height:550),
            styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        super.init()
        window.title = preview ? "Window Factory Native — Preview" : "Window Factory Native"
        window.minSize = NSSize(width:660,height:480); window.delegate = self
        window.isReleasedWhenClosed = false
        search.placeholderString = "Search layouts or applications"; search.delegate = self
        let column = NSTableColumn(identifier:NSUserInterfaceItemIdentifier("layout"))
        column.title = "Layouts"; table.addTableColumn(column); table.headerView = nil
        table.rowHeight = 48; table.dataSource = self; table.delegate = self
        table.target = self; table.doubleAction = #selector(restoreLayout)
        let scroll = NSScrollView(); scroll.documentView = table; scroll.hasVerticalScroller = true
        drawing.wantsLayer = true; drawing.layer?.cornerRadius = 8
        let split = NSStackView(views:[scroll,drawing]); split.orientation = .horizontal; split.spacing = 12
        scroll.widthAnchor.constraint(equalTo:split.widthAnchor,multiplier:0.53).isActive = true
        drawing.widthAnchor.constraint(equalTo:split.widthAnchor,multiplier:0.45).isActive = true
        split.heightAnchor.constraint(greaterThanOrEqualToConstant:240).isActive = true
        for (button,action) in [(capture,#selector(startCapture)),(restore,#selector(restoreLayout)),
                                (establish,#selector(establishLayout)),(save,#selector(saveCapture)),(cancel,#selector(cancelAction))] {
            button.target = self; button.action = action; button.bezelStyle = .rounded
        }
        let importButton = NSButton(title:"Import…",target:self,action:#selector(importLayouts))
        let exportButton = NSButton(title:"Export…",target:self,action:#selector(exportLayouts))
        let deleteButton = NSButton(title:"Delete…",target:self,action:#selector(deleteLayout))
        let reportButton = NSButton(title:"Last report",target:self,action:#selector(showReport))
        for button in [importButton,exportButton,deleteButton] { button.isEnabled = !preview }
        let permission = NSButton(title:"Accessibility Settings…",target:self,action:#selector(openAccessSettings))
        permission.bezelStyle = .rounded
        name.placeholderString = "Name the captured layout"; name.target = self; name.action = #selector(saveCapture)
        let naming = NSStackView(views:[nameLabel,name,save,cancel]); naming.orientation = .horizontal
        name.widthAnchor.constraint(greaterThanOrEqualToConstant:240).isActive = true
        let buttons = NSStackView(views:[capture,restore,establish]); buttons.spacing = 8
        let tools = NSStackView(views:[importButton,exportButton,deleteButton,reportButton,permission]); tools.spacing = 8
        let stack = NSStackView(views:[search,split,naming,buttons,status,tools])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top:18,left:18,bottom:18,right:18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = window.contentView!; content.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo:content.trailingAnchor),stack.topAnchor.constraint(equalTo:content.topAnchor),
            stack.bottomAnchor.constraint(equalTo:content.bottomAnchor),
            search.widthAnchor.constraint(equalTo:stack.widthAnchor,constant:-36),
            split.widthAnchor.constraint(equalTo:stack.widthAnchor,constant:-36),
            status.widthAnchor.constraint(equalTo:stack.widthAnchor,constant:-36)])
        status.font = .systemFont(ofSize:12); status.textColor = .secondaryLabelColor
        monitor = NSEvent.addLocalMonitorForEvents(matching:.keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated {
                guard let self, event.window === self.window else { return false }
                return self.handle(event)
            }
            return handled ? nil : event
        }
        reload()
        status.stringValue = preview ? "Preview only. Window operations and catalog changes are disabled."
            : "Global shortcuts remain with Hammerspoon. " + (AXIsProcessTrusted() ? "Ready." : "Accessibility access is needed for capture and placement.")
    }
    var selected: Recipe? { filtered.indices.contains(table.selectedRow) ? filtered[table.selectedRow] : nil }
    func show() { window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true); window.makeFirstResponder(search) }
    func updateButtons() {
        let access = !preview && AXIsProcessTrusted(), idle = task == nil && frozen == nil
        capture.isEnabled = access && idle; restore.isEnabled = access && idle && selected != nil
        establish.isEnabled = access && idle && selected != nil
        name.isHidden = frozen == nil; nameLabel.isHidden = frozen == nil; save.isHidden = frozen == nil
        save.isEnabled = !preview && frozen != nil && task == nil
        cancel.isHidden = task == nil && frozen == nil
        search.isEnabled = task == nil && frozen == nil
    }
    func reload(select wanted: String? = nil) {
        let query = search.stringValue.trimmingCharacters(in:.whitespacesAndNewlines)
        filtered = store.catalog.recipes.values.filter { query.isEmpty || ($0.name+" "+$0.summary).localizedCaseInsensitiveContains(query) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        table.reloadData()
        if !filtered.isEmpty { table.selectRowIndexes(IndexSet(integer:filtered.firstIndex(where:{ $0.name == wanted }) ?? 0),byExtendingSelection:false) }
        drawing.recipe = selected; updateButtons()
    }
    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }
    func tableView(_ tableView: NSTableView,viewFor tableColumn: NSTableColumn?,row: Int) -> NSView? {
        let recipe = filtered[row]
        let title = NSTextField(labelWithString:recipe.name); title.font = .systemFont(ofSize:13,weight:.semibold)
        let subtitle = NSTextField(labelWithString:recipe.summary); subtitle.font = .systemFont(ofSize:11)
        subtitle.textColor = .secondaryLabelColor; subtitle.lineBreakMode = .byTruncatingTail
        let view = NSStackView(views:[title,subtitle]); view.orientation = .vertical; view.alignment = .leading; view.spacing = 3
        return view
    }
    func tableViewSelectionDidChange(_ notification: Notification) { drawing.recipe = selected; updateButtons() }
    func controlTextDidChange(_ obj: Notification) { if obj.object as? NSSearchField === search { reload() } }
    func handle(_ event: NSEvent) -> Bool {
        if event.keyCode == 53 { cancelAction(); return true }
        if frozen != nil || task != nil { return false }
        if event.keyCode == 125 || event.keyCode == 126 {
            if !filtered.isEmpty {
                let next = max(0,min(filtered.count-1,table.selectedRow+(event.keyCode == 125 ? 1 : -1)))
                table.selectRowIndexes(IndexSet(integer:next),byExtendingSelection:false); table.scrollRowToVisible(next)
            }
            return true
        }
        if event.keyCode == 36 { event.modifierFlags.contains(.command) ? establishLayout() : restoreLayout(); return true }
        if event.keyCode == 51 && event.modifierFlags.contains(.command) { deleteLayout(); return true }
        return false
    }
    func context() throws -> Context {
        guard let screen = window.screen ?? NSScreen.main else { throw FactoryError("No screen available.") }
        return try Context(screen:screen)
    }
    func run(_ status: String,operation: @escaping @MainActor () async throws -> Void) {
        guard task == nil else { return }
        self.status.stringValue = status
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { task = nil; updateButtons() }
            do { try await Task.sleep(for:.milliseconds(40)); try await operation() }
            catch is CancellationError { self.status.stringValue = "Cancelled. Completed changes are retained." }
            catch { self.status.stringValue = error.localizedDescription }
        }
        updateButtons()
    }
    @objc func startCapture() {
        guard !preview, task == nil, frozen == nil else { return }
        run("Capturing windows…") { [self] in
            let recipe = try await coordinator.services.capture(context())
            try Task.checkCancellation(); frozen = recipe; name.stringValue = ""
            status.stringValue = "Captured \(recipe.windows.count) windows. Name the frozen layout."
            updateButtons(); window.makeFirstResponder(name)
        }
    }
    @objc func saveCapture() {
        guard !preview, task == nil, var recipe = frozen else { return }
        do {
            recipe.name = try Recipe.normalizedName(name.stringValue)
            if store.catalog.recipes[recipe.name] != nil && !confirm("Replace “\(recipe.name)”?",detail:"The native copy of this layout will be replaced.") { return }
            try store.save(recipe,replace:true); frozen = nil; search.stringValue = ""; reload(select:recipe.name)
            status.stringValue = "Saved \(recipe.name)."; window.makeFirstResponder(search)
        } catch { status.stringValue = error.localizedDescription }
    }
    @objc func restoreLayout() { apply(establish:false) }
    @objc func establishLayout() { apply(establish:true) }
    func apply(establish: Bool) {
        guard !preview, task == nil, frozen == nil, let recipe = selected else { return }
        run(establish ? "ESTABLISHING…" : "RESTORING…") { [self] in
            let report = try await coordinator.apply(recipe,establish:establish,context:context()) { [weak self] in self?.status.stringValue = $0 }
            lastReceipt = report; status.stringValue = report.summary
        }
    }
    @objc func cancelAction() {
        if let task { task.cancel(); status.stringValue = "Cancelling…" }
        else if frozen != nil { frozen = nil; status.stringValue = "Capture cancelled."; updateButtons(); window.makeFirstResponder(search) }
        else { window.close() }
    }
    @objc func importLayouts() {
        guard !preview, task == nil, frozen == nil else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do { try store.importCatalog(url); reload(); status.stringValue = "Imported a validated copy; the source catalog is unchanged." }
            catch { status.stringValue = error.localizedDescription }
        }
    }
    @objc func exportLayouts() {
        guard !preview, task == nil else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "window-factory-layouts.json"
        if panel.runModal() == .OK, let url = panel.url {
            do { try store.catalog.encoded().write(to:url,options:.atomic); status.stringValue = "Catalog exported." }
            catch { status.stringValue = error.localizedDescription }
        }
    }
    @objc func deleteLayout() {
        guard !preview, task == nil, frozen == nil, let recipe = selected else { return }
        if confirm("Delete “\(recipe.name)”?",detail:"The previous native catalog copy is retained for recovery.") {
            do { try store.delete(recipe.name); reload(); status.stringValue = "Layout deleted." }
            catch { status.stringValue = error.localizedDescription }
        }
    }
    func confirm(_ message: String,detail: String) -> Bool {
        let alert = NSAlert(); alert.messageText = message; alert.informativeText = detail
        alert.addButton(withTitle:"Continue"); alert.addButton(withTitle:"Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
    @objc func showReport() {
        let alert = NSAlert(); alert.messageText = "Last operation"
        alert.informativeText = lastReceipt?.summary ?? "No operation has run."; alert.runModal()
    }
    @objc func openAccessSettings() {
        NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func windowWillClose(_ notification: Notification) { task?.cancel() }
    func stop() { task?.cancel(); if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
}
