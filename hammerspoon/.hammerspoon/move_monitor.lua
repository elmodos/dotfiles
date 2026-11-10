-- FEATURE: Move the active window to the monitor on the left/right
--
-- Uses hs.screen directional layout (:toWest()/:toEast()) so it follows the
-- physical monitor arrangement, not screen index order.
--
-- Hold Right Cmd (remapped to F16 -- see key_remap.lua and right_cmd.lua)
-- and tap:
--   Shift + Left  -> monitor to the west
--   Shift + Right -> monitor to the east

local rightCmd = require("right_cmd")

local ALERT_STYLE = { textSize = 14, radius = 0 }

local function moveTo(direction)
    local win = hs.window.focusedWindow()
    if not win then
        hs.alert.show("No focused window", ALERT_STYLE, 1.5)
        return
    end

    -- direction picks the neighbor of the window's current screen.
    local target = direction(win:screen())

    if not target then
        hs.alert.show("No monitor there", ALERT_STYLE, 1.5)
        return
    end

    -- noResize=true keeps absolute size, ensureInBounds=true clamps to the
    -- target, 0 = instant (no slide).
    win:moveToScreen(target, true, true, 0)
end

rightCmd.bind({"shift"}, "left", function()
    moveTo(function(screen) return screen:toWest() end)
end)
rightCmd.bind({"shift"}, "right", function()
    moveTo(function(screen) return screen:toEast() end)
end)
