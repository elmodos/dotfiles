-- FEATURE: Keyboard scroll mode (HomeRow-style scrolling)
--
-- Cmd+Shift+K enters a dedicated scroll sub-mode that synthesizes real
-- scroll-wheel events (hs.eventtap.event.newScrollEvent), so it scrolls
-- whatever app is under the cursor / focused window:
--   h j k l        scroll left / down / up / right (held = continuous, accelerates)
--   d / u          half-page down / up (one shot)
--   g / shift+g    jump to top / bottom
--   esc / q        exit scroll mode
--
-- Scroll events are routed by macOS to the view under the MOUSE cursor, so on
-- entry we warp the pointer to the center of the focused window; that makes
-- "scroll the thing I'm looking at" behave predictably regardless of where the
-- mouse was left. Set WARP_TO_FOCUSED = false to scroll under the mouse as-is.

-- ---- Tuning (tweak to taste) -----------------------------------------------
local TICK = 0.016        -- timer period for continuous scroll (~60fps)
local STEP = 8            -- scroll speed in pixels per tick while a direction is held
local PAGE_FRACTION = 0.5 -- fraction of the window height for d/u (half page)
local FULL_PAGE_FRACTION = 0.92 -- fraction for PageUp/PageDown (full page)
local JUMP = 100000       -- big one-shot scroll for g / G (top / bottom)
local WARP_TO_FOCUSED = true
local HINT_DURATION = 2.5 -- seconds the help bar stays before fading ("?" re-shows it)
local alertStyle = { textSize = 14, radius = 0 }
-- ----------------------------------------------------------------------------

local scroll = hs.hotkey.modal.new()

local dirs = {}      -- set of currently-held directions, e.g. dirs.down = true
local timer = nil
local alertId = nil

local HINT_TEXT = "⬍ scroll  ·  hjkl / arrows move  ·  d/u / PgUp·PgDn page  ·  g/G / Home·End ends  ·  ? help  ·  esc"

-- Show the help bar briefly; it fades on its own after HINT_DURATION.
local function showHint()
    if alertId then hs.alert.closeSpecific(alertId) end
    alertId = hs.alert.show(HINT_TEXT, alertStyle, hs.screen.mainScreen(), HINT_DURATION)
end

-- Net scroll vector from held keys. Per newScrollEvent: positive values
-- scroll up / left, negative scroll down / right.
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
        if x == 0 and y == 0 then return end -- opposite keys cancel out
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
-- Arrow keys mirror hjkl.
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
-- sign +1 = toward the top (scroll up), -1 = toward the bottom (scroll down).
local function jump(sign)
    hs.eventtap.event.newScrollEvent({ 0, JUMP * sign }, {}, "pixel"):post()
end

scroll:bind({}, "d", function() pageScroll(-1) end) -- half page down
scroll:bind({}, "u", function() pageScroll(1) end)  -- half page up
scroll:bind({}, "g", function() jump(1) end)        -- top
scroll:bind({ "shift" }, "g", function() jump(-1) end) -- bottom

-- Navigation-cluster keys mirror the above.
scroll:bind({}, "pagedown", function() pageScroll(-1, FULL_PAGE_FRACTION) end)
scroll:bind({}, "pageup", function() pageScroll(1, FULL_PAGE_FRACTION) end)
scroll:bind({}, "home", function() jump(1) end)
scroll:bind({}, "end", function() jump(-1) end)

scroll:bind({ "shift" }, "/", showHint) -- "?" re-shows the help bar

scroll:bind({}, "escape", function() scroll:exit() end)
scroll:bind({}, "q", function() scroll:exit() end)

function scroll:entered()
    if WARP_TO_FOCUSED then
        local win = hs.window.focusedWindow()
        if win then
            local f = win:frame()
            hs.mouse.absolutePosition({ x = f.x + f.w / 2, y = f.y + f.h / 2 })
        end
    end
    showHint()
end

function scroll:exited()
    dirs = {}
    if timer then timer:stop(); timer = nil end
    if alertId then hs.alert.closeSpecific(alertId); alertId = nil end
end

-- Bind Cmd+Shift+K to enter scroll mode
hs.hotkey.bind({ "cmd", "shift" }, "k", function() scroll:enter() end)
