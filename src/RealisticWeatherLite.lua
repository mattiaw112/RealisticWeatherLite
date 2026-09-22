-------------------------------------------------------------------------------
-- REALISTIC WEATHER LITE (Corretto e Ottimizzato)
-------------------------------------------------------------------------------
RealisticWeatherLite = {}
RealisticWeatherLite.FACTOR = {
    SNOW_FACTOR = 0.0008, -- Abbassato per accumuli più realistici e variabili
    SNOW_HEIGHT = 1.0     -- Allineato al limite massimo del gioco
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
    if g_modSettings and type(g_modSettings.getModSettings) == "function" then
        local val = g_modSettings.getModSettings(settingName)
        if val ~= nil then return val end
    elseif _G.getModSettings ~= nil then
        local val = _G.getModSettings(settingName)
        if val ~= nil then return val end
    end
    
    -- Fallback se l'impostazione non è ancora definita nel file esterno
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
    -- 1. GESTIONE NEVE E BUFERA (Iper-Realistica & Cap Dinamico 0.5m / 1.0m)
    ---------------------------------------------------------------------------
    local isSnowEnabled = false
    pcall(function()
        if g_currentMission and g_currentMission.missionInfo then
            isSnowEnabled = g_currentMission.missionInfo.isSnowEnabled
        end
    end)

    if isSnowEnabled then
        local isSnowing = self:getIsSnowing()
        local snowFallScale = self:getSnowFallScale()
        
        -- Lettura dinamica della velocità del vento
        local windSpeed = 2.0
        pcall(function()
            if g_currentMission.environment and g_currentMission.environment.weather and g_currentMission.environment.weather.windUpdater then
                local wVel = g_currentMission.environment.weather.windUpdater:getCurrentVelocity()
                if type(wVel) == "number" then windSpeed = wVel end
            end
        end)

        -- Calcolo avanzato della Bufera Dinamica
        -- Innesco: Temperatura <= -1.0°C, Vento > 7.0 m/s, Intensità Precipitazione > 0.6
        local isDynamicBlizzard = false
        if isSnowing and temperature <= -1.0 and windSpeed > 7.0 and snowFallScale > 0.6 then
            if RealisticWeatherLite.blizzardRoll == nil then
                local blizzardChance = 10 + ((windSpeed - 7.0) * 3.5) + ((snowFallScale - 0.6) * 45)
                RealisticWeatherLite.blizzardRoll = (math.random(1, 100) <= blizzardChance)
            end
            isDynamicBlizzard = RealisticWeatherLite.blizzardRoll
        else
            RealisticWeatherLite.blizzardRoll = nil -- Resetta il roll se le condizioni meteo calano
        end

        local gameIsBlizzard = currentWeather ~= nil and currentWeather.isBlizzard and self.blizzardsEnabled
        self.isBlizzard = gameIsBlizzard or isDynamicBlizzard
        
        -- Moltiplicatore della bufera (da 5x a 12x sulla velocità di accumulo)
        local blizzardFactor = self.isBlizzard and (math.random(50, 120) / 10.0) or 1.0 

        -- CAP DINAMICO DELL'ALTEZZA:
        -- Nevicata normale = cap a 0.50m (50 cm)
        -- Bufera attiva = sblocco limite fino a 1.00m (100 cm)
        local maxAllowedHeight = self.isBlizzard and 1.00 or 0.50

        if isSnowing and temperature < 10 then
            if not RealisticWeatherLite.hasWarnedSnow then
                if self.isBlizzard then
                    RealisticWeatherLite:showNotification("rw_blizzard_alert")
                    RealisticWeatherLite.hasWarnedSnow = true
                end
            end

            -- Fisica della densità in base alla temperatura (Wet/Dry Snow)
            local tempAccumulationMultiplier = 1.0
            if temperature >= -1.5 and temperature <= 1.0 then
                -- Neve bagnata/pesante: alta aderenza, accumulo rapido (+35%)
                tempAccumulationMultiplier = 1.35 
            elseif temperature < -6.0 then
                -- Neve secca/farinosa: spazzata via dal vento (-15%)
                tempAccumulationMultiplier = 0.85 
            end

            -- Curva esponenziale dell'intensità (nevicate deboli faticano ad attecchire)
            local intensityMultiplier = math.pow(snowFallScale, 1.6)

            local scale = math.max(0.1, 1 - temperature * 0.1)
            local safeTimescale = (type(timeScale) == "number") and timeScale or 1.0
            
            -- Incremento dell'altezza neve
            local addedSnow = RealisticWeatherLite.FACTOR.SNOW_FACTOR * (safeTimescale / 50000) * intensityMultiplier * scale * blizzardFactor * tempAccumulationMultiplier
            
            -- Clamping con limite dinamico (0.50m o 1.00m)
            self.snowHeight = math.clamp(self.snowHeight + addedSnow, 0, maxAllowedHeight)
        else
            RealisticWeatherLite.hasWarnedSnow = false
            if temperature >= 10 then
                self.snowHeight = 0
                if g_currentMission and g_currentMission.snowSystem then
                    g_currentMission.snowSystem:removeAll()
                end
            elseif temperature > 0 and self.snowHeight > 0 then
                -- Scioglimento dinamico (accelerato se piove contemporaneamente)
                local scale = self:getIsRaining() and math.max(5 / self:getRainFallScale(), 1.25) or 1
                local safeTimescale = (type(timeScale) == "number") and timeScale or 1.0
                self.snowHeight = math.clamp(self.snowHeight - temperature * 0.005 * (safeTimescale / 50000) * scale, 0, maxAllowedHeight)
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
    -- 2. GESTIONE GRANDINE E DANNI VEICOLI (Logica Intelligente e Bilanciata)
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
                -- 1. Smorzamento adattivo del TimeScale (Scalabilità fluida da 1x fino a 360x)
                local deltaMs = realDt or dt or 16.66
                local dtSec = (deltaMs / 1000)
                local currentScale = (g_currentMission.missionInfo and g_currentMission.missionInfo.timeScale) or timeScale or 1.0
                
                local effectiveTimeScale = currentScale
                if effectiveTimeScale > 15.0 then
                    effectiveTimeScale = 15.0 + math.sqrt(effectiveTimeScale - 15.0) * 1.5
                end
                
                local inGameSeconds = dtSec * effectiveTimeScale

                -- 2. TASSI AUMENTATI (5x più veloci a velocità normali)
                local baseWearRate = 0.0009 * hailScale * inGameSeconds     -- Usura vernice rapida
                local baseDamageRate = 0.00018 * hailScale * inGameSeconds  -- Danno meccanico tangibile

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
                                    -- 3. Differenziazione per tipologia di veicolo
                                    local typeMultiplier = 1.0
                                    if vehicle.spec_combine ~= nil or vehicle.spec_cutter ~= nil then
                                        typeMultiplier = 1.3 -- Mietitrebbie e barre da taglio (+30%)
                                    elseif vehicle.spec_motorized ~= nil then
                                        typeMultiplier = 1.07 -- Trattori (standard)
                                    elseif vehicle.spec_attachable ~= nil then
                                        typeMultiplier = 0.7 -- Attrezzi/Rimorchi (-30%)
                                    end

                                    -- 4. Resistenza e Cap massimo per tick aumentati
                                    local currentWear = spec.wearAmount or 0.0
                                    local currentDamage = spec.damageAmount or 0.0

                                    local wearMultiplier = math.clamp(1.0 - (currentWear * 0.3), 0.3, 1.0) * typeMultiplier
                                    local damageMultiplier = math.clamp(1.0 - currentDamage, 0.2, 1.0) * typeMultiplier

                                    -- Limiti per frame alzati per permettere accumuli più rapidi
                                    local finalWear = math.clamp(baseWearRate * wearMultiplier, 0.0, 0.025)
                                    local finalDamage = math.clamp(baseDamageRate * damageMultiplier, 0.0, 0.008)

                                    pcall(function()
                                        if spec.addWearAmount ~= nil then
                                            spec:addWearAmount(finalWear, true)
                                        elseif vehicle.addWearAmount ~= nil then
                                            vehicle:addWearAmount(finalWear, true)
                                        end

                                        if spec.addDamageAmount ~= nil then
                                            spec:addDamageAmount(finalDamage, true)
                                        elseif vehicle.addDamageAmount ~= nil then
                                            vehicle:addDamageAmount(finalDamage, true)
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
    -- 3. GESTIONE NEBBIA DINAMICA (Bilanciata, Map Temp, Dew Point & Seed)
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

            -- 3. CALCOLO DELL'UMIDITÀ GLOBALE & DEW POINT DINAMICO
            local isMorningWindow = (dayTimeMinutes >= 240 and dayTimeMinutes <= 660)
            
            -- Nuova fluttuazione umidità (Dew Point) basata sull'ora del giorno
            local dailyCycleAngle = ((dayTimeMinutes - 360) / 1440) * (2 * math.pi)
            local diurnalHumidityFluke = math.sin(dailyCycleAngle) * 0.15
            
            -- Indice di base combinato con la fluttuazione
            local humidityIndex = math.clamp(
                (groundWetness * 0.5) + (precipitationScale * 0.4) + (isSnowActive and 0.3 or 0.0) - diurnalHumidityFluke, 
                0.0, 
                1.0
            )

            -- 4. SEED CASUALE GIORNALIERO (Nuovo moltiplicatore)
            local currentDay = env.currentDay or 1
            if RealisticWeatherLite.lastCheckedDay ~= currentDay then
                RealisticWeatherLite.lastCheckedDay = currentDay
                RealisticWeatherLite.dailyFogMultiplier = math.random(70, 130) / 100.0
                RealisticWeatherLite.fogRoll = nil
            end
            local fogMultiplier = RealisticWeatherLite.dailyFogMultiplier or 1.0

            -- 5. RANDOMIZZATORE ADATTIVO
            if RealisticWeatherLite.fogRoll == nil then
                local hasPrecipitation = (precipitationScale > 0.05 or isSnowActive)
                local isGroundWetEnough = (groundWetness > 0.35)
                local isValidMorning = (isMorningWindow and temperature <= morningFogThreshold)

                if hasPrecipitation or isGroundWetEnough or isValidMorning then
                    local baseChance = 15 + (humidityIndex * 30) + (isValidMorning and 25 or 0)
                    local finalChance = math.floor(baseChance * fogMultiplier)
                    RealisticWeatherLite.fogRoll = (math.random(1, 100) <= finalChance)
                end
            elseif humidityIndex < 0.15 and precipitationScale == 0 and not isSnowActive and not isMorningWindow then
                RealisticWeatherLite.fogRoll = nil
            end

            -- 6. CALCOLO DENSITÀ PROGRESSIVA (Fisica Neve + Map Temp + Moltiplicatore)
            if RealisticWeatherLite.fogRoll == true then
                local windDissipation = math.clamp(1.0 - (windSpeed / 5.5), 0.0, 1.0)

                if windDissipation > 0 then
                    -- A) NEBBIA MATTUTINA FITTA (04:00 - 11:00)
                    if isMorningWindow and temperature <= morningFogThreshold then
                        local tempFactor = math.clamp(1.0 - (math.max(0, temperature - minMapTemp) / math.max(1, tempRange * 0.35)), 0.25, 1.0)
                        local wetBonus = math.max(humidityIndex, 0.3)
                        local peakFactor = (dayTimeMinutes <= 480) and math.clamp((dayTimeMinutes - 240) / 120, 0.3, 1.0) or math.clamp(1.0 - ((dayTimeMinutes - 480) / 180), 0.1, 1.0)

                        local morningDensity = 0.98 * tempFactor * wetBonus * peakFactor * fogMultiplier
                        
                        targetGroundDensity = math.max(targetGroundDensity, morningDensity * windDissipation)
                        targetHeightDensity = math.max(targetHeightDensity, (morningDensity * 0.90) * windDissipation)
                    end

                    -- B) NEBBIA DA PIOGGIA, NEVE E UMIDITÀ
                    if (humidityIndex > 0.25 or precipitationScale > 0.1 or isSnowActive) and temperature <= moistureFogThreshold then
                        local maxDensity = 0.40 + (groundWetness * 0.30)
                        
                        if isSnowActive then 
                            maxDensity = 0.45 + (precipitationScale * 0.50)
                            -- Neve "Umida" (attorno a 0°C) genera più foschia
                            local snowTempBonus = (temperature >= -2.0 and temperature <= 2.0) and 0.15 or 0.0
                            maxDensity = math.clamp(maxDensity + snowTempBonus, 0.30, 0.90)
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

    -- 7. APPLICAZIONE NATIVA E TRANSIZIONE PROPORZIONALE AL TEMPO DI GIOCO
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
        local maxCm = math.round((maxAllowedHeight or (self.isBlizzard and 1.00 or 0.50)) * 100)
        local fogPercent = math.round((RealisticWeatherLite.currentFogDensity or 0) * 100)
        
        if snowCm > 0 or fogPercent > 0 or self.isBlizzard then
            RealisticWeatherLite.infoBox:setTitle("WEATHER LITE")
            
            if snowCm > 0 or self:getIsSnowing() then
                -- Mostra i centimetri attuali affiancati al limite massimo raggiungibile
                local snowTextStr = string.format("%d / %d cm", snowCm, maxCm)
                RealisticWeatherLite.infoBox:addLine("Altezza Neve:", snowTextStr)
                
                -- Avviso visivo dinamico quando si attiva il limite da 1 metro
                if self.isBlizzard then
                    RealisticWeatherLite.infoBox:addLine("Allerta:", "Bufera (Max 1m)", {1, 0.3, 0.3, 1}, true)
                end
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