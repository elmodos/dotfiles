-- Remap CapsLock -> F13, then use F13 to cycle input languages.

-- 1) Remap CapsLock (0x700000039) to F13 (0x700000068) via hidutil.
--    hidutil mappings don't persist across reboots, so we (re)apply on load.
local remap = [[hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x700000068}]}']]
hs.execute(remap)

-- 2) Handle F13 -> switch to next input language.
--    Layouts are discovered at runtime via hs.keycodes.layouts(), so the same
--    config works on every machine regardless of which layouts are enabled.
--    (Covers keyboard layouts; full IMEs like Chinese/Japanese are not listed here.)
local function nextLayout()
    local layouts = hs.keycodes.layouts()
    if #layouts < 2 then return end

    local current = hs.keycodes.currentLayout()
    local idx = 1
    for i, name in ipairs(layouts) do
        if name == current then
            idx = i
            break
        end
    end
    hs.keycodes.setLayout(layouts[(idx % #layouts) + 1])
end

hs.hotkey.bind({}, "F13", nextLayout)
