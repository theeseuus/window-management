import AppKit

struct OptionalShortcutEnvelope: Codable {
  let version: Int
  let chord: ShortcutChord
}

// Optional app command, independent of the established 31 fixed control slots.
// Slot 65 has its own callback; app search and all 64 app slots keep their owners.
@MainActor
final class NewWindowShortcut {
  static let definition = ShortcutDefinition(
    id: "codex.new-window", title: "New Codex Window", group: .library, index: 2,
    standard: ShortcutChord(key: 45, modifiers: ShortcutChord.hyper, name: "N"))
  private static let preference = "codexNewWindowShortcut.v1"
  private let defaults: UserDefaults, store: KeybindingStore
  private let others: () -> [(String, ShortcutChord)]
  private let live: Bool
  private var ownerEnabled = false
  private(set) var chord: ShortcutChord?
  private(set) var active = false
  private(set) var error: String?
  var action: (() -> Void)?
  var changed: (() -> Void)?
  var reserved: [(String, ShortcutChord)] { chord.map { [(Self.definition.title, $0)] } ?? [] }
  init(
    defaults: UserDefaults = .standard, store: KeybindingStore, live: Bool = true,
    others: @escaping () -> [(String, ShortcutChord)]
  ) {
    self.defaults = defaults
    self.store = store
    self.live = live
    self.others = others
    if let data = defaults.data(forKey: Self.preference) {
      do {
        let value = try JSONDecoder().decode(OptionalShortcutEnvelope.self, from: data)
        guard value.version == 1 else {
          throw FactoryError("Unknown New Codex Window shortcut format.")
        }
        try validate(value.chord)
        chord = value.chord
      } catch {
        self.error = "New Codex Window shortcut could not be loaded: \(error.localizedDescription)"
      }
    }
  }
  private func validate(_ chord: ShortcutChord) throws {
    try ShortcutValidation.validateLocalCommand(chord)
    try ShortcutValidation.validate(
      store.overrides, additional: others() + [(Self.definition.title, chord)])
  }
  private func register(_ chord: ShortcutChord?, enabled: Bool) throws {
    if live {
      var rollback: Int32 = 0
      let status = WFConfigureApplicationHotKey(
        65, chord?.key ?? 0, chord?.modifiers ?? 0, enabled && chord != nil,
        { _, context in
          MainActor.assumeIsolated {
            let owner = Unmanaged<NewWindowShortcut>.fromOpaque(context).takeUnretainedValue()
            owner.action?()
          }
        }, Unmanaged.passUnretained(self).toOpaque(), &rollback)
      guard status == 0 else {
        if rollback != 0 { active = false }
        throw FactoryError(
          "New Codex Window shortcut is unavailable (status \(status)). Previous settings were kept."
        )
      }
    }
    active = enabled && chord != nil
  }
  func set(_ value: ShortcutChord?) throws {
    let data: Data?
    if let value {
      try validate(value)
      data = try JSONEncoder().encode(OptionalShortcutEnvelope(version: 1, chord: value))
    } else {
      data = nil
    }
    try register(value, enabled: ownerEnabled)
    if let data {
      defaults.set(data, forKey: Self.preference)
    } else {
      defaults.removeObject(forKey: Self.preference)
    }
    chord = value
    error = nil
    changed?()
  }
  func setOwnerEnabled(_ enabled: Bool) throws {
    guard ownerEnabled != enabled else { return }
    if let chord { try validate(chord) }
    do {
      try register(chord, enabled: enabled)
      ownerEnabled = enabled
      if chord != nil || defaults.object(forKey: Self.preference) == nil { error = nil }
      changed?()
    } catch {
      self.error = error.localizedDescription
      changed?()
      throw error
    }
  }
  func stop() {
    try? register(nil, enabled: false)
    ownerEnabled = false
  }
}
