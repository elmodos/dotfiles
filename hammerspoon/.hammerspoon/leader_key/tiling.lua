-- FEATURE: Tile windows side-by-side
--
-- Windows that can't be resized (e.g. the iOS Simulator, which reports AXSize as
-- not settable) keep their current width and participate as a fixed column; the
-- remaining width is split among the resizable windows.

return function(leader)
    -- A window is resizable if its accessibility AXSize attribute is settable.
    local function isResizable(win)
        local ax = hs.axuielement.windowElement(win)
        if not ax then return true end
        local ok, settable = pcall(function()
            return ax:isAttributeSettable("AXSize")
        end)
        -- If we can't tell, assume resizable (previous behaviour).
        if not ok or settable == nil then return true end
        return settable
    end

    local function tileWindowsSideBySide()
        local screen = hs.window.focusedWindow() and hs.window.focusedWindow():screen() or hs.screen.mainScreen()
        if not screen then return end

        local windowsOnScreen = {}
        for _, win in ipairs(hs.window.orderedWindows()) do
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

        -- Pass 1: classify, and sum up the width the fixed windows will keep.
        local fixedWidthTotal = 0
        local flexibleCount = 0
        for _, win in ipairs(windowsOnScreen) do
            if isResizable(win) then
                flexibleCount = flexibleCount + 1
            else
                fixedWidthTotal = fixedWidthTotal + win:size().w
            end
        end

        -- Width each resizable window gets from the leftover space.
        local flexibleWidth = 0
        if flexibleCount > 0 then
            flexibleWidth = math.max(0, (screenFrame.w - fixedWidthTotal) / flexibleCount)
        end

        -- Pass 2: place left-to-right.
        local x = screenFrame.x
        for _, win in ipairs(windowsOnScreen) do
            if isResizable(win) then
                win:setFrame(hs.geometry.rect(x, screenFrame.y, flexibleWidth, screenFrame.h), 0)
                x = x + flexibleWidth
            else
                -- Keep the window's own size; only reposition it (full height
                -- would just be ignored/constrained anyway).
                local size = win:size()
                win:setTopLeft(hs.geometry.point(x, screenFrame.y))
                x = x + size.w
            end
        end

        leader.alert("Tiled windows: " .. count)
    end

    -- Register tiling on Shift + \ (pipe "|")
    leader.registerCommand({"shift"}, "\\", tileWindowsSideBySide, "|")
end
