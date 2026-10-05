-- Pure window-frame helpers that can be tested without Hammerspoon.

local M = {}

function M.centerHorizontally(windowFrame, screenFrame)
  return {
    x = screenFrame.x + ((screenFrame.w - windowFrame.w) / 2),
    y = windowFrame.y,
    w = windowFrame.w,
    h = windowFrame.h
  }
end

return M
