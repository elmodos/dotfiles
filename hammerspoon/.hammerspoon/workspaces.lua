-- FEATURE: Switching virtual desktops / Spaces (1-9)
--
-- Uses hs.spaces (macOS private window-management APIs) to jump directly to the
-- Nth Space, so it does NOT depend on the system Ctrl+Number shortcuts being
-- set or enabled.
--
-- Hold Right Cmd (remapped to F16 -- see key_remap.lua and right_cmd.lua)
-- and tap a digit 1-9.

local rightCmd = require("right_cmd")

local ALERT_STYLE = { textSize = 14, radius = 0 }

-- Generate commands for digits 1 through 9 automatically
for i = 1, 9 do
    rightCmd.bind({}, tostring(i), function()
        local screen = hs.screen.mainScreen()
        local spaces = hs.spaces.spacesForScreen(screen)

        if not (spaces and spaces[i]) then
            hs.alert.show("No Space " .. i, ALERT_STYLE, 1.5)
            return
        end

        hs.spaces.gotoSpace(spaces[i])
        hs.alert.show("Space " .. i, ALERT_STYLE, 1.5)
    end)
end
