import AppKit

@MainActor
final class FactoryApp: NSObject, NSApplicationDelegate {
    var library: LibraryWindow?
    var settings: SettingsWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let args = CommandLine.arguments
            let preview = args.contains("--preview")
            let dataIndex = args.firstIndex(of:"--data-dir")
            let directory = dataIndex.flatMap { args.indices.contains($0+1) ? args[$0+1] : nil }
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/share/window-factory-native").path
            let store = try LayoutStore(url:URL(fileURLWithPath:directory).appendingPathComponent("layouts.json"))
            guard let registryURL = Bundle.main.url(forResource:"adapters",withExtension:"json") else { throw FactoryError("Bundled adapter registry missing.") }
            let registry = try JSONDecoder().decode(AdapterRegistry.self,from:Data(contentsOf:registryURL)); try registry.validate()
            if preview {
                let slots = registry.adapters.prefix(3).enumerated().map { index,adapter in
                    Slot(bundleID:adapter.bundleID,appName:adapter.name,ordinal:1,
                         frame:Frame(x:Double(index)/3,y:0,w:1.0/3,h:1))
                }
                let recipe = Recipe(name:"Native preview",capturedAt:"preview",windows:slots)
                store.catalog.recipes[recipe.name] = recipe
                store.catalog.recipes["Two-window preview"] = Recipe(name:"Two-window preview",capturedAt:"preview",windows:Array(slots.prefix(2)))
                store.catalog.recipes["Single-window preview"] = Recipe(name:"Single-window preview",capturedAt:"preview",windows:Array(slots.prefix(1)))
            }
            let preferences = FactoryPreferences()
            settings = SettingsWindow(store:store,preferences:preferences)
            library = LibraryWindow(store:store,registry:registry,preview:preview,preferences:preferences)
            library?.onSettings = { [weak self] in self?.showSettings(nil) }
            settings?.changed = { [weak self] in self?.library?.applyPreferences() }
            let menu = NSMenu(), item = NSMenuItem(), appMenu = NSMenu()
            let settingsItem = appMenu.addItem(withTitle:"Settings…",action:#selector(showSettings(_:)),keyEquivalent:",")
            settingsItem.target = self; appMenu.addItem(.separator())
            appMenu.addItem(withTitle:"Quit Window Factory",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
            item.submenu = appMenu; menu.addItem(item)
            let editItem = NSMenuItem(), edit = NSMenu(title:"Edit")
            edit.addItem(withTitle:"Undo",action:Selector(("undo:")),keyEquivalent:"z")
            let redo = edit.addItem(withTitle:"Redo",action:Selector(("redo:")),keyEquivalent:"z")
            redo.keyEquivalentModifierMask = [.command,.shift]
            edit.addItem(.separator())
            edit.addItem(withTitle:"Cut",action:#selector(NSText.cut(_:)),keyEquivalent:"x")
            edit.addItem(withTitle:"Copy",action:#selector(NSText.copy(_:)),keyEquivalent:"c")
            edit.addItem(withTitle:"Paste",action:#selector(NSText.paste(_:)),keyEquivalent:"v")
            edit.addItem(withTitle:"Select All",action:#selector(NSText.selectAll(_:)),keyEquivalent:"a")
            editItem.submenu = edit; menu.addItem(editItem)
            let layoutItem = NSMenuItem(), layoutMenu = NSMenu(title:"Layout")
            let commands: [(String,Selector,String,NSEvent.ModifierFlags)] = [
                ("Capture…",#selector(LibraryWindow.startCapture),"n",.command),
                ("Restore",#selector(LibraryWindow.restoreLayout),"\r",[]),
                ("Establish here",#selector(LibraryWindow.establishLayout),"\r",.command),
                ("Search",#selector(LibraryWindow.focusSearch),"f",.command),
                ("Import…",#selector(LibraryWindow.importLayouts),"i",.command),
                ("Export…",#selector(LibraryWindow.exportLayouts),"e",[.command,.shift]),
                ("Delete…",#selector(LibraryWindow.deleteLayout),"\u{8}",.command),
                ("Last report",#selector(LibraryWindow.showReport),"",[])]
            for (title,action,key,modifiers) in commands {
                let command = layoutMenu.addItem(withTitle:title,action:action,keyEquivalent:key)
                command.keyEquivalentModifierMask = modifiers; command.target = library
            }
            layoutItem.submenu = layoutMenu; menu.addItem(layoutItem)
            let windowItem = NSMenuItem(), windowMenu = NSMenu(title:"Window")
            windowMenu.addItem(withTitle:"Close Window",action:#selector(NSWindow.performClose(_:)),keyEquivalent:"w")
            windowItem.submenu = windowMenu; menu.addItem(windowItem)
            NSApp.mainMenu = menu
            library?.show()
        } catch {
            let alert = NSAlert(); alert.messageText = "Window Factory could not start"; alert.informativeText = error.localizedDescription
            alert.runModal(); NSApp.terminate(nil)
        }
    }
    @objc func showSettings(_ sender: Any?) { settings?.show() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication,hasVisibleWindows flag: Bool) -> Bool { library?.show(); return true }
    func applicationDidBecomeActive(_ notification: Notification) { library?.updateButtons(); settings?.refresh() }
    func applicationWillTerminate(_ notification: Notification) { library?.stop(); settings?.stop() }
}

@main
enum FactoryMain {
    @MainActor static func main() {
        if let index = CommandLine.arguments.firstIndex(of:"--validate-catalog") {
            do {
                guard CommandLine.arguments.indices.contains(index+1) else { throw FactoryError("Catalog path required.") }
                let catalog = try JSONDecoder().decode(Catalog.self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[index+1])))
                print("Validated \(catalog.recipes.count) layouts."); return
            } catch { fputs("Catalog validation failed.\n",stderr); exit(1) }
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = FactoryApp(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
