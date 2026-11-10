-- Shared "hotkey toggles an app" logic for toggle_terminal.lua and
-- toggle_claude.lua: hide it if it's frontmost, otherwise bring it forward
-- on the screen the mouse is on (launching it if it isn't running).
--
-- Apps are looked up by exact bundle ID: one NSRunningApplication query.
-- hs.application.find("Name") instead builds an object for EVERY running
-- app and compares names on each keypress -- and when nothing matches (app
-- not running) it falls back to hs.window.find, which walks every window of
-- every app over Accessibility. Any app slow to answer AX stalls that walk
-- (up to the 2 s AX timeout set in init.lua, per app), freezing
-- Hammerspoon's main thread and every other hotkey with it.

local M = {}

function M.toggle(bundleID)
    local app = hs.application.applicationsForBundleID(bundleID)[1]
    if not app then
        hs.application.launchOrFocusByBundleID(bundleID)
        return
    end

    if app:isFrontmost() then
        app:hide()
        return
    end

    app:activate()
    local win = app:mainWindow()
    local targetScreen = hs.mouse.getCurrentScreen()
    if win and targetScreen and win:screen() ~= targetScreen then
        win:moveToScreen(targetScreen, true, true, 0)
    end
end

return M
