-------------------------------------------------------------------------------
-- REALISTIC WEATHER LITE - IMPOSTAZIONI E VALORI INTERNI (UI Ibernata)
-------------------------------------------------------------------------------
RealisticWeatherLiteSettings = {}
local RealisticWeatherLiteSettings_mt = Class(RealisticWeatherLiteSettings)

-- Definiamo qui le etichette, i tooltip e i valori predefiniti di sicurezza
RealisticWeatherLiteSettings.CONTROLS = {
    hailDamage = { 
        id = "hailDamage_enabled", 
        label = "Danni da Grandine", 
        tooltip = "Abilita o disabilita i danni alle colture causati dalla grandine.",
        value = true 
    },
    weatherNotifications = { 
        id = "notifications_enabled", 
        label = "Notifiche Meteo", 
        tooltip = "Abilita o disabilita le notifiche a schermo sui cambiamenti meteo.",
        value = true 
    },
    fogControl = { 
        id = "fog_enabled", 
        label = "Nebbia Dinamica", 
        tooltip = "Abilita o disabilita l'effetto nebbia dinamica nel mondo di gioco.",
        value = true 
    }
}

-------------------------------------------------------------------------------
-- GESTIONE PERSISTENZA XML (Stile Moderno GIANTS / XMLFile)
-------------------------------------------------------------------------------
local SETTINGS_FILE = g_currentModSettingsDirectory .. "FS25_RealisticWeatherLite.xml"

function RealisticWeatherLiteSettings:loadSettings()
    local xmlFile = XMLFile.loadIfExists("RealisticWeatherLiteSettings", SETTINGS_FILE, "RealisticWeatherLite")
    if xmlFile ~= nil then
        for _, control in pairs(self.CONTROLS) do
            local val = xmlFile:getBool("RealisticWeatherLite." .. control.id)
            if val ~= nil then
                control.value = val
            end
        end
        xmlFile:delete()
    else
        self:saveSettings()
    end
end

function RealisticWeatherLiteSettings:saveSettings()
    createFolder(g_currentModSettingsDirectory)
    local xmlFile = XMLFile.create("RealisticWeatherLiteSettings", SETTINGS_FILE, "RealisticWeatherLite")
    if xmlFile ~= nil then
        for _, control in pairs(self.CONTROLS) do
            if control.value ~= nil then
                xmlFile:setBool("RealisticWeatherLite." .. control.id, control.value)
            end
        end
        xmlFile:save()
        xmlFile:delete()
    end
end

RealisticWeatherLiteSettings:loadSettings()

-------------------------------------------------------------------------------
-- GESTIONE VALORI
-------------------------------------------------------------------------------
function RealisticWeatherLiteSettings:getModSetting(settingName)
    for _, control in pairs(RealisticWeatherLiteSettings.CONTROLS) do
        if control.id == settingName then
            return control.value
        end
    end
    return true
end

_G.getModSettings = function(settingName)
    return RealisticWeatherLiteSettings:getModSetting(settingName)
end

function RealisticWeatherLiteSettings:setModSetting(settingName, value)
    for _, control in pairs(RealisticWeatherLiteSettings.CONTROLS) do
        if control.id == settingName then
            control.value = value
            break
        end
    end
    self:saveSettings()
end

-------------------------------------------------------------------------------
-- INTERFACCIA GRAFICA (Ibernata/Commentata - Non mostra più nulla a schermo)
-------------------------------------------------------------------------------
--[[
function RealisticWeatherLiteSettings:registerSettingsUI()
    if g_inGameMenu == nil or g_inGameMenu.pageSettings == nil then return end

    local settingsPage = g_inGameMenu.pageSettings
    local scrollPanel = settingsPage.gameSettingsLayout or settingsPage.generalSettingsLayout or settingsPage.boxLayout
    if scrollPanel == nil or scrollPanel.elements == nil or RealisticWeatherLiteSettings.isUIInitialized then return end

    local sectionHeaderTemplate = nil
    for _, element in pairs(scrollPanel.elements) do
        if element.name == "sectionHeader" or (element.getClassName and element:getClassName() == "SectionHeader") then
            sectionHeaderTemplate = element
            break
        end
    end

    local template = settingsPage.checkWoodHarvesterAutoCutBox 
                  or settingsPage.checkDevelopmentOption 
                  or settingsPage.checkHelpMenuBox
                  or settingsPage.checkBoxTemplate
                  
    if template == nil then return end

    if sectionHeaderTemplate ~= nil then
        local header = sectionHeaderTemplate:clone(scrollPanel)
        if header ~= nil then
            header:setText("Realistic Weather Lite")
            header:setVisible(true)
            header:setDisabled(false)
            scrollPanel:addElement(header)
        end
    end

    for _, control in pairs(RealisticWeatherLiteSettings.CONTROLS) do
        local box = template:clone(scrollPanel)
        if box ~= nil then
            box.id = control.id .. "Box"

            -- Ricerca sicura e isolata per evitare conflitti tra i vari interruttori
            local label = box:getDescendantByName("label") or box.elements[1]
            local menuOption = box:getDescendantByName("multiTextOption") or box:getDescendantByName("checkButton") or box.elements[2] or box

            -- Imposta Etichetta e Tooltip personalizzati
            if label ~= nil and label.setText ~= nil then
                label:setText(control.label)
            elseif box.setLabel ~= nil then
                box:setLabel(control.label)
            end

            if box.setTooltipText ~= nil then
                box:setTooltipText(control.tooltip)
            elseif menuOption.setTooltipText ~= nil then
                menuOption:setTooltipText(control.tooltip)
            end

            -- Imposta lo stato visivo iniziale
            if menuOption.setState ~= nil then
                local currentState = RealisticWeatherLiteSettings:getModSetting(control.id)
                menuOption:setState(currentState and 1 or 2, true)
            end

            -- Callback isolato per singolo interruttore
            if menuOption.setCallback ~= nil then
                menuOption:setCallback("onClickCallback", function(_, state)
                    local newValue = (state == 1)
                    RealisticWeatherLiteSettings:setModSetting(control.id, newValue)
                    
                    if g_currentMission ~= nil and RealisticWeatherLiteEvent ~= nil then
                        RealisticWeatherLiteEvent.sendEvent(
                            RealisticWeatherLiteSettings:getModSetting("hailDamage_enabled"),
                            RealisticWeatherLiteSettings:getModSetting("notifications_enabled"),
                            RealisticWeatherLiteSettings:getModSetting("fog_enabled")
                        )
                    end
                end)
            end

            if FocusManager ~= nil then
                box.focusId = FocusManager:serveAutoFocusId()
            end
            
            box:setVisible(true)
            box:setDisabled(false)
            scrollPanel:addElement(box)
        end
    end

    RealisticWeatherLiteSettings.isUIInitialized = true
    if scrollPanel.invalidateLayout ~= nil then
        scrollPanel:invalidateLayout()
    end
end

if InGameMenuSettingsFrame ~= nil and InGameMenuSettingsFrame.onFrameOpen ~= nil then
    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function(self)
        if not RealisticWeatherLiteSettings.isUIInitialized then
            RealisticWeatherLiteSettings:registerSettingsUI()
        end

        if g_inGameMenu ~= nil and g_inGameMenu.pageSettings ~= nil then
            local settingsPage = g_inGameMenu.pageSettings
            for _, control in pairs(RealisticWeatherLiteSettings.CONTROLS) do
                local box = settingsPage:getDescendantByName(control.id .. "Box")
                if box ~= nil then
                    local menuOption = box:getDescendantByName("multiTextOption") or box:getDescendantByName("checkButton") or box.elements[2] or box
                    if menuOption.setState ~= nil then
                        local currentState = RealisticWeatherLiteSettings:getModSetting(control.id)
                        menuOption:setState(currentState and 1 or 2, true)
                    end
                end
            end
        end
    end)
end
]]--