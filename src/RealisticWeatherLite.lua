-------------------------------------------------------------------------------
-- REALISTIC WEATHER LITE (Corretto e Ottimizzato)
-------------------------------------------------------------------------------
RealisticWeatherLite = {}
RealisticWeatherLite.FACTOR = {
    SNOW_FACTOR = 0.0008, -- Abbassato per accumuli più realistici e variabili
    SNOW_HEIGHT = 0.5     -- Allineato al limite massimo del gioco
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
RealisticWeatherLite.infoBox = nil

-------------------------------------------------------------------------------
-- COMUNICAZIONE IMPOSTAZIONI ESTERNE
-------------------------------------------------------------------------------
function RealisticWeatherLite:getModSetting(settingName)
    --[[ 
    -- CODICE ORIGINALE ESTERNO (Preservato per modifiche e ripristino futuro)
    if g_modSettings and type(g_modSettings.getModSettings) == "function" then
        local val = g_modSettings.getModSettings(settingName)
        if val ~= nil then return val end
    elseif _G.getModSettings ~= nil then
        local val = _G.getModSettings(settingName)
        if val ~= nil then return val end
    end
    return true
    ]]--
    
    -- Fallback temporaneo attivo per non dipendere da file esterni
    return true
end

-------------------------------------------------------------------------------
-- FUNZIONI HELPER (Rese più robuste per evitare falsi negativi sulla neve)
-------------------------------------------------------------------------------
function RealisticWeatherLite:getIsSnowing()
    if self.forecast == nil or self.owner == nil then return false end
    local success, _, currentWeather = pcall(function()
        return self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    end)
    if not success or currentWeather == nil then return false end
    
    local pType = currentWeather.precipitationType or currentWeather.type
    local pName = currentWeather.name and string.lower(tostring(currentWeather.name)) or ""
    if pType == WeatherType.SNOW or currentWeather.isSnow == true or string.find(pName, "snow") or string.find(pName, "neve") then
        return true
    end
    return currentWeather.precipitationType == WeatherType.SNOW
end

function RealisticWeatherLite:getSnowFallScale()
    if self.forecast == nil or self.owner == nil then return 1.0 end
    local success, _, currentWeather = pcall(function()
        return self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    end)
    if success and currentWeather ~= nil then
        local pType = currentWeather.precipitationType or currentWeather.type
        local pName = currentWeather.name and string.lower(tostring(currentWeather.name)) or ""
        if pType == WeatherType.SNOW or currentWeather.isSnow == true or string.find(pName, "snow") or string.find(pName, "neve") then
            return currentWeather.dropScale or currentWeather.precipitationScale or 1.0
        end
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
        local pName = currentWeather.name and string.lower(tostring(currentWeather.name)) or ""
        if pType == WeatherType.HAIL or currentWeather.isHail == true or string.find(pName, "hail") or string.find(pName, "grandine") then
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
-- UPDATE UNICO GENERALE
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
        local blizzardFactor = currentWeather ~= nil and currentWeather.isBlizzard and self.blizzardsEnabled and 10 or 1

        self.isBlizzard = currentWeather ~= nil and currentWeather.isBlizzard and self.blizzardsEnabled

        if isSnowing and temperature < 10 then
            if not RealisticWeatherLite.hasWarnedSnow then
                if self.isBlizzard then
                    RealisticWeatherLite:showNotification("rw_blizzard_alert")
                    RealisticWeatherLite.hasWarnedSnow = true
                end
            end

            local scale = 1 - temperature * 0.1
            local safeTimescale = (type(timeScale) == "number") and timeScale or 1.0
            -- Divisore riportato a 50000 per variare l'altezza in base alla durata della tempesta
            self.snowHeight = math.clamp(self.snowHeight + RealisticWeatherLite.FACTOR.SNOW_FACTOR * (safeTimescale / 50000) * self:getSnowFallScale() * scale * blizzardFactor, 0, RealisticWeatherLite.FACTOR.SNOW_HEIGHT)
        else
            RealisticWeatherLite.hasWarnedSnow = false
            if temperature >= 10 then
                self.snowHeight = 0
                if g_currentMission and g_currentMission.snowSystem then
                    g_currentMission.snowSystem:removeAll()
                end
            elseif temperature > 0 and self.snowHeight > 0 then
                local scale = self:getIsRaining() and math.max(5 / self:getRainFallScale(), 1.25) or 1
                local safeTimescale = (type(timeScale) == "number") and timeScale or 1.0
                self.snowHeight = math.clamp(self.snowHeight - temperature * 0.005 * (safeTimescale / 50000) * scale, 0, RealisticWeatherLite.FACTOR.SNOW_HEIGHT)
                if self.snowHeight == 0 and g_currentMission and g_currentMission.snowSystem then 
                    g_currentMission.snowSystem:removeAll() 
                end
            end
        end
    else
        local safeEffectiveTimescale = (type(timeScale) == "number") and timeScale or 100
        local snowReduce = 0.005 * (dT / 1000) * (safeEffectiveTimescale / 100)
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
    -- 2. GESTIONE GRANDINE E DANNI VEICOLI
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
    -- 3. GESTIONE NEBBIA DINAMICA (Bilanciata: Pioggia & Neve Progressive)
    ---------------------------------------------------------------------------
    local isFogEnabled = RealisticWeatherLite:getModSetting("fog_enabled")
    local targetGroundDensity = 0.0
    local targetHeightDensity = 0.0

    if isFogEnabled then
        local env = g_currentMission and g_currentMission.environment
        if env ~= nil and env.currentSeason ~= nil and env.currentSeason ~= Season.SUMMER then
            
            -- 1. ADATTAMENTO DINAMICO AL CLIMA DELLA MAPPA
            local minMapTemp = 5.0
            local maxMapTemp = 25.0
            pcall(function()
                if self.temperatureUpdater ~= nil then
                    if self.temperatureUpdater.getMinTemperature ~= nil then
                        minMapTemp = self.temperatureUpdater:getMinTemperature() or 5.0
                    end
                    if self.temperatureUpdater.getMaxTemperature ~= nil then
                        maxMapTemp = self.temperatureUpdater:getMaxTemperature() or 25.0
                    end
                end
            end)

            local tempRange = math.max(1.0, maxMapTemp - minMapTemp)
            local morningFogThreshold = minMapTemp + (tempRange * 0.35) + 3.0
            local moistureFogThreshold = minMapTemp + (tempRange * 0.60) + 4.0

            -- 2. LETTURA PARAMETRI AMBIENTALI E METEO NATIVI
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

            groundWetness = math.clamp(type(groundWetness) == "number" and groundWetness or 0.0, 0.0, 1.0)
            temperature = type(temperature) == "number" and temperature or 15.0
            precipitationScale = type(precipitationScale) == "number" and precipitationScale or 0.0
            windSpeed = type(windSpeed) == "number" and windSpeed or 2.0
            dayTimeMinutes = type(dayTimeMinutes) == "number" and dayTimeMinutes or 0.0

            -- 3. CALCOLO DELL'UMIDITÀ GLOBALE
            local humidityIndex = math.clamp(groundWetness * 0.5 + precipitationScale * 0.4 + (isSnowActive and 0.3 or 0.0), 0.0, 1.0)
            local isMorningWindow = (dayTimeMinutes >= 240 and dayTimeMinutes <= 660)

            -- 4. RANDOMIZZATORE ADATTIVO (Sia pioggia che neve passano dal tiro di dadi)
            if RealisticWeatherLite.fogRoll == nil then
                local hasPrecipitation = (precipitationScale > 0.05 or isSnowActive)
                local isGroundWetEnough = (groundWetness > 0.35)
                local isValidMorning = (isMorningWindow and temperature <= morningFogThreshold)

                if hasPrecipitation or isGroundWetEnough or isValidMorning then
                    local rollChance = math.floor(15 + (humidityIndex * 30) + (isValidMorning and 25 or 0))
                    RealisticWeatherLite.fogRoll = (math.random(1, 100) <= rollChance)
                end
            elseif humidityIndex < 0.15 and precipitationScale == 0 and not isSnowActive and not isMorningWindow then
                RealisticWeatherLite.fogRoll = nil
            end

            -- 5. CALCOLO DENSITÀ PROGRESSIVA (Pioggia e neve scalate sull'intensità)
            if RealisticWeatherLite.fogRoll == true then
                local windDissipation = math.clamp(1.0 - (windSpeed / 5.5), 0.0, 1.0)

                if windDissipation > 0 then
                    -- A) NEBBIA MATTUTINA FITTA (04:00 - 11:00)
                    if isMorningWindow and temperature <= morningFogThreshold then
                        local tempFactor = math.clamp(1.0 - (math.max(0, temperature - minMapTemp) / math.max(1, tempRange * 0.35)), 0.25, 1.0)
                        local wetBonus = math.max(humidityIndex, 0.3)
                        local peakFactor = (dayTimeMinutes <= 480) and math.clamp((dayTimeMinutes - 240) / 120, 0.3, 1.0) or math.clamp(1.0 - ((dayTimeMinutes - 480) / 180), 0.1, 1.0)

                        targetGroundDensity = math.max(targetGroundDensity, 0.98 * tempFactor * wetBonus * peakFactor * windDissipation)
                        targetHeightDensity = math.max(targetHeightDensity, 0.90 * tempFactor * wetBonus * peakFactor * windDissipation)
                    end

                    -- B) NEBBIA DA PIOGGIA, NEVE E UMIDITÀ
                    if (humidityIndex > 0.25 or precipitationScale > 0.1 or isSnowActive) and temperature <= moistureFogThreshold then
                        local maxDensity = 0.40 + (groundWetness * 0.30)
                        
                        if isSnowActive then 
                            maxDensity = 0.45 + (precipitationScale * 0.50)
                        end

                        local moistureEffect = math.clamp((precipitationScale * 0.6) + (groundWetness * 0.4), 0.2, 1.0)
                        
                        targetGroundDensity = math.max(targetGroundDensity, maxDensity * moistureEffect * windDissipation)
                        targetHeightDensity = math.max(targetHeightDensity, math.max(0.0, maxDensity - 0.08) * moistureEffect * windDissipation)
                    end
                end
            end
        end
    else
        RealisticWeatherLite.fogRoll = nil
    end

    -- 6. APPLICAZIONE NATIVA E TRANSIZIONE PROPORZIONALE AL TEMPO DI GIOCO
    local dtSeconds = 0.016
    pcall(function()
        if dT ~= nil and type(dT) == "number" then
            dtSeconds = dT / 1000.0
        end
    end)

    if type(dtSeconds) ~= "number" then dtSeconds = 0.016 end
    if type(timeScale) ~= "number" then timeScale = 1.0 end

    local gameSecondsPassed = dtSeconds * math.max(timeScale, 1.0)
    local smoothSpeed = math.clamp(gameSecondsPassed / 180.0, 0.0002, 0.15)

    if type(RealisticWeatherLite.currentFogDensity) ~= "number" then RealisticWeatherLite.currentFogDensity = 0.0 end
    if type(RealisticWeatherLite.currentHeightDensity) ~= "number" then RealisticWeatherLite.currentHeightDensity = 0.0 end

    RealisticWeatherLite.currentFogDensity = RealisticWeatherLite.currentFogDensity + (targetGroundDensity - RealisticWeatherLite.currentFogDensity) * smoothSpeed
    RealisticWeatherLite.currentHeightDensity = RealisticWeatherLite.currentHeightDensity + (targetHeightDensity - RealisticWeatherLite.currentHeightDensity) * smoothSpeed

    if RealisticWeatherLite.currentFogDensity > 0.01 then
        pcall(function()
            if type(setGroundFogGlobalCoverage) == "function" then setGroundFogGlobalCoverage(0.00, 1.00) end
            if type(setGroundFogHeight) == "function" then setGroundFogHeight(120.0) end
            if type(setGroundFogGroundLevelDensity) == "function" then setGroundFogGroundLevelDensity(RealisticWeatherLite.currentFogDensity) end
            if type(setGroundFogMinimumValleyDepth) == "function" then setGroundFogMinimumValleyDepth(0.0) end
            if type(setHeightFogGroundLevelDensity) == "function" then setHeightFogGroundLevelDensity(RealisticWeatherLite.currentHeightDensity) end
            if type(setHeightFogMaxHeight) == "function" then setHeightFogMaxHeight(1200.0) end
        end)

        local areNotificationsEnabled = RealisticWeatherLite:getModSetting("notifications_enabled")
        if areNotificationsEnabled and not RealisticWeatherLite.hasWarnedFog and RealisticWeatherLite.currentFogDensity > 0.30 then
            RealisticWeatherLite:showNotification("rw_fog_alert")
            RealisticWeatherLite.hasWarnedFog = true
        end
    else
        RealisticWeatherLite.hasWarnedFog = false
    end
    ---------------------------------------------------------------------------
     -- 4. AGGIORNAMENTO DATI HUD INFO BOX [Integrazione HUD]
    ---------------------------------------------------------------------------
    if RealisticWeatherLite.infoBox ~= nil then
        RealisticWeatherLite.infoBox:clear()
        
        local snowCm = math.round((self.snowHeight or 0) * 100)
        local fogPercent = math.round((RealisticWeatherLite.currentFogDensity or 0) * 100)
        
        if snowCm > 0 or fogPercent > 0 then
            RealisticWeatherLite.infoBox:setTitle("WEATHER LITE")
            
            if snowCm > 0 then
                local snowTextStr = string.format("%d cm", snowCm)
                RealisticWeatherLite.infoBox:addLine("Altezza Neve:", snowTextStr)
            end
            
            if fogPercent > 0 then
                RealisticWeatherLite.infoBox:addLine("Densità Nebbia:", string.format("%d%%", fogPercent), {1, 1, 1, 1}, false)
            end

            RealisticWeatherLite.infoBox:showNextFrame()
        end
    end
end

if Weather ~= nil and Weather.update ~= nil then
    Weather.update = Utils.appendedFunction(Weather.update, RealisticWeatherLite.update)
end

-------------------------------------------------------------------------------
-- GESTIONE RANDOMIZZAZIONE
-------------------------------------------------------------------------------
function RealisticWeatherLite.randomizeFog(self, time)
end

if Weather ~= nil and Weather.randomizeFog ~= nil then
end