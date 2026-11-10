-- F13 (remapped from Caps Lock -- see key_remap.lua) cycles input languages.
--
-- Layouts are discovered at runtime via hs.keycodes.layouts(), so the same
-- config works on every machine regardless of which layouts are enabled.
-- (Covers keyboard layouts; full IMEs like Chinese/Japanese are not listed here.)
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
