-- Load and configure the two independent Spoons.
hs.loadSpoon("TheseusWindow")
spoon.TheseusWindow.showSpaceIndicator = true
spoon.TheseusWindow:bindHotkeys():start()

hs.loadSpoon("TheseusWorkspace")
spoon.TheseusWorkspace:bindHotkeys({
  capture = { { "ctrl", "alt", "cmd", "shift" }, "r" },
  restore = { { "ctrl", "alt", "cmd" }, "r" },
}):start()
