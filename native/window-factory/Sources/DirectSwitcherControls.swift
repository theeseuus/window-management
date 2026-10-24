import AppKit
@preconcurrency import ScreenCaptureKit

@MainActor
final class DirectSwitcherControls {
    private let preferences: FactoryPreferences
    private let services = SwitcherServices()
    private let panel = WindowSwitcherPanel()
    private let hud = GeometryHUD()
    private var recency = WindowRecency()
    private var sessionTask: Task<Void,Never>?, activationTask: Task<Void,Never>?, previewTask: Task<Void,Never>?
    private var activationObserver: NSObjectProtocol?
    private var generation = 0
    private var origin: SwitcherOrigin?
    private var records: [SwitcherWindowRecord] = []
    private var selection: SwitcherSelection?
    private var pending: [Int] = []
    var active = false
    var lastResult = "Native window switching is disabled."
    var workspaceBusy: () -> Bool = { false }
    var changed: (() -> Void)?
    init(preferences: FactoryPreferences) {
        self.preferences = preferences
        panel.choose = { [weak self] index in self?.commit(index:index) }
    }
    func enable() throws {
        guard AXIsProcessTrusted() else { throw FactoryError("Accessibility access is required for window switching.") }
        var failed: UInt32 = 0
        let status = WFRegisterSwitcherHotKeys({ index,context in
            MainActor.assumeIsolated {
                let owner = Unmanaged<DirectSwitcherControls>.fromOpaque(context).takeUnretainedValue()
                if index == 2 { owner.cancel() } else { owner.cycle(index == 0 ? 1 : -1) }
            }
        },Unmanaged.passUnretained(self).toOpaque(),&failed)
        guard status == 0 else { active = false; lastResult = "Switcher registration failed at W/Shift+W index \(failed) (status \(status)); other groups are unchanged."; changed?(); throw FactoryError(lastResult) }
        active = true; preferences.switcherEnabled = true
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didActivateApplicationNotification,object:nil,queue:.main) { [weak self] _ in
            MainActor.assumeIsolated { self?.noteForeground() }
        }
        noteForeground(); lastResult = "Native window switching enabled: Tab + W / Tab + Shift + W."; changed?()
    }
    func disable() {
        cancel(); activationTask?.cancel(); WFUnregisterSwitcherHotKeys(); active = false; preferences.switcherEnabled = false
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver); self.activationObserver = nil }
        lastResult = "Switcher shortcuts released; the Hammerspoon switcher fallback can be enabled."; changed?()
    }
    func restorePreference() {
        if preferences.switcherEnabled { do { try enable() } catch { preferences.switcherEnabled = false; lastResult = error.localizedDescription; changed?() } }
    }
    private func noteForeground() {
        guard let app = NSWorkspace.shared.frontmostApplication,let bundle = app.bundleIdentifier,services.allowed(bundle) else { return }
        let root = AXUIElementCreateApplication(app.processIdentifier); AXUIElementSetMessagingTimeout(root,0.1)
        if let window = axElement(attribute(root,kAXFocusedWindowAttribute)) { recency.note(WFWindowID(window)) }
    }
    func cycle(_ direction: Int) {
        guard active,!workspaceBusy(),activationTask == nil else { return }
        if origin != nil {
            if selection == nil { pending.append(direction) }
            else { selection?.advance(direction); render() }
            return
        }
        do {
            let start = try services.origin(); origin = start
            if let id = start.windowID { recency.note(id) }
            pending = [direction]; generation += 1; let current = generation
            let escapeStatus = WFSetSwitcherEscape(true)
            guard escapeStatus == 0 else { throw FactoryError("Switcher Escape could not register (status \(escapeStatus)); selection cancelled.") }
            panel.loading()
            sessionTask = Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let candidates = try await services.collect(start)
                    try Task.checkCancellation(); try start.check()
                    let ordered = recency.ordered(candidates.map{$0.window.id},current:start.windowID)
                    records = ordered.compactMap { id in candidates.first{$0.window.id == id} }
                    guard !records.isEmpty else { throw FactoryError("No eligible windows to switch to.") }
                    let moves = pending; pending = []
                    selection = SwitcherSelection(ids:ordered,current:start.windowID,direction:moves.first ?? direction)
                    for move in moves.dropFirst() { selection?.advance(move) }
                    render()
                    while current == generation {
                        try Task.checkCancellation(); try start.check()
                        guard !workspaceBusy() else { throw FactoryError("Workspace operation started; switcher cancelled.") }
                        let held = NSEvent.modifierFlags.intersection([.command,.option,.control,.shift,.function])
                        if held.isEmpty { commit(); return }
                        try await Task.sleep(for:.milliseconds(20))
                    }
                } catch is CancellationError { }
                catch { if current == generation { cancel(); lastResult = error.localizedDescription; hud.show(lastResult); changed?() } }
            }
        } catch { cancel(); lastResult = error.localizedDescription; hud.show(lastResult); changed?() }
    }
    private func render() {
        previewTask?.cancel()
        guard let origin,let selection,records.indices.contains(selection.index) else { return }
        panel.render(records,selected:selection.index,origin:origin)
        let target = records[selection.index]
        let id = target.window.id, current = generation
        // This preflight does not request access. Icons are the permission-free fallback.
        guard CGPreflightScreenCaptureAccess() else { return }
        previewTask = Task { @MainActor [weak self] in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(true,onScreenWindowsOnly:false)
                try target.check()
                guard let window = content.windows.first(where:{$0.windowID == id && $0.owningApplication?.processID == target.window.pid}) else { return }
                let filter = SCContentFilter(desktopIndependentWindow:window)
                let configuration = SCStreamConfiguration(); configuration.width = 480
                configuration.height = max(1,Int(480*window.frame.height/max(1,window.frame.width)))
                let image = try await SCScreenshotManager.captureImage(contentFilter:filter,configuration:configuration)
                try Task.checkCancellation()
                guard let self,generation == current,self.selection?.selected == id else { return }
                panel.showPreview(NSImage(cgImage:image,size:NSSize(width:image.width,height:image.height)))
            } catch { /* Keep the app icon if previews are unavailable. */ }
        }
    }
    func cancel() {
        generation += 1; sessionTask?.cancel(); sessionTask = nil; previewTask?.cancel(); previewTask = nil
        panel.hide(); _ = WFSetSwitcherEscape(false); origin = nil; records = []; selection = nil; pending = []
    }
    private func commit(index: Int? = nil) {
        guard let start = origin,let chosen = index ?? selection?.index,records.indices.contains(chosen),!workspaceBusy() else { cancel(); return }
        let target = records[chosen]
        cancel()
        activationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { activationTask = nil; changed?() }
            do {
                try await services.activate(target,from:start)
                recency.note(target.window.id); lastResult = "Switched to \(target.window.appName): exact focus verified."
            } catch is CancellationError { }
            catch { lastResult = error.localizedDescription; hud.show(lastResult) }
        }
    }
    func stop() {
        cancel(); activationTask?.cancel(); WFUnregisterSwitcherHotKeys(); active = false; hud.stop()
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver); self.activationObserver = nil }
    }
}
