-- Bind Ctrl-` to toggle WezTerm (see toggle_app.lua)
local toggleApp = require("toggle_app")

hs.hotkey.bind({"ctrl"}, "`", function()
    toggleApp.toggle("com.github.wez.wezterm")
end)
