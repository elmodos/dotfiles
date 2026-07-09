-- FEATURE: Keyboard scroll mode (HomeRow-style scrolling)
--
-- Cmd+Shift+K scans for scrollable areas in the focused window:
--   * If 0 areas found: falls back to window center and enters scroll mode.
--   * If 1 area found: warps to its center and enters scroll mode.
--   * If >1 areas found: shows Vimium-style hints over each area. Typing
--     the hint warps to that area and enters scroll mode.
--
-- Scroll keys (in scroll mode):
--   h j k l        scroll left / down / up / right
--   d / u          half-page down / up
--   g / shift+g    jump to top / bottom
--   esc / q        exit scroll mode

-- ---- Tuning (tweak to taste) -----------------------------------------------
local TICK = 0.016        -- timer period for continuous scroll (~60fps)
local STEP = 8            -- scroll speed in pixels per tick while a direction is held
local PAGE_FRACTION = 0.5 -- fraction of the window height for d/u (half page)
local FULL_PAGE_FRACTION = 0.92 -- fraction for PageUp/PageDown (full page)
local JUMP = 100000       -- big one-shot scroll for g / G (top / bottom)
local WARP_TO_FOCUSED = true
local HINT_DURATION = 2.5 -- seconds the help bar stays before fading ("?" re-shows it)
local alertStyle = { textSize = 14, radius = 0 }

-- Hint selection tuning
local MAX_DEPTH = 30
local MAX_ELEMENTS = 40
local CHARS = "fjdkslaghzqwertyuiop"
local FONT_SIZE = 14
local TIMEOUT = 6

local SCROLLABLE_ROLES = {
    AXScrollArea = true,
    AXWebArea = true,
    AXTextArea = true,
    AXTable = true,
    AXList = true,
    AXOutline = true,
    AXGrid = true,
}
-- ----------------------------------------------------------------------------

local scroll = hs.hotkey.modal.new()

local dirs = {}      -- set of currently-held directions, e.g. dirs.down = true
local timer = nil
local alertId = nil
local borderCanvas = nil

local HINT_TEXT = "⬍ scroll  ·  hjkl / arrows move  ·  d/u / PgUp·PgDn page  ·  g/G / Home·End ends  ·  ? help  ·  esc"

-- Show the help bar briefly; it fades on its own after HINT_DURATION.
local function showHint()
    if alertId then hs.alert.closeSpecific(alertId) end
    alertId = hs.alert.show(HINT_TEXT, alertStyle, hs.screen.mainScreen(), HINT_DURATION)
end

-- Net scroll vector from held keys.
local function vector()
    local x, y = 0, 0
    if dirs.up then y = y + 1 end
    if dirs.down then y = y - 1 end
    if dirs.left then x = x + 1 end
    if dirs.right then x = x - 1 end
    return x, y
end

local function startTimer()
    if timer then return end
    timer = hs.timer.doEvery(TICK, function()
        local x, y = vector()
        if x == 0 and y == 0 then return end
        hs.eventtap.event.newScrollEvent(
            { math.floor(x * STEP), math.floor(y * STEP) }, {}, "pixel"
        ):post()
    end)
end

local function stopTimerIfIdle()
    if next(dirs) == nil then
        if timer then timer:stop(); timer = nil end
    end
end

-- Hold-to-scroll: press marks the direction active, release clears it.
local function bindDir(key, dir)
    scroll:bind({}, key,
        function() dirs[dir] = true; startTimer() end,
        function() dirs[dir] = nil; stopTimerIfIdle() end)
end
bindDir("h", "left")
bindDir("j", "down")
bindDir("k", "up")
bindDir("l", "right")
bindDir("left", "left")
bindDir("down", "down")
bindDir("up", "up")
bindDir("right", "right")

-- One-shot page / jump scrolls.
local function viewHeight()
    local win = hs.window.focusedWindow()
    if win then return win:frame().h end
    local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
    return (screen and screen:frame().h) or 800
end

local function pageScroll(sign, fraction)
    local amount = math.floor(viewHeight() * (fraction or PAGE_FRACTION)) * sign
    hs.eventtap.event.newScrollEvent({ 0, amount }, {}, "pixel"):post()
end

local function jump(sign)
    hs.eventtap.event.newScrollEvent({ 0, JUMP * sign }, {}, "pixel"):post()
end

scroll:bind({}, "d", function() pageScroll(-1) end)
scroll:bind({}, "u", function() pageScroll(1) end)
scroll:bind({}, "g", function() jump(1) end)
scroll:bind({ "shift" }, "g", function() jump(-1) end)

scroll:bind({}, "pagedown", function() pageScroll(-1, FULL_PAGE_FRACTION) end)
scroll:bind({}, "pageup", function() pageScroll(1, FULL_PAGE_FRACTION) end)
scroll:bind({}, "home", function() jump(1) end)
scroll:bind({}, "end", function() jump(-1) end)

scroll:bind({ "shift" }, "/", showHint)

scroll:bind({}, "escape", function() scroll:exit() end)
scroll:bind({}, "q", function() scroll:exit() end)

function scroll:entered()
    showHint()
end

function scroll:exited()
    dirs = {}
    if timer then timer:stop(); timer = nil end
    if alertId then hs.alert.closeSpecific(alertId); alertId = nil end
    if borderCanvas then borderCanvas:delete(); borderCanvas = nil end
end

-- ---- Scrollable Element Traversal & Deduplication --------------------------

local function isScrollable(el)
    local role = el:attributeValue("AXRole")
    return role and SCROLLABLE_ROLES[role]
end

local function visible(f, sf)
    if not (f and f.w and f.h) or f.w <= 1 or f.h <= 1 then return false end
    local cx, cy = f.x + f.w / 2, f.y + f.h / 2
    return cx >= sf.x and cx <= sf.x + sf.w and cy >= sf.y and cy <= sf.y + sf.h
end

local function collect(el, depth, acc, sf)
    if #acc >= MAX_ELEMENTS or depth > MAX_DEPTH then return end
    pcall(function()
        if isScrollable(el) then
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

local function deduplicate(candidates)
    local result = {}
    for _, item in ipairs(candidates) do
        local f = item.frame
        if f and f.x and f.y and f.w and f.h then
            local cx = f.x + f.w / 2
            local cy = f.y + f.h / 2
            local duplicate = false
            for _, existing in ipairs(result) do
                local ef = existing.frame
                local ecx = ef.x + ef.w / 2
                local ecy = ef.y + ef.h / 2
                if math.abs(cx - ecx) < 8 and math.abs(cy - ecy) < 8 then
                    -- If they overlap, keep the more specific/nested (smaller) one
                    if (f.w * f.h) < (ef.w * ef.h) then
                        existing.el = item.el
                        existing.frame = f
                    end
                    duplicate = true
                    break
                end
            end
            if not duplicate then
                result[#result + 1] = { el = item.el, frame = f }
            end
        end
    end
    return result
end

local function genLabels(n)
    local labels = {}
    if n <= #CHARS then
        for i = 1, n do labels[i] = CHARS:sub(i, i) end
    else
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

-- ---- Selection Overlay & Keystroke Capture ---------------------------------

local selectCanvas, selectTap, selectTimeoutTimer
local selectHints = {}
local selectTyped = ""

local function cleanupSelection()
    if selectTimeoutTimer then selectTimeoutTimer:stop(); selectTimeoutTimer = nil end
    if selectTap then selectTap:stop(); selectTap = nil end
    if selectCanvas then selectCanvas:delete(); selectCanvas = nil end
    selectHints = {}
    selectTyped = ""
end

local function resetSelectionTimeout()
    if selectTimeoutTimer then selectTimeoutTimer:stop() end
    selectTimeoutTimer = hs.timer.doAfter(TIMEOUT, cleanupSelection)
end

local function drawSelection()
    if not selectCanvas then return end
    local sf = selectCanvas:frame()
    local els = {}
    for _, h in ipairs(selectHints) do
        if h.label:sub(1, #selectTyped) == selectTyped then
            local remaining = h.label:sub(#selectTyped + 1)
            local f = h.frame
            local w = 8 + 10 * #remaining
            local boxH = FONT_SIZE + 6
            local x = (f.x + f.w / 2) - w / 2 - sf.x
            local y = (f.y + f.h / 2) - boxH / 2 - sf.y
            
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
    selectCanvas:replaceElements(els)
end

local function showBorder(frame)
    if borderCanvas then borderCanvas:delete(); borderCanvas = nil end
    if not frame then
        local win = hs.window.focusedWindow()
        if win then
            frame = win:frame()
        end
    end
    if not frame then return end

    borderCanvas = hs.canvas.new(frame)
    borderCanvas:level(hs.canvas.windowLevels.overlay)
    borderCanvas:replaceElements({
        {
            type = "rectangle",
            action = "stroke",
            strokeColor = { red = 1, green = 0.84, blue = 0.25, alpha = 0.8 },
            strokeWidth = 3,
            roundedRectRadii = { xRadius = 4, yRadius = 4 },
            frame = { x = 1.5, y = 1.5, w = frame.w - 3, h = frame.h - 3 }
        }
    })
    borderCanvas:show()
end

local function enterScrollMode(frame)
    if frame then
        local cx = frame.x + frame.w / 2
        local cy = frame.y + frame.h / 2
        hs.mouse.absolutePosition({ x = cx, y = cy })
    else
        if WARP_TO_FOCUSED then
            local win = hs.window.focusedWindow()
            if win then
                local f = win:frame()
                hs.mouse.absolutePosition({ x = f.x + f.w / 2, y = f.y + f.h / 2 })
            end
        end
    end
    showBorder(frame)
    scroll:enter()
end

local function onSelectKey(e)
    resetSelectionTimeout()
    local name = hs.keycodes.map[e:getKeyCode()]
    if name == "escape" then
        cleanupSelection()
        return true
    elseif name == "delete" then
        selectTyped = selectTyped:sub(1, -2)
        drawSelection()
        return true
    elseif name and #name == 1 and name:match("%a") then
        local candidate = selectTyped .. name
        local matches = {}
        for _, h in ipairs(selectHints) do
            if h.label:sub(1, #candidate) == candidate then
                matches[#matches + 1] = h
            end
        end
        if #matches == 0 then
            return true
        end
        selectTyped = candidate
        if #matches == 1 and matches[1].label == selectTyped then
            local frame = matches[1].frame
            cleanupSelection()
            enterScrollMode(frame)
            return true
        end
        drawSelection()
        return true
    end
    return true
end

local function start()
    cleanupSelection()

    local win = hs.window.focusedWindow()
    if not win then
        enterScrollMode(nil)
        return
    end

    local axwin = hs.axuielement.windowElement(win)
    if not axwin then
        enterScrollMode(nil)
        return
    end

    local sf = win:screen():fullFrame()
    local acc = {}
    collect(axwin, 0, acc, sf)

    local candidates = deduplicate(acc)

    if #candidates == 0 then
        enterScrollMode(nil)
    elseif #candidates == 1 then
        enterScrollMode(candidates[1].frame)
    else
        local labels = genLabels(#candidates)
        selectHints = {}
        for i, item in ipairs(candidates) do
            selectHints[i] = { el = item.el, frame = item.frame, label = labels[i] }
        end
        selectTyped = ""

        selectCanvas = hs.canvas.new(sf)
        selectCanvas:level(hs.canvas.windowLevels.overlay)
        selectCanvas:show()
        drawSelection()

        selectTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, onSelectKey):start()
        resetSelectionTimeout()
    end
end

-- Bind Cmd+Shift+K to trigger the scroll area scanner
hs.hotkey.bind({ "cmd", "shift" }, "k", start)
