-- Shared "hold Right Cmd (remapped to F16 -- see key_remap.lua), tap a key"
-- trigger for every feature file.
--
-- This has to be exactly one hs.hotkey.bind({}, "F16", ...), not one per
-- feature file: Hammerspoon's own docs for hs.hotkey.new/bind say "You can
-- create multiple hs.hotkey objects for the same keyboard combination, but
-- only one can be active at any given time" -- each later bind SHADOWS every
-- earlier one for that exact combo. With eight independent F16 binds (one
-- per feature file), only the last-required file's bind was ever live; every
-- other feature's F16 trigger silently did nothing (RightCmd+W never
-- entered convenient-size, only RightCmd+M -- the last file required in
-- init.lua -- worked). One shared modal, entered/exited by the one F16
-- bind below, sidesteps that: every feature just adds its own key(s) to it.

local M = {}

M.mode = hs.hotkey.modal.new()

-- mods/key: same arguments as hs.hotkey.modal:bind. fn fires once, and the
-- modal exits immediately afterward, same as every other bound key here.
function M.bind(mods, key, fn)
    M.mode:bind(mods, key, function()
        M.mode:exit()
        fn()
    end)
end

hs.hotkey.bind({}, "F16", function() M.mode:enter() end, function() M.mode:exit() end)

return M
