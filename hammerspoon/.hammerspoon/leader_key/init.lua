-- Leader key: double-tap Ctrl to enter a modal "waiting for command" mode.

local lastCtrlTime = 0
local doublePressInterval = 0.4
local modeTimeout = 2 -- auto-exit waiting mode after this many seconds of inactivity
local alertStyle = { textSize = 14, radius = 0 }
local myMode = hs.hotkey.modal.new()
local modeTimer = nil

local M = {}
M.alertStyle = alertStyle
M.mode = myMode

function myMode:entered()
    hs.alert.show("Waiting for command...", alertStyle, modeTimeout)
    -- Auto-cancel if no command key follows, so a stray double-Ctrl doesn't
    -- swallow a later keystroke meant for text input.
    if modeTimer then modeTimer:stop() end
    modeTimer = hs.timer.doAfter(modeTimeout, function() myMode:exit() end)
end

function myMode:exited()
    if modeTimer then
        modeTimer:stop()
        modeTimer = nil
    end
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
require("leader_key.appearance")(M)
require("leader_key.center")(M)
require("leader_key.convenient_size")(M)

return M
