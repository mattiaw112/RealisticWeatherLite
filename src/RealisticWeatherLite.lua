RealisticWeatherLite = {}
RealisticWeatherLite.FACTOR = {
    SNOW_FACTOR = 0.0005,
    SNOW_HEIGHT = 1.0
}

SnowSystem.MAX_HEIGHT = RealisticWeatherLite.FACTOR.SNOW_HEIGHT

-- Stato dinamico nebbia e tracciamento notifiche
RealisticWeatherLite.currentFogDensity = 0.0
RealisticWeatherLite.currentHeightDensity = 0.0

RealisticWeatherLite.hasWarnedHail = false
RealisticWeatherLite.hasWarnedSnow = false
RealisticWeatherLite.hasWarnedFog = false

-------------------------------------------------------------------------------
-- CONTROLLI E IMPOSTAZIONI INTEGRATE
-------------------------------------------------------------------------------
RealisticWeatherLite.CONTROLS = {
    hailDamage = { id = "hailDamage_enabled", name = "hailDamage_enabled", textKey = "hailDamage_enabled", value = true },
    weatherNotifications = { id = "notifications_enabled", name = "notifications_enabled", textKey = "notifications_enabled", value = true },
    fogControl = { id = "fog_enabled", name = "fog_enabled", textKey = "fog_enabled", value = true }
}

function RealisticWeatherLite:getModSetting(settingName)
    for _, control in pairs(RealisticWeatherLite.CONTROLS) do
        if control.name == settingName then
            return control.value
        end
    end
    return true
end

_G.getModSettings = function(settingName)
    return RealisticWeatherLite:getModSetting(settingName)
end

-------------------------------------------------------------------------------
-- INIEZIONE UI NEL MENU GENERALE
-------------------------------------------------------------------------------
function RealisticWeatherLite:registerSettingsUI()
    if g_gui == nil or g_gui.screenControllers == nil then return end

    local inGameMenu = g_gui.screenControllers[InGameMenu]
    if inGameMenu == nil or inGameMenu.pageSettings == nil then return end

    local settingsPage = inGameMenu.pageSettings
    local layout = settingsPage.generalSettingsLayout or settingsPage.gameSettingsLayout or settingsPage.boxLayout
    if layout == nil or RealisticWeatherLite.isUIInitialized then return end

    local template = settingsPage.checkWoodHarvesterAutoCutBox 
                  or settingsPage.checkDevelopmentOption 
                  or settingsPage.checkHelpMenuBox
                  
    if template == nil then return end

    for _, control in pairs(RealisticWeatherLite.CONTROLS) do
        local box = template:clone(layout)
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

            if menuOption.setState ~= nil then
                menuOption:setState(control.value and 1 or 2)
            end

            if menuOption.setCallback ~= nil then
                menuOption:setCallback("onClickCallback", function(_, state)
                    control.value = (state == 1 or state == true)
                    
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
            
            layout:addElement(box)
        end
    end

    RealisticWeatherLite.isUIInitialized = true
    if layout.invalidateLayout ~= nil then
        layout:invalidateLayout()
    end
end

InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
    RealisticWeatherLite:registerSettingsUI()
end)

-------------------------------------------------------------------------------
-- FUNZIONI HELPER (Forecast FS25)
-------------------------------------------------------------------------------
function RealisticWeatherLite:getIsSnowing()
    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    return currentWeather ~= nil and currentWeather.precipitationType == WeatherType.SNOW
end

function RealisticWeatherLite:getSnowFallScale()
    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    if currentWeather ~= nil and currentWeather.precipitationType == WeatherType.SNOW then
        return currentWeather.dropScale or 1.0
    end
    return 1.0
end

function RealisticWeatherLite:getIsRaining()
    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    return currentWeather ~= nil and currentWeather.precipitationType == WeatherType.RAIN
end

function RealisticWeatherLite:getRainFallScale()
    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    if currentWeather ~= nil and currentWeather.precipitationType == WeatherType.RAIN then
        return currentWeather.dropScale or 1.0
    end
    return 0.0
end

function RealisticWeatherLite:getHailFallScale()
    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    if currentWeather ~= nil and currentWeather.precipitationType == WeatherType.HAIL then
        return currentWeather.dropScale or 1.0
    end
    return 0.0
end

function RealisticWeatherLite:showNotification(textKey)
    local areNotificationsEnabled = RealisticWeatherLite:getModSetting("notifications_enabled")
    if areNotificationsEnabled and g_currentMission ~= nil then
        if g_gui == nil or g_gui.currentGuiName == "" then
            local message = g_i18n:hasText(textKey) and g_i18n:getText(textKey) or textKey
            if g_currentMission.hud ~= nil and g_currentMission.hud.addSideNotification ~= nil then
                g_currentMission.hud:addSideNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, message, nil)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- UPDATE PRINCIPALE (Neve e Danni Grandine)
-------------------------------------------------------------------------------
function RealisticWeatherLite:update(superFunc, dT)
    superFunc(self, dT)

    local timescale = dT * g_currentMission:getEffectiveTimeScale()
    local temperature = self.temperatureUpdater:getTemperatureAtTime(self.owner.dayTime)
    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)

    -- NEVE NORMALE (0.30m) vs BUFERA RARA (1.0m)
    if g_currentMission.missionInfo.isSnowEnabled then
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
                local alertKey = self.isBlizzard and "rw_blizzard_alert" or "rw_snow_alert"
                RealisticWeatherLite:showNotification(alertKey)
                RealisticWeatherLite.hasWarnedSnow = true
            end

            local blizzardFactor = self.isBlizzard and 8 or 1
            local maxSnowLimit = self.isBlizzard and 1.0 or 0.30
            local scale = 1 - temperature * 0.1

            self.snowHeight = math.clamp(
                self.snowHeight + RealisticWeatherLite.FACTOR.SNOW_FACTOR * (timescale / 100000) * self:getSnowFallScale() * scale * blizzardFactor,
                0, 
                maxSnowLimit
            )
        else
            RealisticWeatherLite.hasWarnedSnow = false
            if temperature >= 10 then
                self.snowHeight = 0
                g_currentMission.snowSystem:removeAll()
            elseif temperature > 0 and self.snowHeight > 0 then
                local scale = self:getIsRaining() and math.max(5 / self:getRainFallScale(), 1.25) or 1
                self.snowHeight = math.clamp(
                    self.snowHeight - temperature * 0.001 * (timescale / 100000) * scale,
                    0, 1.0
                )
                if self.snowHeight == 0 then 
                    g_currentMission.snowSystem:removeAll() 
                end
            end
        end
    else
        self.snowHeight = math.max(self.snowHeight - 0.005 * (dT / 1000) * (g_currentMission:getEffectiveTimeScale() / 100), 0)
        self.isBlizzard = false
        RealisticWeatherLite.hasWarnedSnow = false
    end

    g_currentMission.snowSystem:setSnowHeight(self.snowHeight)

    -- GRANDINE E DANNI AI MEZZI
    local isHailDamageEnabled = RealisticWeatherLite:getModSetting("hailDamage_enabled")
    local hail = self:getHailFallScale()

    if hail > 0 then
        if not RealisticWeatherLite.hasWarnedHail then
            RealisticWeatherLite:showNotification("rw_hail_alert")
            RealisticWeatherLite.hasWarnedHail = true
        end

        if isHailDamageEnabled then
            local indoorMask = g_currentMission.indoorMask
            
            local vehiclesList = nil
            if g_currentMission.vehicleSystem ~= nil and g_currentMission.vehicleSystem.getVehicles ~= nil then
                vehiclesList = g_currentMission.vehicleSystem:getVehicles()
            elseif g_currentMission.vehicles ~= nil then
                vehiclesList = g_currentMission.vehicles
            end

            if vehiclesList ~= nil then
                for _, vehicle in pairs(vehiclesList) do
                    local spec = vehicle.spec_wearable
                    if spec ~= nil then
                        local x, _, z = getWorldTranslation(vehicle.rootNode or vehicle.components[1].node)
                        
                        local isIndoor = false
                        if indoorMask ~= nil and x ~= nil and z ~= nil then
                            isIndoor = indoorMask:getIsIndoorAtWorldPosition(x, z)
                        end

                        if not isIndoor then
                            local wearAmount = hail * 0.005 * (timescale / 1000)
                            local damageAmount = hail * 0.002 * (timescale / 1000)

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
                        end
                    end
                end
            end
        end
    else
        RealisticWeatherLite.hasWarnedHail = false
    end
end

Weather.update = Utils.overwrittenFunction(Weather.update, RealisticWeatherLite.update)

-------------------------------------------------------------------------------
-- NEBBIA FISICA DINAMICA (Basata su Umidità e Condizioni del Gioco Base)
-------------------------------------------------------------------------------
FogUpdater.update = Utils.appendedFunction(FogUpdater.update, function(self, dt)
    local isFogEnabled = RealisticWeatherLite:getModSetting("fog_enabled")
    if not isFogEnabled then return end

    local env = g_currentMission and g_currentMission.environment
    if env == nil or env.weather == nil then return end

    local dayTimeMinutes = (env.dayTime / 1000 / 60) % 1440
    local season = env.currentSeason

    -- Leggiamo i parametri fisici direttamente dal gioco base
    local groundWetness = env.weather.groundWetness or 0.0
    local rainScale = env.weather:getRainFallScale()
    local windSpeed = (env.weather.windUpdater ~= nil and env.weather.windUpdater.getCurrentVelocity ~= nil) and env.weather.windUpdater:getCurrentVelocity() or 2.0

    local targetGroundDensity = 0.0
    local targetHeightDensity = 0.0

    -- 1. NEBBIA MATTUTINA BASATA SULL'UMIDITÀ E STAGIONE (Autunno/Inverno)
    -- Si forma la mattina presto (05:00 - 09:00) se il terreno è umido/bagnato e non c'è vento forte
    if season == Season.WINTER or season == Season.AUTUMN then
        if dayTimeMinutes >= 300 and dayTimeMinutes <= 540 then
            if groundWetness > 0.25 and windSpeed < 4.0 then
                local factor = (dayTimeMinutes <= 420) and ((dayTimeMinutes - 300) / 120) or (1.0 - ((dayTimeMinutes - 420) / 120))
                -- L'intensità scala in base a quanto è bagnato il terreno
                local intensityMultiplier = math.clamp(groundWetness * 1.2, 0.4, 1.0)
                
                targetGroundDensity = math.max(targetGroundDensity, 0.80 * factor * intensityMultiplier)
                targetHeightDensity = math.max(targetHeightDensity, 0.65 * factor * intensityMultiplier)
            end
        end
    end

    -- 2. NEBBIA DA EVAPORAZIONE POST-PIOGGIA O DURANTE LA PIOGGIA
    -- Si attiva se piove o se ha appena piovuto e il terreno è saturo con aria calma
    if rainScale > 0 or groundWetness > 0.6 then
        if windSpeed < 5.0 then
            local moistureEffect = math.max(rainScale, groundWetness * 0.7)
            targetGroundDensity = math.max(targetGroundDensity, 0.60 * moistureEffect)
            targetHeightDensity = math.max(targetHeightDensity, 0.45 * moistureEffect)
        end
    end

    -- 3. TRANSIZIONE MORBIDA E FLUIDA (SMOOTH LERP)
    local dtSeconds = dt / 1000.0
    local timeScale = g_currentMission:getEffectiveTimeScale() or 1.0
    local smoothSpeed = math.clamp(dtSeconds * 0.04 * math.max(timeScale / 10, 1.0), 0.001, 0.06)

    RealisticWeatherLite.currentFogDensity = RealisticWeatherLite.currentFogDensity + (targetGroundDensity - RealisticWeatherLite.currentFogDensity) * smoothSpeed
    RealisticWeatherLite.currentHeightDensity = RealisticWeatherLite.currentHeightDensity + (targetHeightDensity - RealisticWeatherLite.currentHeightDensity) * smoothSpeed

    -- 4. APPLICAZIONE VISIVA O RESET DI SICUREZZA CONTRO IL BLOCCO
    if RealisticWeatherLite.currentFogDensity > 0.005 then
        setGroundFogGlobalCoverage(0.00, 1.00)
        setGroundFogHeight(50.0)
        setGroundFogGroundLevelDensity(RealisticWeatherLite.currentFogDensity)
        setGroundFogMinimumValleyDepth(0.0)
        setHeightFogGroundLevelDensity(RealisticWeatherLite.currentHeightDensity)
        setHeightFogMaxHeight(900.0)

        if not RealisticWeatherLite.hasWarnedFog and RealisticWeatherLite.currentFogDensity > 0.30 then
            RealisticWeatherLite:showNotification("rw_fog_alert")
            RealisticWeatherLite.hasWarnedFog = true
        end
    else
        -- Quando la nebbia scende sotto la soglia, azzeriamo completamente i flag per evitare residui nei mesi successivi
        RealisticWeatherLite.hasWarnedFog = false
        RealisticWeatherLite.currentFogDensity = 0.0
        RealisticWeatherLite.currentHeightDensity = 0.0
    end
end)

-------------------------------------------------------------------------------
-- EVENTO MULTIPLAYER JOIN
-------------------------------------------------------------------------------
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