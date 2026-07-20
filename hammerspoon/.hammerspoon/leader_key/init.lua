-- Leader key: double-tap Ctrl to enter a modal "waiting for command" mode.

local lastCtrlTime = 0
local doublePressInterval = 0.4
local modeTimeout = 2 -- auto-exit waiting mode after this many seconds of inactivity
local alertStyle = { textSize = 14, radius = 0 }
local myMode = hs.hotkey.modal.new()
local modeTimer = nil

-- On-screen command menu (replaces the old plain-text hint alert): a centered
-- canvas panel listing every visible command, with Up/Down/Return browsing it.
local selectedIndex = 1
local menuCanvas = nil
local panelLayout = nil

local ROW_HEIGHT, ROW_FONT, ROW_FONT_SIZE = 18, ".AppleSystemUIFont", 13
local PANEL_PAD_X, PANEL_PAD_Y, PANEL_MIN_W = 20, 12, 160
local PANEL_BG     = { red = 0.12, green = 0.12, blue = 0.13, alpha = 0.58 }
local PANEL_STROKE = { white = 1, alpha = 0.12 }
-- Blue accent for the menu's own row highlight (distinct from the yellow
-- used by hint_click.lua/scroll.lua/move_resize.lua's AX-overlay hints).
local ROW_HIGHLIGHT = { red = 0.2, green = 0.55, blue = 1, alpha = 0.32 }
local TEXT_COLOR, TEXT_COLOR_SELECTED = { white = 0.88, alpha = 1 }, { white = 1.0, alpha = 1 }

local M = {}
M.alertStyle = alertStyle
M.mode = myMode
M.modeTimeout = modeTimeout -- shared idle timeout, reused by nested sub-modes (e.g. move_resize.lua)
M.commands = {} -- {modifiers, key, fn, label} rows in registration order, rendered as the menu panel

local function measureLabelWidth(label)
    local styled = hs.styledtext.new(label, { font = { name = ROW_FONT, size = ROW_FONT_SIZE } })
    return hs.drawing.getTextDrawingSize(styled).w
end

-- Sizes the panel to its actual content, then centers it on the screen
-- holding the focused window (same pattern as tiling.lua's tileWindowsSideBySide).
local function computePanelLayout()
    local maxLabelW = 0
    for _, row in ipairs(M.commands) do
        maxLabelW = math.max(maxLabelW, measureLabelWidth(row.label))
    end
    local w = math.max(PANEL_MIN_W, maxLabelW + PANEL_PAD_X * 2)
    local h = ROW_HEIGHT * #M.commands + PANEL_PAD_Y * 2

    local screen = hs.window.focusedWindow() and hs.window.focusedWindow():screen() or hs.screen.mainScreen()
    local sf = screen:frame()
    return { x = sf.x + (sf.w - w) / 2, y = sf.y + (sf.h - h) / 2, w = w, h = h }
end

-- Full redraw of the menu panel: background, then per row a highlight (if
-- selected) followed by its label text, so the text always draws on top.
local function redrawMenu()
    if not menuCanvas or not panelLayout then return end
    local els = {
        { type = "rectangle", action = "fill", fillColor = PANEL_BG, strokeColor = PANEL_STROKE,
          strokeWidth = 1, roundedRectRadii = { xRadius = 10, yRadius = 10 },
          frame = { x = 0, y = 0, w = panelLayout.w, h = panelLayout.h } },
    }
    for i, row in ipairs(M.commands) do
        local rowY = PANEL_PAD_Y + (i - 1) * ROW_HEIGHT
        if i == selectedIndex then
            els[#els + 1] = { type = "rectangle", action = "fill", fillColor = ROW_HIGHLIGHT,
                roundedRectRadii = { xRadius = 5, yRadius = 5 },
                frame = { x = 6, y = rowY, w = panelLayout.w - 12, h = ROW_HEIGHT } }
        end
        els[#els + 1] = { type = "text", text = row.label,
            textColor = (i == selectedIndex) and TEXT_COLOR_SELECTED or TEXT_COLOR,
            textSize = ROW_FONT_SIZE, textFont = ROW_FONT, textAlignment = "left",
            frame = { x = PANEL_PAD_X, y = rowY, w = panelLayout.w - PANEL_PAD_X * 2, h = ROW_HEIGHT } }
    end
    menuCanvas:replaceElements(els)
end

-- Restarts the idle-exit timer; called on entry and on every menu interaction
-- so browsing the list doesn't get cut off by a stray double-Ctrl's timeout.
local function resetModeTimer()
    if modeTimer then modeTimer:stop() end
    modeTimer = hs.timer.doAfter(modeTimeout, function() myMode:exit() end)
end

function myMode:entered()
    -- A redundant double-Ctrl-tap while the menu is already open would
    -- otherwise overwrite menuCanvas with a second hs.canvas, orphaning the
    -- first one on screen forever (exited() can only ever delete whichever
    -- canvas the variable currently points at). Treat it as a no-op instead.
    if menuCanvas then return end

    selectedIndex = 1
    panelLayout = computePanelLayout()
    menuCanvas = hs.canvas.new(panelLayout)
    menuCanvas:level(hs.canvas.windowLevels.popUpMenu)
    menuCanvas:show()
    redrawMenu()
    resetModeTimer()
end

function myMode:exited()
    if modeTimer then
        modeTimer:stop()
        modeTimer = nil
    end
    if menuCanvas then
        menuCanvas:delete()
        menuCanvas = nil
    end
    panelLayout = nil
end

function M.alert(text, duration)
    local style = alertStyle
    return hs.alert.show(text, style, duration or 1.5)
end

-- Mac-style glyphs for the auto-generated chord shown in the menu panel.
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
--   false  -> bind the key but hide it from the menu panel (used so the 1-9
--             loop contributes a single "1-9" entry rather than nine)
function M.registerCommand(modifiers, key, fn, label)
    if label ~= false then
        M.commands[#M.commands + 1] = {
            modifiers = modifiers,
            key = key,
            fn = fn,
            label = label or formatChord(modifiers, key),
        }
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
    if type == hs.eventtap.event.types.leftMouseDown or
       type == hs.eventtap.event.types.rightMouseDown then
        lastCtrlTime = 0
        -- A click means the user's attention (and next keystroke) has moved
        -- elsewhere; leaving the menu armed would let a still-bound chord
        -- (e.g. "d", "w", a digit) fire as a command instead of being typed.
        if menuCanvas then myMode:exit() end
        return false
    end
    if type == hs.eventtap.event.types.keyDown then
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

-- macOS can silently disable a CGEventTap if its callback doesn't respond
-- quickly enough (e.g. while gatherRoots() in hint_click.lua runs a slow
-- synchronous AX sweep on this same thread). Since ctrlTapWatcher runs on
-- every keystroke system-wide, once disabled it stops seeing real typing
-- until something restarts it. Poll and self-heal rather than requiring a
-- config reload.
hs.timer.doEvery(2, function()
    if not M.ctrlTapWatcher:isEnabled() then
        M.ctrlTapWatcher:start()
    end
end)

myMode:bind({}, "escape", function() myMode:exit() end)

-- Menu navigation: Up/Down move the highlight (wrapping) and stay in the
-- mode; Return invokes the highlighted row exactly like pressing its own
-- shortcut would. These are mode mechanics, not plugin rows, so they bypass
-- registerCommand and never appear as their own menu entry.
myMode:bind({}, "up", function()
    if #M.commands == 0 then return end
    selectedIndex = selectedIndex - 1
    if selectedIndex < 1 then selectedIndex = #M.commands end
    redrawMenu()
    resetModeTimer()
end)

myMode:bind({}, "down", function()
    if #M.commands == 0 then return end
    selectedIndex = selectedIndex + 1
    if selectedIndex > #M.commands then selectedIndex = 1 end
    redrawMenu()
    resetModeTimer()
end)

myMode:bind({}, "return", function()
    local row = M.commands[selectedIndex]
    myMode:exit()
    if row then row.fn() end
end)

require("leader_key.tiling")(M)
require("leader_key.workspaces")(M)
require("leader_key.maximize")(M)
require("leader_key.move_monitor")(M)
require("leader_key.appearance")(M)
require("leader_key.center")(M)
require("leader_key.convenient_size")(M)
require("leader_key.move_resize")(M)

return M
