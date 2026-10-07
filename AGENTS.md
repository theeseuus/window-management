# Working on Theseus window/workspace management

- The two Spoons are independent. Keep window geometry/Space movement in
  TheseusWindow and cross-app recipe workflows in TheseusWorkspace.
- To add or change application creation support, start with
  [docs/app-adapters.md](docs/app-adapters.md). Humans and agents use that same
  procedure. Exact app operations belong in `app_adapters.lua`, not in recipe
  data or the shared Establish/placement engine.
- Run `mise run validate` for scoped changes. The repository owns its Lua/Node
  versions; do not add global tools or dependencies for an adapter.
- Keep README behaviour/limitations and the adapter guide current when changing
  creation semantics or extension steps. Change SHORTCUTS.md only if bindings
  actually change; preserve historical interface evidence in design-qa.md.
- Mocked tests and a clean reload do not prove native window creation. Report
  which live app/version scenarios were tested. Arrange desktop pilots with
  the owner; do not grant Automation permission, quit project apps, or move
  other-Space windows to make a test pass.
- Follow the host's configuration-management and Git/publication policy when
  deploying and committing. Do not edit only a managed live Spoon.
