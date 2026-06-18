-- Bind Ctrl-` to toggle WezTerm
hs.hotkey.bind({"ctrl"}, "`", function()
    local appName = "WezTerm" 
    local app = hs.application.find(appName)

    if app then
        if app:isFrontmost() then
            app:hide()
        else
            app:activate()
            local win = app:mainWindow()
            local targetScreen = hs.mouse.getCurrentScreen()
            if win and targetScreen and win:screen() ~= targetScreen then
                win:moveToScreen(targetScreen, true, true, 0)
            end
        end
    end
end)
