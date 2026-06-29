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
M.commands = {} -- chord strings in registration order, listed in the entered() alert

function myMode:entered()
    hs.alert.show("Waiting for command:\n" .. table.concat(M.commands, ", "), alertStyle, modeTimeout)
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

-- Mac-style glyphs for the auto-generated chord shown in the hint list.
local MOD_SYMBOLS = { cmd = "⌘", ctrl = "⌃", alt = "⌥", shift = "⇧", fn = "fn" }
local KEY_SYMBOLS = {
    left = "←", right = "→", up = "↑", down = "↓",
    escape = "⎋", space = "␣", ["return"] = "⏎", delete = "⌫",
}

local function formatChord(modifiers, key)
    local out = ""
    if modifiers then
        for _, m in ipairs(modifiers) do
            -- Known modifiers get a glyph and butt against the key (⇧←);
            -- unknown ones fall back to "name+".
            out = out .. (MOD_SYMBOLS[m] or (m .. "+"))
        end
    end
    return out .. (KEY_SYMBOLS[key] or key)
end

-- label (optional):
--   nil    -> show the auto-generated chord (e.g. "⇧←")
--   string -> show this instead (e.g. "+", "|", or later "f — click")
--   false  -> bind the key but hide it from the hint list (used so the 1-9
--             loop contributes a single "1-9" entry rather than nine)
function M.registerCommand(modifiers, key, fn, label)
    if label ~= false then
        M.commands[#M.commands + 1] = label or formatChord(modifiers, key)
    end
    myMode:bind(modifiers, key, function()
        myMode:exit()
        fn()
    end)
end

M.ctrlTapWatcher = hs.eventtap.new({
    hs.eventtap.event.types.flagsChanged,
    hs.eventtap.event.types.keyDown,
    hs.eventtap.event.types.leftMouseDown,
    hs.eventtap.event.types.rightMouseDown,
}, function(event)
    local type = event:getType()
    if type == hs.eventtap.event.types.keyDown or
       type == hs.eventtap.event.types.leftMouseDown or
       type == hs.eventtap.event.types.rightMouseDown then
        lastCtrlTime = 0
        return false
    end

    local flags = event:getFlags()
    local keyCode = event:getKeyCode()

    -- If a different modifier key was pressed/released, reset the tap timer
    if keyCode ~= 59 and keyCode ~= 62 then
        lastCtrlTime = 0
        return false
    end

    local onlyCtrl = flags.ctrl and not flags.cmd and not flags.alt and not flags.shift and not flags.fn

    if not onlyCtrl then
        -- Control key was released or other flags are active
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
