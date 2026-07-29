-------------------------------------------------------------------------------
-- REALISTIC WEATHER LITE - IMPOSTAZIONI E UI SEPARATE
-------------------------------------------------------------------------------
RealisticWeatherLiteSettings = {}
local RealisticWeatherLiteSettings_mt = Class(RealisticWeatherLiteSettings)

RealisticWeatherLiteSettings.CONTROLS = {
    hailDamage = { id = "hailDamage_enabled", name = "hailDamage_enabled", textKey = "hailDamage_enabled", tooltipKey = "hailDamage_tooltip", value = true },
    weatherNotifications = { id = "notifications_enabled", name = "notifications_enabled", textKey = "notifications_enabled", tooltipKey = "notifications_tooltip", value = true },
    fogControl = { id = "fog_enabled", name = "fog_enabled", textKey = "fog_enabled", tooltipKey = "fog_tooltip", value = true }
}

function RealisticWeatherLiteSettings:getModSetting(settingName)
    for _, control in pairs(RealisticWeatherLiteSettings.CONTROLS) do
        if control.id == settingName or control.name == settingName then
            return control.value
        end
    end
    return true
end

-- Esposizione globale per far leggere i dati allo script principale
_G.getModSettings = function(settingName)
    return RealisticWeatherLiteSettings:getModSetting(settingName)
end

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

            local menuOption = box.elements[1] or box
            local label = box.elements[2]

            local titleText = g_i18n:hasText(control.textKey) and g_i18n:getText(control.textKey) or control.name
            
            if label ~= nil and label.setText ~= nil then
                label:setText(titleText)
            elseif box.setLabel ~= nil then
                box:setLabel(titleText)
            end

            local tooltipText = g_i18n:hasText(control.tooltipKey) and g_i18n:getText(control.tooltipKey) or titleText
            if box.setTooltipText ~= nil then
                box:setTooltipText(tooltipText)
            elseif menuOption.setTooltipText ~= nil then
                menuOption:setTooltipText(tooltipText)
            elseif box.tooltip ~= nil then
                box.tooltip = tooltipText
            elseif menuOption.tooltip ~= nil then
                menuOption.tooltip = tooltipText
            end

            if menuOption.setState ~= nil then
                local initialState = control.value and 1 or 2
                menuOption:setState(initialState, true)
            end

            if menuOption.setCallback ~= nil then
                menuOption:setCallback("onClickCallback", function(_, state)
                    control.value = (state == 1)
                    
                    if g_currentMission ~= nil and RealisticWeatherLiteEvent ~= nil then
                        local hail = RealisticWeatherLiteSettings:getModSetting("hailDamage_enabled")
                        local notify = RealisticWeatherLiteSettings:getModSetting("notifications_enabled")
                        local fog = RealisticWeatherLiteSettings:getModSetting("fog_enabled")

                        RealisticWeatherLiteEvent.sendEvent(hail, notify, fog)
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

InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
    RealisticWeatherLiteSettings:registerSettingsUI()
end)

-------------------------------------------------------------------------------
-- EVENTO MULTIPLAYER JOIN
-------------------------------------------------------------------------------
if FSBaseMission ~= nil and FSBaseMission.onClientJoined ~= nil then
    FSBaseMission.onClientJoined = Utils.appendedFunction(FSBaseMission.onClientJoined, function(self, connection)
        if g_currentMission ~= nil and g_currentMission:getIsServer() and connection ~= nil then
            local hail = RealisticWeatherLiteSettings:getModSetting("hailDamage_enabled")
            local notify = RealisticWeatherLiteSettings:getModSetting("notifications_enabled")
            local fog = RealisticWeatherLiteSettings:getModSetting("fog_enabled")
            
            if RealisticWeatherLiteEvent ~= nil then
                connection:sendEvent(RealisticWeatherLiteEvent.new(hail, notify, fog))
            end
        end
    end)
end