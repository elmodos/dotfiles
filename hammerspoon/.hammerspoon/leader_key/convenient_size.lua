-- FEATURE: Resize the active window to a "convenient" size
--
-- On an ultrawide monitor, maximizing stretches a window across the whole
-- width, which is unusable for a terminal/editor. This shrinks the focused
-- window to a comfortable reading column, keeping its current position
-- (just nudged back on-screen if the new size would otherwise hang off an
-- edge).
--
-- The target width is a fraction of the screen width, then CLAMPED on both
-- ends:
--   * minWidth keeps it comfortable on a narrow laptop screen, while
--   * maxWidth is what actually tames the ultrawide.
-- (And it never exceeds the screen itself, for very small displays.)
-- Height is a large fraction of the usable frame, so it stays clear of the
-- menu bar and Dock and reads as "deliberately sized", not maximized.

local widthFraction = 0.7  -- preferred share of the screen width
local minWidth = 1100      -- ...but never narrower than this many points
local maxWidth = 1600      -- ...and never wider than this many points
local heightFraction = 0.92

return function(leader)
    leader.registerCommand({}, "w", function()
        local win = hs.window.focusedWindow()
        if not win then
            leader.alert("No focused window")
            return
        end

        local frame = win:screen():frame() -- usable area (excludes menu bar/Dock)
        local current = win:frame()

        -- Clamp the preferred width between min and max, then never exceed the
        -- screen (matters only on displays narrower than minWidth).
        local w = math.min(frame.w, math.max(minWidth, math.min(frame.w * widthFraction, maxWidth)))
        local h = frame.h * heightFraction

        -- Keep the window's current top-left, but pull it back on-screen if
        -- the new size would otherwise push it past the screen's edges.
        local x = math.min(current.x, frame.x + frame.w - w)
        local y = math.min(current.y, frame.y + frame.h - h)
        x = math.max(x, frame.x)
        y = math.max(y, frame.y)

        win:setFrame(hs.geometry.rect(x, y, w, h), 0) -- 0 = instant, no animation
        leader.alert("Convenient size")
    end, "w — size")
end
