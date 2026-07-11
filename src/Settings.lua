if settings == nil then
    settings = {}
end

settings.CONTROLS = {
    hailDamage = {
        name = "hailDamage_enabled",
        title = g_i18n:getText("hailDamage_enabled"), -- Richiama la traduzione da modDesc
        value = true
    },
    weatherNotifications = {
        name = "notifications_enabled",
        title = g_i18n:getText("notifications_enabled"), -- Richiama la traduzione da modDesc
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
    -- Verifica che il menu di gioco sia pronto
    if g_gui == nil or g_gui.screenControllers == nil or g_gui.screenControllers[InGameMenu] == nil then 
        return 
    end

    local settingsPage = g_gui.screenControllers[InGameMenu].pageSettings
    if settingsPage == nil or settingsPage.gameSettingsLayout == nil then 
        return 
    end

    -- Se abbiamo già inserito le opzioni, evita duplicati
    if settings.isUIInitialized then return end

    local layout = settingsPage.gameSettingsLayout

    -- Creiamo gli elementi grafici (Sì/No) per le nostre opzioni
    for _, control in pairs(settings.CONTROLS) do
        if settingsPage.checkDevelopmentOption ~= nil then
            pcall(function()
                local newElement = settingsPage.checkDevelopmentOption:clone(layout)
                if newElement ~= nil then
                    -- Impostiamo il testo visibile a schermo nel menu
                    if newElement.setLabel ~= nil then
                        newElement:setLabel(control.title)
                    end
                    
                    -- Gestiamo l'evento di cambio stato (Sì/No) con sincronizzazione di rete
                    newElement:setCallback("onClickCallback", function(_, state)
                        control.value = (state == 1 or state == true)
                        print(string.format("[settings.lua] Opzione '%s' impostata a: %s", control.name, tostring(control.value)))

                        -- 🌐 INGRESSO LOGICA RETE MULTIPLAYER:
                        if g_currentMission ~= nil then
                            local hail = _G.getModSettings("hailDamage_enabled")
                            local notify = _G.getModSettings("notifications_enabled")
                            
                            if g_server ~= nil then
                                -- Se siamo l'host, eseguiamo il broadcast a tutti i client connessi
                                g_server:broadcastEvent(RealisticWeatherLiteEvent.new(hail, notify))
                            elseif g_client ~= nil then
                                -- Se siamo un client Admin, inviamo l'evento al server affinché lo distribuisca
                                g_client:getServerConnection():sendEvent(RealisticWeatherLiteEvent.new(hail, notify))
                            end
                        end
                    end)

                    -- Impostiamo lo stato iniziale corretto
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
    -- Quando la schermata delle impostazioni si apre, genera i nostri menu custom
    if InGameMenuSettings ~= nil and InGameMenuSettings.onFrameOpen ~= nil then
        InGameMenuSettings.onFrameOpen = Utils.appendedFunction(InGameMenuSettings.onFrameOpen, function(self)
            settings:registerSettings()
        end)
    end
end

-- Hook di attivazione a caricamento mappa completato
FSBaseMission.onLoadMapFinished = Utils.appendedFunction(FSBaseMission.onLoadMapFinished, oofOnLoadMapFinished)

-- 🌐 SINCRONIZZAZIONE AUTOMATICA ALL'INGRESSO DEI GIOCATORI:
-- Quando un client entra nel server, l'host gli invia immediatamente le impostazioni correnti
FSBaseMission.onClientJoined = Utils.appendedFunction(FSBaseMission.onClientJoined, function(self, connection)
    if g_currentMission:getIsServer() and connection ~= nil then
        local hail = _G.getModSettings("hailDamage_enabled")
        local notify = _G.getModSettings("notifications_enabled")
        
        connection:sendEvent(RealisticWeatherLiteEvent.new(hail, notify))
    end
end)

print("--- [settings.lua] Struttura FS25 e Logica Multiplayer Pronta ---")