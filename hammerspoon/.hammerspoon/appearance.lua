-- FEATURE: Change macOS appearance between Dark and Light mode
--
-- Hold Right Cmd (remapped to F16 -- see key_remap.lua and right_cmd.lua)
-- and tap:
--   "d" -> Turn on system dark mode
--   "l" -> Turn on system light mode

local rightCmd = require("right_cmd")

local ALERT_STYLE = { textSize = 14, radius = 0 }

rightCmd.bind({}, "d", function()
    local script = [[
        tell application "System Events"
            tell appearance preferences
                set dark mode to true
            end tell
        end tell
    ]]
    local ok, _, _ = hs.osascript.applescript(script)
    if ok then
        hs.alert.show("Dark Mode Enabled", ALERT_STYLE, 1.5)
    else
        hs.alert.show("Failed to set Dark Mode", ALERT_STYLE, 1.5)
    end
end)

rightCmd.bind({}, "l", function()
    local script = [[
        tell application "System Events"
            tell appearance preferences
                set dark mode to false
            end tell
        end tell
    ]]
    local ok, _, _ = hs.osascript.applescript(script)
    if ok then
        hs.alert.show("Light Mode Enabled", ALERT_STYLE, 1.5)
    else
        hs.alert.show("Failed to set Light Mode", ALERT_STYLE, 1.5)
    end
end)
