-- FEATURE: Maximize the active window
--
-- Resizes the focused window to fill the screen's usable frame (minus menu bar
-- and Dock) — NOT the native macOS fullscreen Space.

return function(leader)
    -- Bound to the +/= key (no Shift needed inside leader mode).
    leader.registerCommand({"shift"}, "=", function()
        local win = hs.window.focusedWindow()
        if not win then
            leader.alert("No focused window")
            return
        end

        win:maximize(0) -- duration 0 = instant, no animation
        leader.alert("Maximized")
    end, "+")
end
