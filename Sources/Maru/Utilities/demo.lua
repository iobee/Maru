-- Window management configuration

-- Constants
local DEBOUNCE_TIME = 0.1

-- Application groups
local messageApps = {
    WeChat = true,
    Messages = true,
    Telegram = true,
    WhatsApp = true,
    Slack = true,
    Discord = true,
    ["System Settings"] = true
}

-- Window management function
local function manageWindow(window)
    if not window then return end
    
    local app = window:application()
    if not app then return end
    
    local appName = app:name()
    if not appName then return end
    
    -- Skip certain applications
    if appName == "HiTranslator" or appName == "Raycast" or appName == "iPhone Mirroring" or appName == "Electron" then
        print(string.format("[Hammerspoon] Skipping application: %s", appName))
        return
    end
    
    -- Execute command
    if messageApps[appName] then
        print(string.format("[Hammerspoon] Managing message app: %s (center)", appName))
        hs.task.new("/usr/bin/open", nil, { "-g", "raycast://extensions/raycast/window-management/center" }):start()
    else
        print(string.format("[Hammerspoon] Managing other app: %s (almost-maximize)", appName))
        hs.task.new("/usr/bin/open", nil, { "-g", "raycast://extensions/raycast/window-management/almost-maximize" }):start()
    end
end

-- Debounce function
local function debounce(func, wait)
    local timer = nil
    return function(window)
        if timer then timer:stop() end
        timer = hs.timer.doAfter(wait, function()
            func(window)
            timer = nil
        end)
    end
end

-- Initialize
local windowFilter = hs.window.filter.new()
windowFilter:subscribe(hs.window.filter.windowFocused, debounce(manageWindow, DEBOUNCE_TIME))

hs.alert.show("Hammerspoon config loaded")