-- FEATURE: Center the active window on its monitor
--
-- Hold Right Cmd (remapped to F16 -- see key_remap.lua and right_cmd.lua)
-- and tap "c". Positions the focused window in the center of its current
-- monitor/screen, without altering its size.

local rightCmd = require("right_cmd")

local ALERT_STYLE = { textSize = 14, radius = 0 }

rightCmd.bind({}, "c", function()
    local win = hs.window.focusedWindow()
    if not win then
        hs.alert.show("No focused window", ALERT_STYLE, 1.5)
        return
    end

    win:centerOnScreen(nil, true, 0) -- 0 duration for instant move
    hs.alert.show("Centered", ALERT_STYLE, 1.5)
end)
