-- FEATURE: Maximize the active window
--
-- Resizes the focused window to fill the screen's usable frame (minus menu bar
-- and Dock) — NOT the native macOS fullscreen Space.
--
-- Hold Right Cmd (remapped to F16 -- see key_remap.lua and right_cmd.lua)
-- and tap Shift+= (the "+" key).

local rightCmd = require("right_cmd")

local ALERT_STYLE = { textSize = 14, radius = 0 }

rightCmd.bind({"shift"}, "=", function()
    local win = hs.window.focusedWindow()
    if not win then
        hs.alert.show("No focused window", ALERT_STYLE, 1.5)
        return
    end

    win:maximize(0) -- duration 0 = instant, no animation
    hs.alert.show("Maximized", ALERT_STYLE, 1.5)
end)
