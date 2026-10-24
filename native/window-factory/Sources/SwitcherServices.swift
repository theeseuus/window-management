import AppKit

@MainActor
struct SwitcherDesktop {
    let display: UInt32, space: UInt64
    init(_ screen: NSScreen) throws {
        display = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        var sid: UInt64 = 0, kind: Int32 = -1
        guard WFContext(display,&sid,&kind) else { throw FactoryError("Desktop membership unavailable.") }
        space = sid
    }
    func check() throws {
        try Task.checkCancellation(); var sid: UInt64 = 0,kind: Int32 = -1
        guard WFContext(display,&sid,&kind),sid == space else { throw FactoryError("Desktop changed; switcher cancelled.") }
    }
}
@MainActor
struct SwitcherOrigin {
    let pid: pid_t
    let windowID: UInt32?
    let desktops: [SwitcherDesktop]
    func check() throws {
        for desktop in desktops { try desktop.check() }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { throw FactoryError("Focus changed; switcher cancelled.") }
        if let windowID {
            let root = AXUIElementCreateApplication(pid); AXUIElementSetMessagingTimeout(root,0.1)
            guard let focused = axElement(attribute(root,kAXFocusedWindowAttribute)),WFWindowID(focused) == windowID else { throw FactoryError("Focused window changed; switcher cancelled.") }
        }
    }
}
@MainActor
struct SwitcherWindowRecord {
    let window: LiveWindow
    let space: UInt64, display: UInt32
    let title: String
    let icon: NSImage?
    func check() throws {
        try Task.checkCancellation(); let w = window
        guard WFWindowID(w.element) == w.id,NSRunningApplication(processIdentifier:w.pid)?.bundleIdentifier == w.bundleID,
              NSRunningApplication(processIdentifier:w.pid)?.isHidden == false,
              WFWindowSpaces(w.id)?.map(\.uint64Value) == [space],[0,4].contains(WFSpaceKind(space)),
              attribute(w.element,kAXSubroleAttribute) as? String == kAXStandardWindowSubrole,
              (attribute(w.element,kAXMinimizedAttribute) as? Bool) != true else { throw FactoryError("Selected window is closed or no longer eligible; switch cancelled.") }
    }
}
@MainActor
final class SwitcherServices {
    func allowed(_ bundle: String) -> Bool {
        bundle != Bundle.main.bundleIdentifier && bundle != "org.hammerspoon.Hammerspoon"
        && !bundle.lowercased().contains("1password") && !bundle.lowercased().contains("onepassword")
        && bundle != "com.apple.Passwords" && bundle != "com.apple.keychainaccess"
    }
    func origin() throws -> SwitcherOrigin {
        guard AXIsProcessTrusted(),let app = NSWorkspace.shared.frontmostApplication,
              let bundle = app.bundleIdentifier,!bundle.lowercased().contains("1password"),!bundle.lowercased().contains("onepassword"),
              bundle != "com.apple.Passwords",bundle != "com.apple.keychainaccess" else { throw FactoryError("Focus a regular application first.") }
        let root = AXUIElementCreateApplication(app.processIdentifier); AXUIElementSetMessagingTimeout(root,0.1)
        let focused = axElement(attribute(root,kAXFocusedWindowAttribute))
        let id = focused.map{WFWindowID($0)}.flatMap{$0 == 0 ? nil : $0}
        return SwitcherOrigin(pid:app.processIdentifier,windowID:id,desktops:try NSScreen.screens.map{try SwitcherDesktop($0)})
    }
    func collect(_ origin: SwitcherOrigin) async throws -> [SwitcherWindowRecord] {
        try origin.check()
        let infos = CGWindowListCopyWindowInfo(.optionAll,kCGNullWindowID) as? [[String:Any]] ?? []
        let regular = infos.filter{($0[kCGWindowLayer as String] as? Int) == 0}
        let order = regular.compactMap{($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value}
        let pids = regular.compactMap{($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value}
            + NSWorkspace.shared.runningApplications.filter{$0.activationPolicy == .regular}.map(\.processIdentifier)
        var visited = Set<pid_t>(),result: [SwitcherWindowRecord] = []
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        for pid in pids where visited.insert(pid).inserted {
            try origin.check(); await Task.yield()
            guard let app = NSRunningApplication(processIdentifier:pid),let bundle = app.bundleIdentifier,allowed(bundle),
                  app.activationPolicy == .regular,!app.isHidden else { continue }
            let root = AXUIElementCreateApplication(pid); AXUIElementSetMessagingTimeout(root,0.1)
            for element in children(root,kAXWindowsAttribute) {
                let id = WFWindowID(element)
                guard id != 0,attribute(element,kAXSubroleAttribute) as? String == kAXStandardWindowSubrole,
                      (attribute(element,kAXMinimizedAttribute) as? Bool) != true,
                      let spaces = WFWindowSpaces(id),spaces.count == 1,[0,4].contains(WFSpaceKind(spaces[0].uint64Value)) else { continue }
                var rect = CGRect.zero
                guard WFReadFrame(element,&rect),rect.width>0,rect.height>0 else { continue }
                let frame = Frame(x:rect.minX,y:rect.minY,w:rect.width,h:rect.height)
                let screens = NSScreen.screens.sorted { a,b in
                    func area(_ s: NSScreen) -> Double {
                        let f = s.frame,i = rect.intersection(CGRect(x:f.minX,y:top-f.maxY,width:f.width,height:f.height))
                        return i.isNull ? 0 : i.width*i.height
                    }
                    return area(a)>area(b)
                }
                guard let screen = screens.first else { continue }
                let f = screen.frame
                guard frame.isVisible(in:Frame(x:f.minX,y:top-f.maxY,w:f.width,h:f.height)) else { continue }
                let display = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
                let window = LiveWindow(id:id,pid:pid,bundleID:bundle,appName:app.localizedName ?? bundle,element:element,frame:frame)
                let record = SwitcherWindowRecord(window:window,space:spaces[0].uint64Value,display:display,
                    title:attribute(element,kAXTitleAttribute) as? String ?? "",icon:app.icon)
                if (try? record.check()) != nil { result.append(record) }
            }
        }
        try origin.check()
        result.sort{(order.firstIndex(of:$0.window.id) ?? Int.max)<(order.firstIndex(of:$1.window.id) ?? Int.max)}
        return result
    }
    func activate(_ target: SwitcherWindowRecord,from origin: SwitcherOrigin) async throws {
        try origin.check(); try target.check()
        var main: Int32 = 0, raised: Int32 = 0
        let status = WFRequestWindowFocus(target.window.element,target.window.pid,&main,&raised)
        // Space changes here are intentional native activation, never movement.
        for _ in 0..<40 {
            try await Task.sleep(for:.milliseconds(30)); try target.check()
            let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
            guard front == origin.pid || front == target.window.pid else { throw FactoryError("User focus changed; switch verification stopped.") }
            let root = AXUIElementCreateApplication(target.window.pid); AXUIElementSetMessagingTimeout(root,0.1)
            var sid: UInt64 = 0,kind: Int32 = -1
            if front == target.window.pid,let focused = axElement(attribute(root,kAXFocusedWindowAttribute)),
               WFWindowID(focused) == target.window.id,WFContext(target.display,&sid,&kind),sid == target.space { return }
        }
        throw FactoryError("Switch not confirmed for \(target.window.appName) (main \(main), raise \(raised), activation \(status)).")
    }
}
