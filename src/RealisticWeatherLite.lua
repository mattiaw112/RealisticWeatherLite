RealisticWeatherLite = {}
RealisticWeatherLite.FACTOR = {
    SNOW_FACTOR = 0.0005,
    SNOW_HEIGHT = 1.0
}

if SnowSystem ~= nil then
    SnowSystem.MAX_HEIGHT = RealisticWeatherLite.FACTOR.SNOW_HEIGHT
end

-- Stato dinamico nebbia e tracciamento notifiche
RealisticWeatherLite.currentFogDensity = 0.0
RealisticWeatherLite.currentHeightDensity = 0.0

RealisticWeatherLite.hasWarnedHail = false
RealisticWeatherLite.hasWarnedSnow = false
RealisticWeatherLite.hasWarnedFog = false
RealisticWeatherLite.blizzardRoll = nil

-------------------------------------------------------------------------------
-- CONTROLLI E IMPOSTAZIONI INTEGRATE (Corretti e sincronizzati)
-------------------------------------------------------------------------------
RealisticWeatherLite.CONTROLS = {
    hailDamage = { id = "hailDamage_enabled", name = "hailDamage_enabled", textKey = "hailDamage_enabled", tooltipKey = "hailDamage_tooltip", value = true },
    weatherNotifications = { id = "notifications_enabled", name = "notifications_enabled", textKey = "notifications_enabled", tooltipKey = "notifications_tooltip", value = true },
    fogControl = { id = "fog_enabled", name = "fog_enabled", textKey = "fog_enabled", tooltipKey = "fog_tooltip", value = true }
}

function RealisticWeatherLite:getModSetting(settingName)
    for _, control in pairs(RealisticWeatherLite.CONTROLS) do
        if control.id == settingName or control.name == settingName then
            return control.value
        end
    end
    return true
end

_G.getModSettings = function(settingName)
    return RealisticWeatherLite:getModSetting(settingName)
end

-------------------------------------------------------------------------------
-- INIEZIONE UI SICURA NEL MENU DI GIOCO
-------------------------------------------------------------------------------
function RealisticWeatherLite:registerSettingsUI()
    if g_inGameMenu == nil or g_inGameMenu.pageSettings == nil then return end

    local settingsPage = g_inGameMenu.pageSettings
    local scrollPanel = settingsPage.gameSettingsLayout or settingsPage.generalSettingsLayout or settingsPage.boxLayout
    if scrollPanel == nil or scrollPanel.elements == nil or RealisticWeatherLite.isUIInitialized then return end

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

    for _, control in pairs(RealisticWeatherLite.CONTROLS) do
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
                        local hail = RealisticWeatherLite:getModSetting("hailDamage_enabled")
                        local notify = RealisticWeatherLite:getModSetting("notifications_enabled")
                        local fog = RealisticWeatherLite:getModSetting("fog_enabled")

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

    RealisticWeatherLite.isUIInitialized = true
    if scrollPanel.invalidateLayout ~= nil then
        scrollPanel:invalidateLayout()
    end
end

InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
    RealisticWeatherLite:registerSettingsUI()
end)

-------------------------------------------------------------------------------
-- FUNZIONI HELPER
-------------------------------------------------------------------------------
function RealisticWeatherLite:getIsSnowing()
    if self.forecast == nil or self.owner == nil then return false end
    local success, _, currentWeather = pcall(function()
        return self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    end)
    if not success or currentWeather == nil then return false end
    return currentWeather.precipitationType == WeatherType.SNOW
end

function RealisticWeatherLite:getSnowFallScale()
    if self.forecast == nil or self.owner == nil then return 1.0 end
    local success, _, currentWeather = pcall(function()
        return self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    end)
    if success and currentWeather ~= nil and currentWeather.precipitationType == WeatherType.SNOW then
        return currentWeather.dropScale or 1.0
    end
    return 1.0
end

function RealisticWeatherLite:getIsRaining()
    if self.forecast == nil or self.owner == nil then return false end
    local success, _, currentWeather = pcall(function()
        return self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    end)
    if not success or currentWeather == nil then return false end
    return currentWeather.precipitationType == WeatherType.RAIN
end

function RealisticWeatherLite:getRainFallScale()
    if self.forecast == nil or self.owner == nil then return 0.0 end
    local success, _, currentWeather = pcall(function()
        return self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    end)
    if success and currentWeather ~= nil and currentWeather.precipitationType == WeatherType.RAIN then
        return currentWeather.dropScale or 1.0
    end
    return 0.0
end

function RealisticWeatherLite:getHailFallScale()
    if self.forecast == nil or self.owner == nil then return 0.0 end
    local success, _, currentWeather = pcall(function()
        return self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    end)
    if success and currentWeather ~= nil then
        local pType = currentWeather.precipitationType or currentWeather.type
        if pType == WeatherType.HAIL or currentWeather.isHail or pType == WeatherType.HAIL then
            return currentWeather.dropScale or currentWeather.precipitationScale or 1.0
        end
    end
    return 0.0
end

function RealisticWeatherLite:showNotification(textKey)
    local areNotificationsEnabled = RealisticWeatherLite:getModSetting("notifications_enabled")
    if areNotificationsEnabled and g_currentMission ~= nil then
        local message = g_i18n:hasText(textKey) and g_i18n:getText(textKey) or textKey
        if g_currentMission.hud ~= nil and g_currentMission.hud.addSideNotification ~= nil then
            g_currentMission.hud:addSideNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, message, nil)
        end
    end
end

-------------------------------------------------------------------------------
-- UPDATE UNICO GENERALE (Neve, Grandine e Nebbia blindati e interattivi)
-------------------------------------------------------------------------------
function RealisticWeatherLite:update(dT)
    if self.temperatureUpdater == nil or self.owner == nil or self.forecast == nil then return end

    local realDt = dT
    local timeScale = 1.0
    pcall(function()
        local ts = g_currentMission:getEffectiveTimeScale()
        if type(ts) == "number" then timeScale = ts end
    end)

    local temperature = 15.0
    pcall(function()
        local tVal = self.temperatureUpdater:getTemperatureAtTime(self.owner.dayTime)
        if type(tVal) == "number" then temperature = tVal end
    end)

    local success, _, currentWeather = pcall(function()
        return self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    end)

    ---------------------------------------------------------------------------
    -- 1. GESTIONE NEVE E BUFERA
    ---------------------------------------------------------------------------
    local isSnowEnabled = false
    pcall(function()
        if g_currentMission and g_currentMission.missionInfo then
            isSnowEnabled = g_currentMission.missionInfo.isSnowEnabled
        end
    end)

    if isSnowEnabled then
        local isSnowing = self:getIsSnowing()
        local isNativeBlizzard = currentWeather ~= nil and currentWeather.isBlizzard
        if isSnowing and isNativeBlizzard and RealisticWeatherLite.blizzardRoll == nil then
            RealisticWeatherLite.blizzardRoll = (math.random(1, 100) <= 15)
        elseif not isSnowing then
            RealisticWeatherLite.blizzardRoll = nil
        end

        self.isBlizzard = isNativeBlizzard and (RealisticWeatherLite.blizzardRoll == true)

        if isSnowing and temperature < 10 then
            if not RealisticWeatherLite.hasWarnedSnow then
                if self.isBlizzard then
                    RealisticWeatherLite:showNotification("rw_blizzard_alert")
                    RealisticWeatherLite.hasWarnedSnow = true
                end
            end

            local blizzardFactor = self.isBlizzard and 25 or 1
            local maxSnowLimit = self.isBlizzard and 1.0 or 0.30
            local scale = 1 - temperature * 0.1

            local snowAdd = RealisticWeatherLite.FACTOR.SNOW_FACTOR * (realDt * timeScale / 30000) * self:getSnowFallScale() * scale * blizzardFactor
            if type(snowAdd) ~= "number" then snowAdd = 0 end

            self.snowHeight = math.clamp(
                self.snowHeight + snowAdd,
                0, 
                maxSnowLimit
            )
        else
            RealisticWeatherLite.hasWarnedSnow = false
            if temperature >= 10 then
                self.snowHeight = 0
                if g_currentMission and g_currentMission.snowSystem then
                    g_currentMission.snowSystem:removeAll()
                end
            elseif temperature > 0 and self.snowHeight > 0 then
                local rainScale = self:getRainFallScale()
                local safeRainScale = (type(rainScale) == "number" and rainScale > 0) and rainScale or 1.0
                local scale = self:getIsRaining() and math.max(5 / safeRainScale, 1.25) or 1
                
                local snowSub = temperature * 0.001 * (realDt * timeScale / 100000) * scale
                if type(snowSub) ~= "number" then snowSub = 0 end

                self.snowHeight = math.clamp(
                    self.snowHeight - snowSub,
                    0, 1.0
                )
                if self.snowHeight == 0 and g_currentMission and g_currentMission.snowSystem then 
                    g_currentMission.snowSystem:removeAll() 
                end
            end
        end
    else
        local snowReduce = 0.005 * (realDt / 1000) * (timeScale / 100)
        if type(snowReduce) ~= "number" then snowReduce = 0 end
        self.snowHeight = math.max(self.snowHeight - snowReduce, 0)
        self.isBlizzard = false
        RealisticWeatherLite.hasWarnedSnow = false
    end

    if g_currentMission ~= nil and g_currentMission.snowSystem ~= nil then
        pcall(function()
            g_currentMission.snowSystem:setSnowHeight(self.snowHeight)
        end)
    end

    ---------------------------------------------------------------------------
    -- 2. GESTIONE GRANDINE E DANNI VEICOLI (Ottimizzata per scala temporale)
    ---------------------------------------------------------------------------
    local isHailDamageEnabled = RealisticWeatherLite:getModSetting("hailDamage_enabled")
    local hailScale = 0.0
    
    pcall(function()
        if currentWeather ~= nil then
            local pType = currentWeather.precipitationType or currentWeather.type
            local pName = currentWeather.name and string.lower(tostring(currentWeather.name)) or ""
            if pType == WeatherType.HAIL or currentWeather.isHail == true or string.find(pName, "hail") or string.find(pName, "grandine") then
                hailScale = currentWeather.dropScale or currentWeather.precipitationScale or 1.0
            end
        end
    end)
    
    if hailScale == 0.0 then
        pcall(function()
            hailScale = self:getHailFallScale()
        end)
    end

    if hailScale == 0.0 and g_currentMission ~= nil and g_currentMission.environment ~= nil and g_currentMission.environment.weather ~= nil then
        pcall(function()
            local envWeather = g_currentMission.environment.weather
            local envType = envWeather.currentPrecipitationType or envWeather.precipitationType
            local envName = envWeather.currentPrecipitationName and string.lower(tostring(envWeather.currentPrecipitationName)) or ""
            if envType == WeatherType.HAIL or envWeather.isHailActive == true or envWeather.isHail == true or string.find(envName, "hail") or string.find(envName, "grandine") then
                hailScale = envWeather.precipitationScale or envWeather.dropScale or 1.0
            end
        end)
    end

    if type(hailScale) ~= "number" then hailScale = 0.0 end

    if hailScale > 0.0 then
        if not RealisticWeatherLite.hasWarnedHail then
            RealisticWeatherLite:showNotification("rw_hail_alert")
            RealisticWeatherLite.hasWarnedHail = true
        end

        if isHailDamageEnabled and g_currentMission ~= nil then
            local indoorMask = g_currentMission.indoorMask
            local vehiclesList = g_currentMission.vehicles
            if vehiclesList == nil and g_currentMission.vehicleSystem ~= nil then
                vehiclesList = g_currentMission.vehicleSystem.vehicles
            end

            if vehiclesList ~= nil then
                for _, vehicle in pairs(vehiclesList) do
                    if vehicle ~= nil then
                        local spec = vehicle.spec_wearable
                        if spec ~= nil then
                            local rootNode = vehicle.rootNode or (vehicle.components and vehicle.components[1] and vehicle.components[1].node)
                            if rootNode ~= nil then
                                local success, x, _, z = pcall(getWorldTranslation, rootNode)
                                
                                local isIndoor = false
                                if success and indoorMask ~= nil and x ~= nil and z ~= nil then
                                    pcall(function()
                                        isIndoor = indoorMask:getIsIndoorAtWorldPosition(x, z)
                                    end)
                                end

                                if not isIndoor then
                                    local wearAmount = hailScale * 0.00035 * (realDt / 1000) * timeScale
                                    local damageAmount = hailScale * 0.00012 * (realDt / 1000) * timeScale

                                    pcall(function()
                                        if spec.addWearAmount ~= nil then
                                            spec:addWearAmount(wearAmount, true)
                                        elseif vehicle.addWearAmount ~= nil then
                                            vehicle:addWearAmount(wearAmount, true)
                                        end

                                        if spec.addDamageAmount ~= nil then
                                            spec:addDamageAmount(damageAmount, true)
                                        elseif vehicle.addDamageAmount ~= nil then
                                            vehicle:addDamageAmount(damageAmount, true)
                                        end
                                    end)
                                end
                            end
                        end
                    end
                end
            end
        end
    else
        RealisticWeatherLite.hasWarnedHail = false
    end

    ---------------------------------------------------------------------------
    -- 3. GESTIONE NEBBIA DINAMICA (Rara, selettiva e blindata)
    ---------------------------------------------------------------------------
    local isFogEnabled = RealisticWeatherLite:getModSetting("fog_enabled")
    local targetGroundDensity = 0.0
    local targetHeightDensity = 0.0

    if isFogEnabled then
        local env = g_currentMission and g_currentMission.environment
        if env ~= nil and env.currentSeason ~= nil and env.currentSeason ~= Season.SUMMER then
            local dayTimeMinutes = 0.0
            pcall(function()
                if env.dayTime and type(env.dayTime) == "number" then
                    dayTimeMinutes = (env.dayTime / 1000 / 60) % 1440
                end
            end)

            local groundWetness = 0.0
            pcall(function()
                if env.weather ~= nil and env.weather.groundWetness ~= nil and type(env.weather.groundWetness) == "number" then
                    groundWetness = env.weather.groundWetness
                end
            end)

            local precipitationScale = 0.0
            local isSnowActive = self:getIsSnowing()
            if isSnowActive then
                precipitationScale = self:getSnowFallScale()
            elseif self:getIsRaining() then
                precipitationScale = self:getRainFallScale()
            end

            local windSpeed = 2.0
            pcall(function()
                if env.weather ~= nil and env.weather.windUpdater ~= nil and env.weather.windUpdater.getCurrentVelocity ~= nil then
                    local wVel = env.weather.windUpdater:getCurrentVelocity()
                    if type(wVel) == "number" then windSpeed = wVel end
                end
            end)

            if type(groundWetness) ~= "number" then groundWetness = 0.0 end
            if type(temperature) ~= "number" then temperature = 15.0 end
            if type(precipitationScale) ~= "number" then precipitationScale = 0.0 end
            if type(windSpeed) ~= "number" then windSpeed = 2.0 end
            if type(dayTimeMinutes) ~= "number" then dayTimeMinutes = 0.0 end

            if RealisticWeatherLite.fogRoll == nil and (groundWetness > 0.4 or precipitationScale > 0 or isSnowActive) then
                RealisticWeatherLite.fogRoll = (math.random(1, 100) <= 25)
            elseif groundWetness <= 0.2 and precipitationScale == 0 and not isSnowActive then
                RealisticWeatherLite.fogRoll = nil
            end

            if RealisticWeatherLite.fogRoll == true then
                local snowBonusNum = isSnowActive and 0.8 or 0.2
                
                if dayTimeMinutes >= 240 and dayTimeMinutes <= 660 then 
                    if temperature <= 6.0 and windSpeed < 5.0 then
                        local tempFactor = math.clamp(1.0 - (temperature / 6.0), 0.2, 1.0)
                        local wetBonus = math.max(groundWetness, snowBonusNum)
                        
                        local peakFactor = (dayTimeMinutes <= 480) and 1.0 or (1.0 - ((dayTimeMinutes - 480) / 180))
                        peakFactor = math.clamp(peakFactor, 0.1, 1.0)

                        targetGroundDensity = math.max(targetGroundDensity, 0.75 * tempFactor * wetBonus * peakFactor)
                        targetHeightDensity = math.max(targetHeightDensity, 0.60 * tempFactor * wetBonus * peakFactor)
                    end
                end

                if (groundWetness > 0.5 or precipitationScale > 0.3 or isSnowActive) then
                    if windSpeed < 4.5 and temperature < 10.0 then
                        local snowMoistureNum = isSnowActive and 0.9 or 0.0
                        local moistureEffect = math.max(precipitationScale, groundWetness * 0.8, snowMoistureNum)
                        targetGroundDensity = math.max(targetGroundDensity, 0.65 * moistureEffect)
                        targetHeightDensity = math.max(targetHeightDensity, 0.50 * moistureEffect)
                    end
                end
            end
        end
    else
        RealisticWeatherLite.fogRoll = nil
    end

    local dtSeconds = 0.016
    pcall(function()
        if dT ~= nil and type(dT) == "number" then
            dtSeconds = dT / 1000.0
        end
    end)

    if type(dtSeconds) ~= "number" then dtSeconds = 0.016 end
    if type(timeScale) ~= "number" then timeScale = 1.0 end

    local smoothSpeed = math.clamp(dtSeconds * 0.08 * math.max(timeScale / 10, 1.0), 0.002, 0.1)

    if type(RealisticWeatherLite.currentFogDensity) ~= "number" then RealisticWeatherLite.currentFogDensity = 0.0 end
    if type(RealisticWeatherLite.currentHeightDensity) ~= "number" then RealisticWeatherLite.currentHeightDensity = 0.0 end

    RealisticWeatherLite.currentFogDensity = RealisticWeatherLite.currentFogDensity + (targetGroundDensity - RealisticWeatherLite.currentFogDensity) * smoothSpeed
    RealisticWeatherLite.currentHeightDensity = RealisticWeatherLite.currentHeightDensity + (targetHeightDensity - RealisticWeatherLite.currentHeightDensity) * smoothSpeed

    if RealisticWeatherLite.currentFogDensity > 0.001 then
        pcall(function()
            if type(setGroundFogGlobalCoverage) == "function" then setGroundFogGlobalCoverage(0.00, 1.00) end
            if type(setGroundFogHeight) == "function" then setGroundFogHeight(50.0) end
            if type(setGroundFogGroundLevelDensity) == "function" then setGroundFogGroundLevelDensity(RealisticWeatherLite.currentFogDensity) end
            if type(setGroundFogMinimumValleyDepth) == "function" then setGroundFogMinimumValleyDepth(0.0) end
            if type(setHeightFogGroundLevelDensity) == "function" then setHeightFogGroundLevelDensity(RealisticWeatherLite.currentHeightDensity) end
            if type(setHeightFogMaxHeight) == "function" then setHeightFogMaxHeight(900.0) end
        end)

        local areNotificationsEnabled = RealisticWeatherLite:getModSetting("notifications_enabled")
        if areNotificationsEnabled and not RealisticWeatherLite.hasWarnedFog and RealisticWeatherLite.currentFogDensity > 0.30 then
            RealisticWeatherLite:showNotification("rw_fog_alert")
            RealisticWeatherLite.hasWarnedFog = true
        end
    else
        RealisticWeatherLite.hasWarnedFog = false
        RealisticWeatherLite.currentFogDensity = 0.0
        RealisticWeatherLite.currentHeightDensity = 0.0
        
        pcall(function()
            if type(setGroundFogGroundLevelDensity) == "function" then setGroundFogGroundLevelDensity(0.0) end
            if type(setHeightFogGroundLevelDensity) == "function" then setHeightFogGroundLevelDensity(0.0) end
        end)
    end
end

if Weather ~= nil and Weather.update ~= nil then
    Weather.update = Utils.appendedFunction(Weather.update, RealisticWeatherLite.update)
end

-------------------------------------------------------------------------------
-- RANDOMIZZAZIONE NEBBIA NATIVA ESTESA (Rara, persistente e protetta)
-------------------------------------------------------------------------------
function RealisticWeatherLite.randomizeFog(self, time)
    if not g_currentMission or not g_currentMission:getIsServer() then return end

    local season = (self.owner and self.owner.currentSeason) or 1
    local seasonToFog = (self.seasonToFog and self.seasonToFog[season]) or nil
    local currentDay = (g_currentMission.environment and g_currentMission.environment.currentMonotonicDay) or 1
    local fog

    self.lastFogDay = self.lastFogDay or 0

    if seasonToFog == nil or currentDay == self.lastFogDay + 1 then
        fog = nil
    else
        local successTemplate, createdFog = pcall(function()
            return seasonToFog:createFromTemplate()
        end)
        
        if successTemplate and createdFog ~= nil then
            fog = createdFog
            
            if season ~= 2 and math.random() >= 0.92 then
                fog.groundFogCoverageEdge0 = math.random(5, 15) / 100
                fog.groundFogCoverageEdge1 = math.random(85, 95) / 100
                fog.groundFogExtraHeight = math.random(20, 40)
                fog.groundFogGroundLevelDensity = math.random(90, 210) / 100
                fog.heightFogMaxHeight = math.random(600, 850)
                fog.heightFogGroundLevelDensity = math.random(80, 200) / 100
                
                if fog.groundFogStartDayTimeMinutes ~= nil then
                    fog.groundFogEndDayTimeMinutes = math.min(math.random(fog.groundFogStartDayTimeMinutes + 180, fog.groundFogStartDayTimeMinutes + 900), 1439)
                end

                if fog.groundFogWeatherTypes ~= nil then
                    for weatherType, _ in pairs(fog.groundFogWeatherTypes) do
                        fog.groundFogWeatherTypes[weatherType] = true
                    end
                end

                self.lastFogDay = currentDay
            end
        end
    end

    if self.fogUpdater and self.fogUpdater.setTargetFog and fog ~= nil then
        pcall(function()
            self.fogUpdater:setTargetFog(fog, time)
        end)
    end
end

if Weather ~= nil and Weather.randomizeFog ~= nil then
    Weather.randomizeFog = Utils.overwrittenFunction(Weather.randomizeFog, RealisticWeatherLite.randomizeFog)
end

-------------------------------------------------------------------------------
-- EVENTO MULTIPLAYER JOIN
-------------------------------------------------------------------------------
if FSBaseMission ~= nil and FSBaseMission.onClientJoined ~= nil then
    FSBaseMission.onClientJoined = Utils.appendedFunction(FSBaseMission.onClientJoined, function(self, connection)
        if g_currentMission ~= nil and g_currentMission:getIsServer() and connection ~= nil then
            local hail = RealisticWeatherLite:getModSetting("hailDamage_enabled")
            local notify = RealisticWeatherLite:getModSetting("notifications_enabled")
            local fog = RealisticWeatherLite:getModSetting("fog_enabled")
            
            if RealisticWeatherLiteEvent ~= nil then
                connection:sendEvent(RealisticWeatherLiteEvent.new(hail, notify, fog))
            end
        end
    end)
end