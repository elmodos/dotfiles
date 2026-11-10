-- Bind Ctrl-Shift-` (~) to toggle Claude.app (see toggle_app.lua)
local toggleApp = require("toggle_app")

hs.hotkey.bind({"ctrl", "shift"}, "`", function()
    toggleApp.toggle("com.anthropic.claudefordesktop")
end)
