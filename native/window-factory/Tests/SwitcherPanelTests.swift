import AppKit

@main enum SwitcherPanelTests {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let picker = WindowSwitcherPanel()
        let origin = SwitcherOrigin(pid:getpid(),windowID:nil,desktops:[])
        let records = (0..<18).map { i in
            let desktop = i/6+1
            return SwitcherWindowRecord(
                window:SwitcherWindowIdentity(id:UInt32(i+1),pid:getpid(),bundleID:"local.test",appName:"Test",element:nil,frame:Frame(x:0,y:0,w:100,h:100)),
                space:UInt64(desktop),display:1,title:"Window \(i+1)",icon:nil,
                location:SwitcherDesktopLocation(display:1,space:UInt64(desktop),displayNumber:1,desktopNumber:desktop,spaceOrder:desktop,isCurrent:desktop == 1,isFullscreen:false))
        }
        picker.render(records,selected:0,origin:origin)
        let panel = NSApplication.shared.windows.first{$0.title == "Window Factory Window Switcher"}!
        let scroll = panel.contentView!.subviews.compactMap{$0 as? NSScrollView}.first!
        let document = scroll.documentView!
        var assertions = 0
        func check(_ value: Bool,_ message: String) {
            assertions += 1
            guard value else { fatalError(message) }
        }
        func row(_ index: Int) -> NSButton { document.subviews.compactMap{$0 as? NSButton}.first{$0.tag == index}! }
        func select(_ index: Int) {
            picker.render(records,selected:index,origin:origin)
            check(scroll.documentView === document,"selection must retain the document")
            check(scroll.contentView.bounds.contains(row(index).frame),"selected row must be fully visible")
        }
        let top = scroll.contentView.bounds.origin
        select(1); select(2); select(3)
        check(scroll.contentView.bounds.origin == top,"visible rows must not move the viewport")
        for index in 4..<18 {
            let before = scroll.contentView.bounds
            let frame = row(index).frame
            select(index)
            let after = scroll.contentView.bounds
            let expected = frame.minY < before.minY ? frame.minY : before.minY
            check(abs(after.minY-expected)<0.01,"down navigation must scroll only to the row edge")
            check(abs(after.minY-before.minY)<=84,"one step must not sweep past multiple rows")
        }
        for index in stride(from:16,through:0,by:-1) {
            let before = scroll.contentView.bounds
            let frame = row(index).frame
            select(index)
            let expected = frame.maxY>before.maxY ? frame.maxY-before.height : before.minY
            check(abs(scroll.contentView.bounds.minY-expected)<0.01,"up navigation must scroll only to the row edge")
        }
        select(17); select(0); select(12); select(6)
        let still = scroll.contentView.bounds
        select(6)
        check(scroll.contentView.bounds == still,"repeated selection must not scroll")
        picker.hide()
        picker.render(Array(records.prefix(2)),selected:0,origin:origin)
        check(scroll.documentView !== document,"new session must rebuild its list")
        check(scroll.documentView!.bounds.height>=scroll.contentSize.height,"short lists must fill the viewport")
        picker.stop()
        for label in ["1","12","123","?","—"] {
            let image = SpaceIndicator.image(label)
            check(image.isTemplate,"indicator adapts to menu-bar appearance")
            check(image.size.height == 18 && image.size.width>=24,"compact outlined badge dimensions")
            let bitmap = NSBitmapImageRep(data:image.tiffRepresentation!)!
            check(bitmap.colorAt(x:0,y:0)!.alphaComponent == 0,"rounded badge corner stays transparent")
        }
        func event(_ id: AEEventID = AEEventID(kAEOpenApplication)) -> NSAppleEventDescriptor {
            NSAppleEventDescriptor(eventClass:AEEventClass(kCoreEventClass),eventID:id,targetDescriptor:nil,returnID:AEReturnID(kAutoGenerateReturnID),transactionID:AETransactionID(kAnyTransactionID))
        }
        check(!LauncherControls.isLoginLaunch(nil),"missing launch event is a normal launch")
        check(!LauncherControls.isLoginLaunch(event()),"ordinary open shows the library")
        let direct = event(); direct.setParam(NSAppleEventDescriptor(boolean:true),forKeyword:AEKeyword(keyAELaunchedAsLogInItem))
        check(LauncherControls.isLoginLaunch(direct),"login marker is recognized")
        let property = event(); property.setParam(NSAppleEventDescriptor(enumCode:OSType(keyAELaunchedAsLogInItem)),forKeyword:AEKeyword(keyAEPropData))
        check(LauncherControls.isLoginLaunch(property),"login property-data marker is recognized")
        let unrelated = event(AEEventID(kAEReopenApplication)); unrelated.setParam(NSAppleEventDescriptor(boolean:true),forKeyword:AEKeyword(keyAELaunchedAsLogInItem))
        check(!LauncherControls.isLoginLaunch(unrelated),"reopening the app is not a quiet login launch")
        check(!FactoryLaunchPolicy.showsLibrary(arguments:[],loginLaunch:LauncherControls.isLoginLaunch(property)),"login launches keep the library closed")
        let preferenceName = "WindowFactory.DockTest.\(UUID().uuidString)"
        let dockDefaults = UserDefaults(suiteName:preferenceName)!
        defer { dockDefaults.removePersistentDomain(forName:preferenceName) }
        let dockPreferences = FactoryPreferences(defaults:dockDefaults)
        check(dockPreferences.showDockIcon,"Dock icon starts visible")
        dockPreferences.showDockIcon = false
        check(!FactoryPreferences(defaults:dockDefaults).showDockIcon,"Dock visibility survives preference reload")
        dockPreferences.showDockIcon = true
        check(FactoryPreferences(defaults:dockDefaults).showDockIcon,"Dock visibility restores independently")
        let settingsStore = try LayoutStore(url:URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("wf-settings-\(UUID().uuidString).json"))
        let settings = SettingsWindow(store:settingsStore,preferences:FactoryPreferences())
        settings.refresh(); settings.window.contentView!.layoutSubtreeIfNeeded()
        let settingsScroll = settings.window.contentView!.subviews.compactMap{$0 as? NSScrollView}.first!
        check(settingsScroll.documentView!.frame.height>settingsScroll.contentSize.height,"long Settings content scrolls within the window")
        check(settings.window.frame.height<=(NSScreen.main?.visibleFrame.height ?? 2000),"Settings window stays within usable display height")
        settings.stop()
        print("native switcher panel: \(assertions) assertions passed; no windows shown or controlled")
    }
}
