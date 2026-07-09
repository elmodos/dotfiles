-- FEATURE: Sticky move/resize mode for the active window
--
-- "m" enters a nested modal that stays active across multiple keypresses (unlike
-- every other leader command, which fires once and exits). Arrows nudge the
-- window's position; Shift+Arrows nudge its size, growing/shrinking from the
-- top-left corner. Holding a key relies on macOS's own key-repeat to move
-- continuously. A yellow outline overlay tracks the window's frame for the
-- duration of the mode.
--
-- hs.hotkey.modal:bind only intercepts the exact combos you bind; anything
-- else falls through to the focused app (e.g. typing). So all key handling
-- here runs through one hs.eventtap instead: it swallows every keyDown while
-- the mode is active, acting on recognised keys and silently ignoring
-- everything else (Escape or Return exit the mode, besides the idle timeout).

local step = 20   -- points per keypress
local minSize = 100 -- never resize a window smaller than this on either axis
local minVisible = 50 -- always keep at least this many points on-screen when moving
local outlineWidth = 4
local outlineColor = { red = 1, green = 0.84, blue = 0.25, alpha = 0.9 } -- same yellow as hint_click.lua/scroll.lua

-- keycode -> {plain = fn(dx,dy,dw,dh)-shaped deltas for no modifiers, shift = ditto for Shift-only}
local ARROW_DELTAS = {
    left  = { plain = { -step, 0, 0, 0 }, shift = { 0, 0, -step, 0 } },
    right = { plain = { step, 0, 0, 0 },  shift = { 0, 0, step, 0 } },
    up    = { plain = { 0, -step, 0, 0 }, shift = { 0, 0, 0, -step } },
    down  = { plain = { 0, step, 0, 0 },  shift = { 0, 0, 0, step } },
}

return function(leader)
    local adjustMode = hs.hotkey.modal.new()
    local targetWindow = nil
    local idleTimer = nil
    local outline = nil

    local function resetIdleTimer()
        if idleTimer then idleTimer:stop() end
        idleTimer = hs.timer.doAfter(leader.modeTimeout, function() adjustMode:exit() end)
    end

    -- One canvas, repositioned in place on every nudge (we already know the
    -- new frame synchronously, so no polling/watcher is needed to track it).
    local function showOutline()
        local f = targetWindow:frame()
        if not outline then
            outline = hs.canvas.new(f)
            outline:appendElements({
                type = "rectangle",
                action = "stroke",
                strokeColor = outlineColor,
                strokeWidth = outlineWidth,
                fillColor = { alpha = 0 },
            })
            outline:level(hs.canvas.windowLevels.overlay)
            outline:behaviorAsLabels({ "canJoinAllSpaces" })
            outline:show()
        else
            outline:frame(f)
        end
    end

    local function hideOutline()
        if outline then
            outline:delete()
            outline = nil
        end
    end

    -- Clamp so the window never resizes below minSize, never grows past its
    -- screen's usable frame, and can't be nudged fully off-screen (at least
    -- minVisible points of it must stay within the screen frame).
    local function clampFrame(frame)
        local screenFrame = targetWindow:screen():frame()
        frame.w = math.min(math.max(minSize, frame.w), screenFrame.w)
        frame.h = math.min(math.max(minSize, frame.h), screenFrame.h)
        frame.x = math.max(screenFrame.x - frame.w + minVisible,
            math.min(frame.x, screenFrame.x + screenFrame.w - minVisible))
        frame.y = math.max(screenFrame.y - frame.h + minVisible,
            math.min(frame.y, screenFrame.y + screenFrame.h - minVisible))
        return frame
    end

    local function nudge(dx, dy, dw, dh)
        if not targetWindow then return end
        local f = targetWindow:frame()
        f.x = f.x + dx
        f.y = f.y + dy
        f.w = f.w + dw
        f.h = f.h + dh
        targetWindow:setFrame(clampFrame(f), 0)
        showOutline()
        resetIdleTimer()
    end

    -- No-modifier and Shift-only checks, mirroring the exact-match semantics
    -- hs.hotkey.modal:bind used to give us for these combos. `fn` is
    -- deliberately excluded: macOS sets it on arrow/escape/Home/End/F-keys
    -- regardless of whether the physical Fn key is held, so treating it as a
    -- real modifier here would make these checks never match.
    local function isNoMods(flags)
        return not (flags.shift or flags.cmd or flags.alt or flags.ctrl)
    end
    local function isShiftOnly(flags)
        return flags.shift and not (flags.cmd or flags.alt or flags.ctrl)
    end

    local escapeCode = hs.keycodes.map["escape"]
    local returnCode = hs.keycodes.map["return"]
    local arrowsByCode = {}
    for name, deltas in pairs(ARROW_DELTAS) do
        arrowsByCode[hs.keycodes.map[name]] = deltas
    end

    -- Catches every keyDown while adjust mode is active (OS key-repeat included,
    -- so held keys keep firing with no separate repeatfn needed) and swallows
    -- it unconditionally: recognised keys act, everything else is ignored.
    local keyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
        local code = event:getKeyCode()
        local flags = event:getFlags()

        if (code == escapeCode or code == returnCode) and isNoMods(flags) then
            adjustMode:exit()
            return true
        end

        local deltas = arrowsByCode[code]
        if deltas then
            if isNoMods(flags) then
                nudge(table.unpack(deltas.plain))
            elseif isShiftOnly(flags) then
                nudge(table.unpack(deltas.shift))
            end
        end

        return true
    end)

    function adjustMode:entered()
        targetWindow = hs.window.focusedWindow()
        if not targetWindow then
            leader.alert("No focused window")
            adjustMode:exit()
            return
        end
        showOutline()
        resetIdleTimer()
        keyTap:start()
    end

    function adjustMode:exited()
        keyTap:stop()
        if idleTimer then
            idleTimer:stop()
            idleTimer = nil
        end
        hideOutline()
        targetWindow = nil
    end

    leader.registerCommand({}, "m", function() adjustMode:enter() end, "m — move/resize")
end
