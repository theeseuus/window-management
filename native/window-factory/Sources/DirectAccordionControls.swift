import AppKit

@MainActor
final class DirectAccordionControls {
    private let preferences: FactoryPreferences
    private let hud = GeometryHUD()
    private var task: Task<Void,Never>?
    var active = false
    var lastResult = "Native accordion is disabled."
    var workspaceBusy: () -> Bool = { false }
    var changed: (() -> Void)?
    init(preferences: FactoryPreferences) { self.preferences = preferences }
    func enable() throws {
        guard AXIsProcessTrusted() else { throw FactoryError("Accessibility access is required for accordion.") }
        let status = WFRegisterAccordionHotKey({ _,context in
            MainActor.assumeIsolated { Unmanaged<DirectAccordionControls>.fromOpaque(context).takeUnretainedValue().run() }
        },Unmanaged.passUnretained(self).toOpaque())
        guard status == 0 else { active = false; lastResult = "Accordion registration failed (status \(status)); other groups are unchanged."; changed?(); throw FactoryError(lastResult) }
        active = true; preferences.accordionEnabled = true
        lastResult = "Native accordion enabled: Tab + Shift + S."; changed?()
    }
    func disable() {
        WFUnregisterAccordionHotKey(); task?.cancel(); active = false; preferences.accordionEnabled = false
        lastResult = "Accordion shortcut released; the Hammerspoon fallback can be enabled."; changed?()
    }
    func restorePreference() {
        if preferences.accordionEnabled { do { try enable() } catch { preferences.accordionEnabled = false; lastResult = error.localizedDescription; changed?() } }
    }
    private func read(_ element: AXUIElement) throws -> Frame {
        var rect = CGRect.zero
        guard WFReadFrame(element,&rect),rect.width>0,rect.height>0 else { throw FactoryError("Window frame unavailable.") }
        return Frame(x:rect.minX,y:rect.minY,w:rect.width,h:rect.height)
    }
    private func snapshot() throws -> (LiveWindow,Context,[LiveWindow]) {
        guard AXIsProcessTrusted(),let app = NSWorkspace.shared.frontmostApplication,let bundle = app.bundleIdentifier,
              app.activationPolicy == .regular,!app.isHidden,bundle != Bundle.main.bundleIdentifier,bundle != "org.hammerspoon.Hammerspoon",
              !bundle.lowercased().contains("1password"),!bundle.lowercased().contains("onepassword"),
              bundle != "com.apple.Passwords",bundle != "com.apple.keychainaccess" else { throw FactoryError("Focus a regular application window first.") }
        let root = AXUIElementCreateApplication(app.processIdentifier); AXUIElementSetMessagingTimeout(root,0.15)
        guard let focused = axElement(attribute(root,kAXFocusedWindowAttribute)),attribute(focused,kAXSubroleAttribute) as? String == kAXStandardWindowSubrole else { throw FactoryError("No focused standard window.") }
        let frame = try read(focused),id = WFWindowID(focused)
        guard id != 0 else { throw FactoryError("Window identity unavailable.") }
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        let rect = CGRect(x:frame.x,y:frame.y,width:frame.w,height:frame.h)
        let display = NSScreen.screens.max { a,b in
            func area(_ s: NSScreen) -> Double {
                let f = s.frame,i = rect.intersection(CGRect(x:f.minX,y:top-f.maxY,width:f.width,height:f.height))
                return i.isNull ? 0 : i.width*i.height
            }
            return area(a)<area(b)
        }
        guard let display else { throw FactoryError("Display unavailable.") }
        let context = try Context(screen:display)
        func window(_ element: AXUIElement,_ frame: Frame) -> LiveWindow {
            LiveWindow(id:WFWindowID(element),pid:app.processIdentifier,bundleID:bundle,appName:app.localizedName ?? bundle,element:element,frame:frame)
        }
        let anchor = window(focused,frame); try anchor.eligible(in:context)
        var seen = Set<UInt32>(),others: [LiveWindow] = []
        for element in children(root,kAXWindowsAttribute) {
            let candidateID = WFWindowID(element)
            guard candidateID != 0,candidateID != id,seen.insert(candidateID).inserted,
                  attribute(element,kAXSubroleAttribute) as? String == kAXStandardWindowSubrole,
                  let frame = try? read(element),frame.isVisible(in:context.frame) else { continue }
            let candidate = window(element,frame)
            guard (try? candidate.eligible(in:context)) != nil else { continue }
            others.append(candidate)
        }
        return (anchor,context,others)
    }
    private func check(_ anchor: LiveWindow,_ context: Context) throws {
        try Task.checkCancellation(); try anchor.eligible(in:context)
        guard !workspaceBusy(),NSWorkspace.shared.frontmostApplication?.processIdentifier == anchor.pid else { throw FactoryError("Focus or workspace operation changed; accordion stopped.") }
        let root = AXUIElementCreateApplication(anchor.pid); AXUIElementSetMessagingTimeout(root,0.1)
        guard let focused = axElement(attribute(root,kAXFocusedWindowAttribute)),WFWindowID(focused) == anchor.id,
              try read(anchor.element).matches(anchor.frame) else { throw FactoryError("Anchor changed; accordion stopped.") }
    }
    func run() {
        guard active,task == nil,!workspaceBusy() else { return }
        do {
            let (anchor,context,others) = try snapshot()
            task = Task { @MainActor [weak self] in
                guard let self else { return }
                defer { task = nil; changed?() }
                do {
                    let plan = AccordionGeometry.plan(anchor:AccordionRecord(id:anchor.id,frame:anchor.frame),others:others.map{AccordionRecord(id:$0.id,frame:$0.frame)},screen:context.frame)
                    for destination in plan {
                        try check(anchor,context)
                        guard let target = others.first(where:{$0.id == destination.id}) else { continue }
                        try target.eligible(in:context)
                        let f = destination.frame
                        guard WFApplyDirectFrame(target.element,CGRect(x:f.x,y:f.y,width:f.w,height:f.h)) == .success else { throw FactoryError("Application rejected accordion placement; some windows may already be placed.") }
                    }
                    // Submit the whole fan first; do not delay each window behind
                    // the previous window's animation or move the anchor to focus it.
                    if !plan.isEmpty { try await Task.sleep(for:.milliseconds(400)) }
                    try check(anchor,context)
                    var placed = 0
                    for destination in plan {
                        guard let target = others.first(where:{$0.id == destination.id}) else { continue }
                        try target.eligible(in:context)
                        if try read(target.element).matches(destination.frame) { placed += 1 }
                    }
                    guard placed == plan.count else { throw FactoryError("Accordion placed \(placed) of \(plan.count) other windows; the app constrained the remaining frames.") }
                    lastResult = "Accordion: \(plan.count+1) windows; anchor unchanged."; hud.show("ACC \(plan.count+1)",on:context.screen)
                } catch is CancellationError { lastResult = "Accordion cancelled." }
                catch { lastResult = error.localizedDescription; hud.show(lastResult) }
            }
        } catch { lastResult = error.localizedDescription; hud.show(lastResult); changed?() }
    }
    func stop() { WFUnregisterAccordionHotKey(); task?.cancel(); active = false; hud.stop() }
}
