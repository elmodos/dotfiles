-- FEATURE: Accessibility hint-clicker (HomeRow / Vimium-style) — PROTOTYPE
--
-- Cmd+Shift+Space      label every clickable element in the focused window,
--                      type the label to LEFT-click it.
--                      If the last key in sequence is typed with Shift, it RIGHT-clicks.
--   esc / backspace    cancel / undo last typed char.
--
-- How it works: walk the focused window's accessibility tree (hs.axuielement)
-- collecting elements that are actionable (clickable role or an AXPress action),
-- draw a Vimium-style label over each (hs.canvas), capture keystrokes with an
-- hs.eventtap, and on a full label synthesize a click at the element's center.
--
-- PROTOTYPE CAVEATS (this is the part HomeRow's native app optimizes):
--   * Traversal is SYNCHRONOUS with caps (MAX_ELEMENTS / MAX_DEPTH). On big web
--     pages / Electron apps it can briefly hang while scanning. Native AppKit
--     apps feel instant. The async upgrade path is axuielement:elementSearch().
--   * Coordinates assume AXFrame is in the same top-left screen space as the
--     window's screen; fine for typical single-origin layouts.

-- ---- Tuning ----------------------------------------------------------------
local MAX_ELEMENTS = 400  -- safety cap (also the max number of 2-char labels below)
local MAX_DEPTH = 50      -- how deep to descend the AX tree
local TIMEOUT = 6         -- auto-cancel after this many seconds of inactivity
local FONT_SIZE = 14
-- Home-row-first alphabet; 20 chars -> 400 unique 2-char labels.
local CHARS = "fjdkslaghzqwertyuiop"
-- Roles we always treat as clickable even without probing actions (cheap check).
local CLICKABLE_ROLES = {
    AXButton = true, AXLink = true, AXCheckBox = true, AXRadioButton = true,
    AXMenuItem = true, AXMenuButton = true, AXPopUpButton = true,
    AXTextField = true, AXTextArea = true, AXComboBox = true,
    AXDisclosureTriangle = true, AXTab = true, AXSlider = true, AXCell = true,
}
local alertStyle = { textSize = 14, radius = 0 }
-- ----------------------------------------------------------------------------

-- Per-invocation state.
local canvas, tap, timeoutTimer
local hints = {}   -- { {el=, frame=, label=}, ... }
local typed = ""

local function cleanup()
    if timeoutTimer then timeoutTimer:stop(); timeoutTimer = nil end
    if tap then tap:stop(); tap = nil end
    if canvas then canvas:delete(); canvas = nil end
    hints = {}
    typed = ""
end

local function resetTimeout()
    if timeoutTimer then timeoutTimer:stop() end
    timeoutTimer = hs.timer.doAfter(TIMEOUT, cleanup)
end

-- ---- Element collection ------------------------------------------------
local function isActionable(el)
    local role = el:attributeValue("AXRole")
    if role and CLICKABLE_ROLES[role] then return true end
    local ok, actions = pcall(function() return el:actionNames() end)
    if ok and actions then
        for _, a in ipairs(actions) do
            if a == "AXPress" then return true end
        end
    end
    return false
end

local function visible(f, sf)
    if not (f and f.w and f.h) or f.w <= 1 or f.h <= 1 then return false end
    local cx, cy = f.x + f.w / 2, f.y + f.h / 2 -- require center on-screen
    return cx >= sf.x and cx <= sf.x + sf.w and cy >= sf.y and cy <= sf.y + sf.h
end

local function collect(el, depth, acc, sf)
    if #acc >= MAX_ELEMENTS or depth > MAX_DEPTH then return end
    pcall(function()
        if isActionable(el) then
            local f = el:attributeValue("AXFrame")
            if visible(f, sf) then
                acc[#acc + 1] = { el = el, frame = f }
            end
        end
    end)
    local kids = el:attributeValue("AXChildren")
    if kids then
        for _, k in ipairs(kids) do
            collect(k, depth + 1, acc, sf)
            if #acc >= MAX_ELEMENTS then return end
        end
    end
end

-- ---- Labels ------------------------------------------------------------
local function genLabels(n)
    local labels = {}
    if n <= #CHARS then
        for i = 1, n do labels[i] = CHARS:sub(i, i) end
    else -- uniform 2-char labels -> no prefix ambiguity
        local i = 1
        for a = 1, #CHARS do
            for b = 1, #CHARS do
                if i > n then return labels end
                labels[i] = CHARS:sub(a, a) .. CHARS:sub(b, b)
                i = i + 1
            end
        end
    end
    return labels
end

-- ---- Overlay -----------------------------------------------------------
local function draw()
    if not canvas then return end
    local sf = canvas:frame()
    local els = {}
    for _, h in ipairs(hints) do
        if h.label:sub(1, #typed) == typed then
            local remaining = h.label:sub(#typed + 1) -- shrink as you type
            local f = h.frame
            local x, y = f.x - sf.x, f.y - sf.y
            local w = 8 + 10 * #remaining
            local boxH = FONT_SIZE + 6
            els[#els + 1] = {
                type = "rectangle", action = "fill",
                fillColor = { red = 1, green = 0.84, blue = 0.25, alpha = 0.95 },
                strokeColor = { red = 0.35, green = 0.27, blue = 0, alpha = 1 },
                strokeWidth = 1,
                roundedRectRadii = { xRadius = 3, yRadius = 3 },
                frame = { x = x, y = y, w = w, h = boxH },
            }
            els[#els + 1] = {
                type = "text", text = remaining,
                textColor = { red = 0, green = 0, blue = 0, alpha = 1 },
                textSize = FONT_SIZE, textFont = ".AppleSystemUIFontBold",
                textAlignment = "center",
                frame = { x = x, y = y + 2, w = w, h = boxH },
            }
        end
    end
    canvas:replaceElements(els)
end

-- ---- Action ------------------------------------------------------------
local function clickElement(frame, isShift)
    local center = { x = frame.x + frame.w / 2, y = frame.y + frame.h / 2 }
    if isShift then
        hs.eventtap.rightClick(center)
    else
        hs.eventtap.leftClick(center)
    end
end

-- ---- Keystroke capture -------------------------------------------------
local function onKey(e)
    resetTimeout()
    local name = hs.keycodes.map[e:getKeyCode()]
    if name == "escape" then
        cleanup()
        return true
    elseif name == "delete" then
        typed = typed:sub(1, -2)
        draw()
        return true
    elseif name and #name == 1 and name:match("%a") then
        local candidate = typed .. name
        local matches = {}
        for _, h in ipairs(hints) do
            if h.label:sub(1, #candidate) == candidate then matches[#matches + 1] = h end
        end
        if #matches == 0 then
            return true -- dead end: ignore the keystroke
        end
        typed = candidate
        if #matches == 1 and matches[1].label == typed then
            local frame = matches[1].frame
            local flags = e:getFlags()
            local isShift = flags.shift
            cleanup() -- tear down the overlay BEFORE clicking so it can't intercept
            clickElement(frame, isShift)
            return true
        end
        draw()
        return true
    end
    return true -- swallow everything else so it doesn't leak into the app
end

-- ---- Entry -------------------------------------------------------------
local function start()
    cleanup()

    local win = hs.window.focusedWindow()
    if not win then hs.alert.show("No focused window", alertStyle) return end
    local axwin = hs.axuielement.windowElement(win)
    if not axwin then hs.alert.show("No accessibility for this window", alertStyle) return end

    local sf = win:screen():fullFrame()
    local acc = {}
    collect(axwin, 0, acc, sf)
    if #acc == 0 then hs.alert.show("No clickable elements found", alertStyle) return end

    local labels = genLabels(#acc)
    hints = {}
    for i, item in ipairs(acc) do
        hints[i] = { el = item.el, frame = item.frame, label = labels[i] }
    end
    typed = ""

    canvas = hs.canvas.new(sf)
    canvas:level(hs.canvas.windowLevels.overlay)
    canvas:show()
    draw()

    tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, onKey):start()
    resetTimeout()
end

-- Bind Cmd+Shift+Space to trigger hint click
hs.hotkey.bind({ "cmd", "shift" }, "space", start)
