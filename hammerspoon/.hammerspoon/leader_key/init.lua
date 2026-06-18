-- Leader key: double-tap Ctrl to enter a modal "waiting for command" mode.

local lastCtrlTime = 0
local doublePressInterval = 0.4
local alertStyle = { textSize = 14, radius = 0 }
local myMode = hs.hotkey.modal.new()

local M = {}
M.alertStyle = alertStyle
M.mode = myMode

function myMode:entered()
    hs.alert.show("Waiting for command...", alertStyle, 1.5)
end

function M.alert(text, duration)
    local style = alertStyle
    return hs.alert.show(text, style, duration or 1.5)
end

function M.registerCommand(modifiers, key, fn)
    myMode:bind(modifiers, key, function()
        myMode:exit()
        fn()
    end)
end

M.ctrlTapWatcher = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(event)
    local flags = event:getFlags()
    local keyCode = event:getKeyCode()

    local onlyCtrl = (keyCode == 59 or keyCode == 62)
        and flags.ctrl and not flags.cmd and not flags.alt and not flags.shift and not flags.fn

    if not onlyCtrl then
        if flags.ctrl then lastCtrlTime = 0 end
        return false
    end

    local now = hs.timer.secondsSinceEpoch()
    if lastCtrlTime > 0 and (now - lastCtrlTime) < doublePressInterval then
        myMode:enter()
        lastCtrlTime = 0 -- Fully reset, so the next press counts as the first
    else
        lastCtrlTime = now
    end
    return false
end):start()

myMode:bind({}, "escape", function() myMode:exit() end)

require("leader_key.tiling")(M)
require("leader_key.workspaces")(M)
require("leader_key.maximize")(M)
require("leader_key.move_monitor")(M)

return M
