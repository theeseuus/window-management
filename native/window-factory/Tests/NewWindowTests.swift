import AppKit

@main
struct NewWindowTests {
  @MainActor static func main() async throws {
    _ = NSApplication.shared
    var count = 0
    func check(_ value: Bool, _ message: String) {
      count += 1
      precondition(value, message)
    }
    let registry = try JSONDecoder().decode(
      AdapterRegistry.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    let adapters = Dictionary(uniqueKeysWithValues: registry.adapters.map { ($0.bundleID, $0) })
    let target = NewWindowTarget(display: 1, space: 7, frame: Frame(x: 0, y: 30, w: 1800, h: 1100))
    var here = target
    var ids: Set<UInt32> = [1, 2]
    var creates = 0
    var prepares = 0
    var waits = 0
    var blocked = false
    var mode = "success"
    let backend = NewWindowBackend(
      target: { here },
      prepare: { _, expected in
        prepares += 1
        guard here == expected, mode != "prepare-fail" else {
          throw FactoryError("context or permission changed")
        }
      },
      inventory: { _, expected in
        guard here == expected else { throw FactoryError("context changed") }
        return ids
      },
      create: { adapter, _ in
        check(
          adapter.bundleID == "com.openai.codex" && adapter.menu == ["File", "New Window"],
          "exact canonical Codex adapter reused")
        creates += 1
        if mode == "success" { ids.insert(UInt32(100 + creates)) }
        if mode == "late-error" {
          ids.insert(200)
          throw FactoryError("uncertain dispatch")
        }
        if mode == "multiple" { ids.formUnion([300, 301]) }
        if mode == "space-change" {
          here = NewWindowTarget(display: 1, space: 8, frame: target.frame)
        }
      },
      wait: {
        waits += 1
        try Task.checkCancellation()
      })
    let action = NewWindowAction(adapters: adapters, backend: backend)
    action.blocked = { blocked }
    func settle() async throws {
      for _ in 0..<100 {
        if !action.isBusy { return }
        try await Task.sleep(for: .milliseconds(5))
      }
      preconditionFailure("new-window fixture did not settle")
    }
    check(creates == 0, "construction never opens a window")
    blocked = true
    action.run("com.openai.codex")
    check(!action.isBusy && creates == 0, "busy owners prevent dispatch")
    blocked = false
    action.run("unknown.app")
    check(creates == 0, "unreviewed app rejected")
    action.run("com.openai.codex")
    action.run("com.openai.codex")
    try await settle()
    check(
      creates == 1 && action.receipt?.windowID == 101, "repeated trigger while busy dispatches once"
    )
    check(
      action.receipt?.target == target && ids.contains(1) && ids.contains(2),
      "receipt retains captured desktop and existing IDs")
    check(
      action.dispatched && !action.isBusy && prepares == 2,
      "checks occur before the single dispatch")
    mode = "prepare-fail"
    action.run("com.openai.codex")
    try await settle()
    check(
      creates == 1 && !action.dispatched && action.receipt == nil,
      "preflight failure leaves app untouched")
    mode = "late-error"
    action.run("com.openai.codex")
    try await settle()
    check(
      creates == 2 && action.dispatched && action.receipt == nil && ids.contains(200),
      "uncertain command is never retried or cleaned up")
    mode = "timeout"
    waits = 0
    action.run("com.openai.codex")
    try await settle()
    check(
      creates == 3 && waits == 50 && action.receipt == nil,
      "bounded discovery timeout does not repeat creation")
    mode = "space-change"
    action.run("com.openai.codex")
    try await settle()
    check(
      creates == 4 && action.receipt == nil,
      "desktop change stops confirmation without follow or retry")
    here = target
    mode = "multiple"
    action.run("com.openai.codex")
    try await settle()
    check(
      creates == 5 && action.receipt == nil,
      "ambiguous multiple arrivals are not claimed as one creation")
    action.stop()
    let dock = WindowCreationMenus.dock(
      target: nil, open: NSSelectorFromString("open:"), create: NSSelectorFromString("create:"),
      available: false)
    check(
      dock.items.map(\.title) == ["Open Window Factory", "New Codex Window Here"],
      "only Window Factory's own Dock menu is provided")
    check(
      !dock.autoenablesItems && !dock.items[1].isEnabled,
      "Dock command remains disabled when unavailable")
    let menu = SpaceIndicator.menu(target: nil)
    check(
      menu.items.contains {
        $0.identifier?.rawValue == "codex.new-window" && $0.title == "New Codex Window Here"
      }, "menu-bar action is discoverable")
    print(
      "native new-window action: \(count) assertions passed; injected desktop only, no live app creation or UI activation"
    )
  }
}
