if settings == nil then
    settings = {}
end

-- Salviamo le chiavi di localizzazione invece di chiamare subito g_i18n
settings.CONTROLS = {
    hailDamage = {
        name = "hailDamage_enabled",
        textKey = "hailDamage_enabled",
        value = true
    },
    weatherNotifications = {
        name = "notifications_enabled",
        textKey = "notifications_enabled",
        value = true
    }
}

-------------------------------------------------------------------------------
-- FUNZIONE GLOBALE DI LETTURA DELLE IMPOSTAZIONI
-------------------------------------------------------------------------------
_G.getModSettings = function(settingName)
    if settings.CONTROLS ~= nil then
        for _, control in pairs(settings.CONTROLS) do
            if control.name == settingName then
                return control.value
            end
        end
    end
    return true
end

-------------------------------------------------------------------------------
-- INIEZIONE GRAFICA NEL MENU DEL GIOCO (METODO FS25)
-------------------------------------------------------------------------------
function settings:registerSettings()
    -- Verifica che il menu di gioco e la GUI siano pronti
    if g_gui == nil or g_gui.screenControllers == nil then 
        return 
    end

    local inGameMenu = g_gui.screenControllers[InGameMenu]
    if inGameMenu == nil or inGameMenu.pageSettings == nil then 
        return 
    end

    local settingsPage = inGameMenu.pageSettings
    if settingsPage.gameSettingsLayout == nil then 
        return 
    end

    -- Evita di reinserire gli elementi più volte
    if settings.isUIInitialized then return end

    local layout = settingsPage.gameSettingsLayout

    -- Creiamo gli elementi grafici (Sì/No) per le opzioni
    for _, control in pairs(settings.CONTROLS) do
        if settingsPage.checkDevelopmentOption ~= nil then
            pcall(function()
                local newElement = settingsPage.checkDevelopmentOption:clone(layout)
                if newElement ~= nil then
                    -- Recuperiamo il testo tradotto in modo sicuro in questo momento
                    local titleText = g_i18n:hasText(control.textKey) and g_i18n:getText(control.textKey) or control.name
                    
                    if newElement.setLabel ~= nil then
                        newElement:setLabel(titleText)
                    end
                    
                    -- Gestione dell'evento di cambio stato (Sì/No)
                    newElement:setCallback("onClickCallback", function(_, state)
                        control.value = (state == 1 or state == true)
                        print(string.format("[settings.lua] Opzione '%s' impostata a: %s", control.name, tostring(control.value)))

                        -- Sincronizzazione Multiplayer
                        if g_currentMission ~= nil then
                            local hail = _G.getModSettings("hailDamage_enabled")
                            local notify = _G.getModSettings("notifications_enabled")
                            
                            if g_server ~= nil and RealisticWeatherLiteEvent ~= nil then
                                g_server:broadcastEvent(RealisticWeatherLiteEvent.new(hail, notify))
                            elseif g_client ~= nil and RealisticWeatherLiteEvent ~= nil then
                                g_client:getServerConnection():sendEvent(RealisticWeatherLiteEvent.new(hail, notify))
                            end
                        end
                    end)

                    -- Impostazione dello stato iniziale
                    if newElement.setIsChecked ~= nil then
                        newElement:setIsChecked(control.value)
                    elseif newElement.setState ~= nil then
                        newElement:setState(control.value and 1 or 2)
                    end
                    
                    layout:addElement(newElement)
                end
            end)
        end
    end

    settings.isUIInitialized = true
    if layout.invalidateLayout ~= nil then
        layout:invalidateLayout()
    end
    print("[settings.lua] Menu impostazioni RealisticWeatherLite inserito con successo!")
end

-------------------------------------------------------------------------------
-- INIZIALIZZAZIONE AL CARICAMENTO DELLA MAPPA E SINCRONIZZAZIONE ENTRATA
-------------------------------------------------------------------------------
local function oofOnLoadMapFinished()
    if InGameMenuSettings ~= nil and InGameMenuSettings.onFrameOpen ~= nil then
        InGameMenuSettings.onFrameOpen = Utils.appendedFunction(InGameMenuSettings.onFrameOpen, function(self)
            settings:registerSettings()
        end)
    end
end

-- Hook di attivazione a caricamento mappa completato
FSBaseMission.onLoadMapFinished = Utils.appendedFunction(FSBaseMission.onLoadMapFinished, oofOnLoadMapFinished)

-- Sincronizzazione automatica all'ingresso dei giocatori in Multiplayer
FSBaseMission.onClientJoined = Utils.appendedFunction(FSBaseMission.onClientJoined, function(self, connection)
    if g_currentMission ~= nil and g_currentMission:getIsServer() and connection ~= nil then
        local hail = _G.getModSettings("hailDamage_enabled")
        local notify = _G.getModSettings("notifications_enabled")
        
        if RealisticWeatherLiteEvent ~= nil then
            connection:sendEvent(RealisticWeatherLiteEvent.new(hail, notify))
        end
    end
end)

print("--- [settings.lua] Struttura FS25 e Logica Multiplayer Pronta ---")