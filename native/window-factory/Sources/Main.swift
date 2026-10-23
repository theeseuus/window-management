import AppKit

@MainActor
final class FactoryApp: NSObject, NSApplicationDelegate {
    var library: LibraryWindow?
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
            let menu = NSMenu(), item = NSMenuItem(), appMenu = NSMenu()
            appMenu.addItem(withTitle:"Quit Window Factory Native",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
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
            editItem.submenu = edit; menu.addItem(editItem); NSApp.mainMenu = menu
            library = LibraryWindow(store:store,registry:registry,preview:preview); library?.show()
        } catch {
            let alert = NSAlert(); alert.messageText = "Window Factory could not start"; alert.informativeText = error.localizedDescription
            alert.runModal(); NSApp.terminate(nil)
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication,hasVisibleWindows flag: Bool) -> Bool { library?.show(); return true }
    func applicationDidBecomeActive(_ notification: Notification) { library?.updateButtons() }
    func applicationWillTerminate(_ notification: Notification) { library?.stop() }
}

@main
enum FactoryMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = FactoryApp(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
