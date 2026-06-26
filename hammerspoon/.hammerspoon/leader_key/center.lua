-- FEATURE: Center the active window on its monitor
--
-- Positions the focused window in the center of its current monitor/screen,
-- without altering its size.

return function(leader)
    -- Bound to the "c" key (no modifier needed inside leader mode).
    leader.registerCommand({}, "c", function()
        local win = hs.window.focusedWindow()
        if not win then
            leader.alert("No focused window")
            return
        end

        win:centerOnScreen(nil, true, 0) -- 0 duration for instant move
        leader.alert("Centered")
    end, "c — center")
end
