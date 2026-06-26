-- FEATURE: Change macOS appearance between Dark and Light mode
--
-- Adds handlers inside leader key mode:
--   "d" -> Turn on system dark mode
--   "l" -> Turn on system light mode

return function(leader)
    leader.registerCommand({}, "d", function()
        local script = [[
            tell application "System Events"
                tell appearance preferences
                    set dark mode to true
                end tell
            end tell
        ]]
        local ok, _, _ = hs.osascript.applescript(script)
        if ok then
            leader.alert("Dark Mode Enabled")
        else
            leader.alert("Failed to set Dark Mode")
        end
    end, "d — dark")

    leader.registerCommand({}, "l", function()
        local script = [[
            tell application "System Events"
                tell appearance preferences
                    set dark mode to false
                end tell
            end tell
        ]]
        local ok, _, _ = hs.osascript.applescript(script)
        if ok then
            leader.alert("Light Mode Enabled")
        else
            leader.alert("Failed to set Light Mode")
        end
    end, "l — light")
end
