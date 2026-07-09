if addModSettings == nil then
    _G.addModSettings = function(name, group, key, default) end
end

WeatherSettings = {}
WeatherSettings.CONTROLS = {}

WeatherSettings.CONTROLS.hailDamage = {
    id = "hailDamageEnabled",
    name = "hailDamage_enabled",
    type = "bool",
    title = "Abilita Danni Grandine",
    value = true
}

WeatherSettings.CONTROLS.weatherNotifications = {
    id = "notificationsEnabled",
    name = "notifications_enabled",
    type = "bool",
    title = "Abilita Notifiche Meteo",
    value = true
}

if FocusManager ~= nil then
    FocusManager.setGui = Utils.appendedFunction(FocusManager.setGui, function(_, gui)
        if gui == "ingameMenuSettings" then
            if g_gui ~= nil and g_gui.screenControllers ~= nil and g_gui.screenControllers[InGameMenu] ~= nil then
                local settingsPage = g_gui.screenControllers[InGameMenu].pageSettings
                if settingsPage ~= nil and settingsPage.gameSettingsLayout ~= nil then
                    for _, control in pairs(WeatherSettings.CONTROLS) do
                        if control.id and (not control.focusId or not FocusManager.currentFocusData.idToElementMapping[control.focusId]) then
                            pcall(function() FocusManager:loadElementFromCustomValues(control, nil, nil, false, false) end)
                        end
                    end
                    settingsPage.gameSettingsLayout:invalidateLayout()
                end
            end
        end
    end)
end

_G.getModSettings = function(settingName)
    if WeatherSettings.CONTROLS ~= nil then
        for _, control in pairs(WeatherSettings.CONTROLS) do
            if control.name == settingName then
                return control.value
            end
        end
    end
    return true
end

print("--- [WeatherSettings] Caricato con protezione attiva ---")