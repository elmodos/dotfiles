-- FEATURE: Tile windows side-by-side

return function(leader)
    local function tileWindowsSideBySide()
        local screen = hs.window.focusedWindow() and hs.window.focusedWindow():screen() or hs.screen.mainScreen()
        if not screen then return end

        local visibleWindows = hs.window.orderedWindows()
        local windowsOnScreen = {}

        for _, win in ipairs(visibleWindows) do
            if win:screen() == screen and win:isStandard() and not win:isMinimized() then
                table.insert(windowsOnScreen, win)
            end
        end

        local count = #windowsOnScreen
        if count == 0 then
            leader.alert("No windows to tile")
            return
        end

        local screenFrame = screen:frame()
        local windowWidth = screenFrame.w / count

        for i, win in ipairs(windowsOnScreen) do
            local newFrame = hs.geometry.rect(
                screenFrame.x + (i - 1) * windowWidth,
                screenFrame.y,
                windowWidth,
                screenFrame.h
            )
            win:setFrame(newFrame, 0)
        end

        leader.alert("Tiled windows: " .. count)
    end

    -- Register tiling on Shift + \ (pipe "|")
    leader.registerCommand({"shift"}, "\\", tileWindowsSideBySide)
end
