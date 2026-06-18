-- FEATURE: Switching virtual desktops / Spaces (1-9)
--
-- Uses hs.spaces (macOS private window-management APIs) to jump directly to the
-- Nth Space, so it does NOT depend on the system Ctrl+Number shortcuts being
-- set or enabled.

return function(leader)
    -- Generate commands for digits 1 through 9 automatically
    for i = 1, 9 do
        leader.registerCommand({}, tostring(i), function()
            local screen = hs.screen.mainScreen()
            local spaces = hs.spaces.spacesForScreen(screen)

            if not (spaces and spaces[i]) then
                leader.alert("No Space " .. i)
                return
            end

            hs.spaces.gotoSpace(spaces[i])
            leader.alert("Space " .. i)
        end)
    end
end
