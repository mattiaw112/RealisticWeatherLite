WeatherSettings = {}
WeatherSettings.CONTROLS = {}

-- 1. Registrazione impostazioni
addModSettings("hailDamage", "hailDamage_settings", "hailDamage_enabled", true)
addModSettings("weatherNotifications", "weatherNotifications_settings", "notifications_enabled", true)

-- 2. Definizione controlli per il menu
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

-- 3. Hook per iniettare nel menu
FocusManager.setGui = Utils.appendedFunction(FocusManager.setGui, function(_, gui)
    if gui == "ingameMenuSettings" then
        for _, control in pairs(WeatherSettings.CONTROLS) do
            if not control.focusId or not FocusManager.currentFocusData.idToElementMapping[control.focusId] then
                FocusManager:loadElementFromCustomValues(control, nil, nil, false, false)
            end
        end
        local settingsPage = g_gui.screenControllers[InGameMenu].pageSettings
        settingsPage.gameSettingsLayout:invalidateLayout()
    end
end)