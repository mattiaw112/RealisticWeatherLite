RW_Weather = {}
RW_Weather.FACTOR = {
    SNOW_FACTOR = 0.0005,
    SNOW_HEIGHT = 1.0
}

SnowSystem.MAX_HEIGHT = RW_Weather.FACTOR.SNOW_HEIGHT

-------------------------------------------------------------------------------
-- FUNZIONI HELPER (Lettura dal forecast di FS25)
-------------------------------------------------------------------------------
function RW_Weather:getIsSnowing()
    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    return currentWeather ~= nil and currentWeather.precipitationType == WeatherType.SNOW
end

function RW_Weather:getSnowFallScale()
    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    if currentWeather ~= nil and currentWeather.precipitationType == WeatherType.SNOW then
        return currentWeather.dropScale or 1.0
    end
    return 1.0
end

function RW_Weather:getIsRaining()
    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    return currentWeather ~= nil and currentWeather.precipitationType == WeatherType.RAIN
end

function RW_Weather:getRainFallScale()
    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    if currentWeather ~= nil and currentWeather.precipitationType == WeatherType.RAIN then
        return currentWeather.dropScale or 1.0
    end
    return 1.0
end

function RW_Weather:getHailFallScale()
    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    if currentWeather ~= nil and currentWeather.precipitationType == WeatherType.HAIL then
        return currentWeather.dropScale or 1.0
    end
    return 0.0
end

-------------------------------------------------------------------------------
-- FUNZIONE PER MOSTRARE LE NOTIFICHE METEO
-------------------------------------------------------------------------------
function RW_Weather:showNotification(textKey)
    local areNotificationsEnabled = _G.getModSettings and _G.getModSettings("notifications_enabled") or false
    if areNotificationsEnabled and g_currentMission ~= nil then
        local title = g_i18n:hasText("rw_warning_title") and g_i18n:getText("rw_warning_title") or "Allerta Meteo"
        local message = g_i18n:hasText(textKey) and g_i18n:getText(textKey) or textKey
        
        if g_currentMission.hud ~= nil and g_currentMission.hud.ingameMap ~= nil then
            g_currentMission:showBlinkingWarning(message, 5000)
        end
    end
end

-------------------------------------------------------------------------------
-- UPDATE PRINCIPALE: Gestione Neve e Danni da Grandine
-------------------------------------------------------------------------------
function RW_Weather:update(superFunc, dT)
    -- 1. Update nativo del gioco
    superFunc(self, dT)

    local timescale = dT * g_currentMission:getEffectiveTimeScale()

    ---------------------------------------------------------------------------
    -- GESTIONE NEVE
    ---------------------------------------------------------------------------
    local temperature = self.temperatureUpdater:getTemperatureAtTime(self.owner.dayTime)
    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)

    if g_currentMission.missionInfo.isSnowEnabled then
        local blizzardFactor = (currentWeather ~= nil and currentWeather.isBlizzard) and 10 or 1
        self.isBlizzard = currentWeather ~= nil and currentWeather.isBlizzard

        if self:getIsSnowing() and temperature < 10 then
            local scale = 1 - temperature * 0.1
            self.snowHeight = math.clamp(
                self.snowHeight + RW_Weather.FACTOR.SNOW_FACTOR * (timescale / 100000) * self:getSnowFallScale() * scale * blizzardFactor,
                0, 
                RW_Weather.FACTOR.SNOW_HEIGHT
            )
        elseif temperature >= 10 then
            self.snowHeight = 0
            g_currentMission.snowSystem:removeAll()
        elseif temperature > 0 and self.snowHeight > 0 then
            local scale = self:getIsRaining() and math.max(5 / self:getRainFallScale(), 1.25) or 1
            self.snowHeight = math.clamp(
                self.snowHeight - temperature * 0.001 * (timescale / 100000) * scale, 
                0, 
                RW_Weather.FACTOR.SNOW_HEIGHT
            )
            if self.snowHeight == 0 then 
                g_currentMission.snowSystem:removeAll() 
            end
        end
    else
        self.snowHeight = math.max(self.snowHeight - 0.005 * (dT / 1000) * (g_currentMission:getEffectiveTimeScale() / 100), 0)
        self.isBlizzard = false
    end

    -- Applica l'altezza della neve visibile sul terreno
    g_currentMission.snowSystem:setSnowHeight(self.snowHeight)

    ---------------------------------------------------------------------------
    -- GESTIONE DANNI DA GRANDINE & NOTIFICHE (Collegata alle Impostazioni)
    ---------------------------------------------------------------------------
    local isHailDamageEnabled = _G.getModSettings and _G.getModSettings("hailDamage_enabled") or false
    local hail = self:getHailFallScale()

    if hail > 0 then
        -- Invia notifica di allerta grandine (se attiva nelle opzioni)
        if not self.hasWarnedHail then
            self:showNotification("rw_hail_alert")
            self.hasWarnedHail = true
        end

        -- Applica i danni se l'opzione è attiva
        if isHailDamageEnabled then
            local indoorMask = g_currentMission.indoorMask
            local vehicles = g_currentMission.vehicleSystem.vehicles

            for _, vehicle in pairs(vehicles) do
                local wearable = vehicle.spec_wearable
                if wearable ~= nil then
                    local x, _, z = getWorldTranslation(vehicle.rootNode)

                    if x ~= nil and z ~= nil and not indoorMask:getIsIndoorAtWorldPosition(x, z) then
                        local damageAmount = hail * 0.0001 * (timescale / 100000)
                        local wearAmount = hail * 0.0003 * (timescale / 100000)
                        
                        wearable:addWearAmount(wearAmount, true)
                        wearable:addDamageAmount(damageAmount, true)
                    end
                end
            end
        end
    else
        self.hasWarnedHail = false
    end
end

Weather.update = Utils.overwrittenFunction(Weather.update, RW_Weather.update)

-------------------------------------------------------------------------------
-- GESTIONE NEBBIA FITTA & NOTIFICHE
-------------------------------------------------------------------------------
function RW_Weather:randomizeFog(superFunc, time)
    if not g_currentMission:getIsServer() then return end

    local season = self.owner.currentSeason
    local seasonToFog = self.seasonToFog[season]
    local currentDay = g_currentMission.environment.currentMonotonicDay
    local fog

    self.lastFogDay = self.lastFogDay or 0

    if seasonToFog == nil or currentDay == self.lastFogDay + 1 then
        fog = nil
    else
        fog = seasonToFog:createFromTemplate()

        if season ~= 2 and math.random() >= 0.85 then
            fog.groundFogCoverageEdge0 = math.random(5, 10) / 100
            fog.groundFogCoverageEdge1 = math.random(90, 95) / 100
            fog.groundFogExtraHeight = math.random(25, 35)
            fog.groundFogGroundLevelDensity = math.random(85, 200) / 100
            fog.heightFogMaxHeight = math.random(650, 800)
            fog.heightFogGroundLevelDensity = math.random(75, 190) / 100
            fog.groundFogEndDayTimeMinutes = math.min(math.random(fog.groundFogStartDayTimeMinutes + 120, fog.groundFogStartDayTimeMinutes + 860), 1439)

            fog.groundFogWeatherTypes[WeatherType.SNOW] = true
            fog.groundFogWeatherTypes[WeatherType.RAIN] = true

            self.lastFogDay = currentDay

            -- Notifica di nebbia fitta (se attiva nelle opzioni)
            self:showNotification("rw_fog_alert")
        end
    end

    self.fogUpdater:setTargetFog(fog, time)
end

Weather.randomizeFog = Utils.overwrittenFunction(Weather.randomizeFog, RW_Weather.randomizeFog)

-------------------------------------------------------------------------------
-- SALVATAGGIO E SINCRONIZZAZIONE
-------------------------------------------------------------------------------
function RW_Weather:setInitialState(superFunc, snowHeight, timeSinceLastRain, lastFogDay)
    superFunc(self, snowHeight, timeSinceLastRain, lastFogDay)
    self.snowHeight = snowHeight
    self.timeSinceLastRain = timeSinceLastRain
    self.lastFogDay = lastFogDay
    g_currentMission.snowSystem:setSnowHeight(self.snowHeight)
end

Weather.setInitialState = Utils.overwrittenFunction(Weather.setInitialState, RW_Weather.setInitialState)

function RW_Weather:saveToXMLFile(handle, key)
    local xmlFile = XMLFile.wrap(handle)
    if xmlFile ~= nil then
        xmlFile:setInt(key .. "#lastFogDay", self.lastFogDay or 0)
        xmlFile:save(false, true)
        xmlFile:delete()
    end
end

Weather.saveToXMLFile = Utils.appendedFunction(Weather.saveToXMLFile, RW_Weather.saveToXMLFile)

function RW_Weather:loadFromXMLFile(handle, key)
    local xmlFile = XMLFile.wrap(handle)
    if xmlFile ~= nil then
        self.lastFogDay = xmlFile:getInt(key .. "#lastFogDay", 0)
        xmlFile:delete()
    end
end

Weather.loadFromXMLFile = Utils.prependedFunction(Weather.loadFromXMLFile, RW_Weather.loadFromXMLFile)