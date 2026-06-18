-- FEATURE: Move the active window to the monitor on the left/right
--
-- Uses hs.screen directional layout (:toWest()/:toEast()) so it follows the
-- physical monitor arrangement, not screen index order.
--   Shift + Left  -> monitor to the west
--   Shift + Right -> monitor to the east

return function(leader)
    local function moveTo(direction)
        local win = hs.window.focusedWindow()
        if not win then
            leader.alert("No focused window")
            return
        end

        -- direction picks the neighbor of the window's current screen.
        local target = direction(win:screen())

        if not target then
            leader.alert("No monitor there")
            return
        end

        -- noResize=true keeps absolute size, ensureInBounds=true clamps to the
        -- target, 0 = instant (no slide).
        win:moveToScreen(target, true, true, 0)
    end

    leader.registerCommand({"shift"}, "left", function()
        moveTo(function(screen) return screen:toWest() end)
    end)
    leader.registerCommand({"shift"}, "right", function()
        moveTo(function(screen) return screen:toEast() end)
    end)
end
